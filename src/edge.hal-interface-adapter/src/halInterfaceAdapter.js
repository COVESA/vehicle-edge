/*****************************************************************************
 * Copyright (c) 2021 Robert Bosch GmbH
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 ****************************************************************************/

const iotea = require('boschio.iotea');
const ProtocolGateway = iotea.ProtocolGateway;
const MqttClient = iotea.util.MqttClient;
const fs = require('fs').promises;

const {
    PLATFORM_EVENTS_TOPIC,
    PLATFORM_EVENT_TYPE_SET_CONFIG,
    PLATFORM_EVENT_TYPE_UNSET_CONFIG

} = iotea.constants;

const {
	KuksaValWebsocket,
    VssPathTranslator
} = iotea.adapter;

const {
    Logger,
    JsonModel
} = iotea.util;

module.exports = class HalInterfaceAdapter {
    // Publish info about enabled and disabled VSS paths
    constructor() {
        this.lut = new HalVssLookupTable();
        this.ioTeaProtocolGateway = null;
        this.halProtocolGateway = null;

        this.vssSocket = null;
        // Needed for directly passing values to IoT Event Analytics
        this.instance = null;
        this.subject = null;

        this.config = null;
        this.retainBuffer = {};
        this.logger = new Logger('HalInterfaceAdapter');

        this.vssPathTranslator = new VssPathTranslator();
    }

    start(absConfigFilePath, absMappingFilePath) {
        return this.__loadConfigFile(absConfigFilePath)
            .then(configData => {
                this.config = new JsonModel(configData);

                try {
                    this.vssPathTranslator = new VssPathTranslator(this.config.get("'kuksa.val'.pathConfig"));
                }
                catch(err) {
                    // Invalid configuration for VSS path translator
					this.logger.error(err.message, null, err);
                }

                // Init the global log level
                process.env.LOG_LEVEL = this.config.get('loglevel', Logger.ENV_LOG_LEVEL.WARN);
                
                let protocolGatewayConfig = this.config.get('iotea.protocolGateway');
                if (ProtocolGateway.getAdapterCount(protocolGatewayConfig) !== 1) {
                    throw new Error(`Invalid IoTea ProtocolGateway Configuration. Specify a single adapter in your ProtocolGateway configuration`);
                }
                this.ioTeaProtocolGateway = new ProtocolGateway(protocolGatewayConfig, 'IoTea ProtocolGateway');
                
                protocolGatewayConfig = this.config.get('hal.protocolGateway');
                if (ProtocolGateway.getAdapterCount(protocolGatewayConfig) !== 1) {
                    throw new Error(`Invalid HAL ProtocolGateway Configuration. Specify a single adapter in your ProtocolGateway configuration`);
                }
                this.halProtocolGateway = new ProtocolGateway(protocolGatewayConfig, 'HAL ProtocolGateway');
            })
            .then(() => this.__loadMappingFile(absMappingFilePath, this.config.get("'kuksa.val'.bypass", false) === true))
            .then(async () => {
                this.subject = this.config.get('iotea.subject', null);
                this.instance = this.config.get('iotea.instance', null);

                const hasVssConfig = this.config.get("'kuksa.val'.ws", null) !== null && this.config.get("'kuksa.val'.jwt", null) !== null;

                if (!hasVssConfig) {
                    this.logger.always('*****INFO***** No Kuksa.VAL configuration found. All events will be directly sent to IoT Event Analytics Platform');

                    if (this.subject === null || this.instance === null) {
                        throw new Error(`You need to define the mandatory fields iotea.subject and iotea.instance to be able to omit 'kuksa.val'.ws and 'kuksa.val'.jwt`);
                    }

                    return;
                }

                this.logger.info(`Connecting to KuksaVal: ${this.config.get("'kuksa.val'.ws")}`);
                this.vssSocket = new KuksaValWebsocket(this.config.get("'kuksa.val'.ws"), this.config.get("'kuksa.val'.jwt"));

                // Check if any event goes directly to IoT Event Analytics Platform
                const sendAnyEventToIoTea = this.lut.entries().reduce((acc, entry) => acc && entry.shouldBypassVss(), false);

                // Get subject from KUKSA.val
                if (this.config.get("'kuksa.val'.subjectPath", null) !== null) {
                    await this.vssSocket.subscribe(this.config.get("'kuksa.val'.subjectPath"), msg => {
                        this.subject = msg.value;
                    }, err => {
                        this.logger.error(err.message, null, err);
                    }, true);
                } else {
                    if (sendAnyEventToIoTea && this.subject === null) {
                        throw new Error(`You need to define the mandatory field iotea.subject, if you do not specify vss.subjectPath`);
                    }
                }

                // Get instance from KUKSA.val
                if (this.config.get("'kuksa.val'.instancePath", null) !== null) {
                    await this.vssSocket.subscribe(this.config.get("'kuksa.val'.instancePath"), msg => {
                        this.instance = msg.value;
                    }, err => {
                        this.logger.error(err.message, null, err);
                    }, true);
                } else {
                    if (sendAnyEventToIoTea && this.instance === null) {
                        throw new Error(`You need to define the mandatory field iotea.instance, if you do not specify vss.instancePath`);
                    }
                }
            })
            .then(() => {
                this.logger.info(`Subscribing for HAL events on topic +`);
                return this.halProtocolGateway.subscribeJsonShared('hal-interface-adapters', '+', this.__onHalMessageReceive.bind(this));
            })
            .then(() => {
                this.logger.info(`Subscribing for platform events on ${PLATFORM_EVENTS_TOPIC}...`);
                return this.ioTeaProtocolGateway.subscribeJsonShared('hal-interface-adapters', PLATFORM_EVENTS_TOPIC, this.__onIoTeaPlatformEvent.bind(this));
                
            })
            .then(() => {
                this.logger.info('HAL interface adapter started successfully');
            })
            .catch(err => {
                this.logger.error(err.message, null, err);
            });
    }

    __loadConfigFile(absPath) {
		this.logger.debug(`Loading config from: ${absPath} ...`);
        return fs.readFile(absPath, { encoding: 'utf8' })
            .then(content => JSON.parse(content));
    }

    __loadMappingFile(absPath, defaultBypassVss) {
		this.logger.debug(`Loading mapping from: ${absPath} ...`);
        return fs.readFile(absPath, { encoding: 'utf8' })
            .then(content => JSON.parse(content))
            .then(entries => {
                for (const entry of entries) {
                    this.lut.add(new HalVssLookupTableEntry(entry, defaultBypassVss));
                }
            });
    }

    async __onHalMessageReceive(msg, topic) {
        this.logger.debug(`Received HAL message ${JSON.stringify(msg)} for topic ${topic}`);

        // Receives topic like '10.CruiseStatus2'
        try {
            const entry = this.lut.resolveEntryByHalResourceId(topic);
            const messageModel = new JsonModel(msg);

            let value = null;
            let whenMs = messageModel.get('whenMs', Date.now());

            try {
                value = entry.processValue(messageModel.get(entry.getHalValuePath()));
            }
            catch(err) {
                this.logger.debug(err.message);
                return;
            }

            // Write the value into the buffer
            this.retainBuffer[topic] = {
                value,
                whenMs
            };

            await this.__publishValue(entry, value, whenMs);
        }
        catch(err) {
            this.logger.error(err.message, null, err);
        }
    }

    async __onIoTeaPlatformEvent(ev, topic) {
        this.logger.debug(`Received platform event ${JSON.stringify(ev)} on topic ${topic}`);

        if (ev.type !== PLATFORM_EVENT_TYPE_SET_CONFIG && ev.type !== PLATFORM_EVENT_TYPE_UNSET_CONFIG) {
            return;
        }

        const talentId = ev.data.talent;

        this.logger.info(`Received event for talent ${talentId}`);

        try {
            const uniqueVssPaths = this.__extractUniqueVssPathsFromRules(ev.data.config.rules);

            this.logger.info(`Unique vss paths: ${uniqueVssPaths}`);

            for (const uniqueVssPath of uniqueVssPaths) {
                try {
                    const entry = this.lut.resolveEntryByVssPath(uniqueVssPath);

                    if (ev.type === PLATFORM_EVENT_TYPE_SET_CONFIG) {
                        this.logger.info(`Adding consumer for ${entry.getVssPath()} with HAL resourceId ${entry.getHalResourceId()}`);

                        if (entry.pushUniqueConsumer(talentId) && entry.shouldRetainValue && this.retainBuffer.hasOwnProperty(entry.getHalResourceId())) {
                            // Only triggers, if it's the first time the talent was added to the consumers of a specific entry
                            this.logger.info(`Found signal ${entry.getHalResourceId()} in retain buffer`);
                            const retainBufferEntry = this.retainBuffer[entry.getHalResourceId()];
                            // Previous value is present, publish it to give an immediate feedback for the talent
                            await this.__publishValue(entry, retainBufferEntry.value, retainBufferEntry.whenMs);
                        }

                        this.logger.info(`All consumers ${Array.from(entry.consumers.values())}`);

                        if (entry.consumers.size === 1) {
                            // Was the first one, so enable it
                            await this.__enableHalResourceId(entry.getHalResourceId());
                        }
                    }

                    if (ev.type === PLATFORM_EVENT_TYPE_UNSET_CONFIG) {
                        this.logger.info(`Removing consumer from ${entry.getVssPath()} with HAL resourceId ${entry.getHalResourceId()}`);

                        entry.removeConsumerIfExisting(talentId);

                        if (entry.consumers.size === 0) {
                            // Was the last one, so disable it
                            await this.__disableHalResourceId(entry.getHalResourceId());
                        }
                    }
                }
                catch(err) {
                    // Not found, just ignore
                    this.logger.debug(err.message);
                }
            }
        }
        catch(err) {
            this.logger.warn(`Oops, this should not have happened.`, null, err);
        }
    }

    __extractUniqueVssPathsFromRules(rulesJson, vssPaths = []) {
        if (rulesJson.rules) {
            for (let rule of rulesJson.rules) {
                this.logger.debug(`Will extract vss from rule ${rule}`);
                vssPaths = this.__extractUniqueVssPathsFromRules(rule, vssPaths);
                this.logger.debug(`vss paths: ${vssPaths}`);
            }

            return Array.from(new Set(vssPaths));
        }

        // eslint-disable-next-line no-useless-escape
        const typeSelectionRegex = /^(?:([0-9]+|\*)\.)?([^\.]+)$/g;

        const matches = typeSelectionRegex.exec(rulesJson.typeSelector);

        // Can be a wildcard * or a specific type
        const type = matches[2];

        // vss path could now be */path/to/feature, but Kuksa.VAL it should actually support it
        vssPaths.push(this.vssPathTranslator.ioteaTypeAndFeature2KuksaVssPath(type, rulesJson.feature));

        return vssPaths;
    }

    __enableHalResourceId(halResourceId) {
        this.logger.info(`Enable HAL resourceId ${halResourceId}`);
        return this.halProtocolGateway.publishJson(`${halResourceId}/enable`, {
            returnTopic: ''
        });
    }

    __disableHalResourceId(halResourceId) {
        this.logger.info(`Disable HAL resourceId ${halResourceId}`);
        return this.halProtocolGateway.publishJson(`${halResourceId}/disable`, {
            returnTopic: ''
        });
    }

    async __publishValue(entry, value, whenMs) {
        const vssPath = entry.getVssPath();

        if (this.vssSocket === null || entry.shouldBypassVss()) {
            // Rewrite the path and extract the type
            const { type, feature } = this.vssPathTranslator.kuksaVss2IoteaTypeAndFeature(vssPath);

            this.logger.debug(`Publishing ${value} to IoT Event Analytics for type=${type} and feature=${feature}...`);

            return this.ioTeaProtocolGateway.publishJson(iotea.constants.INGESTION_TOPIC, {
                whenMs,
                // First element is type
                type,
                // All others joined by $ is the feature
                feature,
                value: value,
                instance: this.instance,
                subject: this.subject
            });
        }

        // Publishes it to VSS
        this.logger.debug(`Publishing ${value} to Kuksa.VAL at path ${vssPath}...`);
        // Given timestamp cannot be transported to Kuksa.VAL and may get lost there >> May lead to duplicate timestamps and missing events
        return this.vssSocket.publish(vssPath, value);
    }
}
class BidirectionalLookupTable {
    constructor() {
        this.d1 = {};
        this.d2 = {};
    }

    __resolveD1(key) {
        return this.__resolve(this.d1, key);
    }

    __resolveD2(key) {
        return this.__resolve(this.d2, key);
    }

    __resolve(o, key) {
        if (!o.hasOwnProperty(key)) {
            throw new Error(`Could not find key ${key}`);
        }

        return o[key];
    }
}

class HalVssLookupTableEntry {
    constructor(data, defaultBypassVss = false) {
        this.data = data;
        this.defaultBypassVss = defaultBypassVss;
        this.consumers = new Set();

        this.valueMapping = this.data.halValueMapping || null;
        this.valueFactor = isFinite(this.data.halValueFactor) ? this.data.halValueFactor : 1;
        this.valueOffset = isFinite(this.data.halValueOffset) ? this.data.halValueOffset : 0;
        // Defaults to true
        this.shouldRetainValue = this.data.retainValue !== false;
    }

    getHalValuePath() {
        return this.data.halValuePath || '';
    }

    getHalResourceId() {
        return this.data.halResourceId;
    }

    getVssPath() {
        return this.data.vssPath;
    }

    shouldBypassVss() {
        return this.data.vssBypass === true || (this.defaultBypassVss === true && this.data.vssBypass === undefined);
    }

    pushUniqueConsumer(consumer) {
        if (this.consumers.has(consumer)) {
            return false;
        }

        this.consumers.add(consumer);

        return true;
    }

    removeConsumerIfExisting(consumer) {
        this.consumers.delete(consumer);
    }

    processValue(value) {
        if (this.valueMapping !== null) {
            if (this.valueMapping[value] === undefined) {
                throw new Error(`Invalid value mapping for ${value} of resource ${this.getHalResourceId()}`);
            }

            value = this.valueMapping[value];
        }

        if (!isFinite(value)) {
            return value;
        }

        return value * this.valueFactor + this.valueOffset;
    }
}

class HalVssLookupTable extends BidirectionalLookupTable {
    add(entry) {
        this.d1[entry.getHalResourceId()] = entry;
        this.d2[entry.getVssPath()] = entry;
    }

    entries() {
        const entries = [];

        for (let key of Object.keys(this.d2)) {
            entries.push(this.d2[key]);
        }

        return entries;
    }

    resolveVssPath(halResourceId) {
        return this.resolveEntryByHalResourceId(halResourceId).getVssPath();
    }

    resolvehalResourceId(vssPath) {
        return this.resolveEntryByVssPath(vssPath).getHalResourceId();
    }

    resolveEntryByHalResourceId(halResourceId) {
        return this.__resolveD1(halResourceId);
    }

    resolveEntryByVssPath(vssPath) {
        return this.__resolveD2(vssPath);
    }

    getSimpleMapping(keyField, valueField) {
        return Object.values(this.d1).reduce((acc, entry) => {
            acc[entry[keyField]] = entry[valueField];
            return acc;
        }, {});
    }
}
