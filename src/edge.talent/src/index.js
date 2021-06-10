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

const Logger = iotea.util.Logger;
process.env.LOG_LEVEL = Logger.ENV_LOG_LEVEL.INFO;

const {
    MqttProtocolAdapter
} = iotea.util;

const {
    Talent,
    OpConstraint,
    Rule,
    AndRules,
    ProtocolGateway,
    TalentInput
} = iotea;

const {
    VALUE_TYPE_RAW
} = iotea.constants;

class SpeedTalent extends Talent {
    constructor(protocolGatewayConfig) {
        super('speed-talent', protocolGatewayConfig);
        this.logger.info(`Created with config: ${JSON.stringify(protocolGatewayConfig)}`);
    }

    getRules() {
        return new AndRules([
            new Rule(new OpConstraint('Speed', OpConstraint.OPS.ISSET, null, 'Vehicle', VALUE_TYPE_RAW))
        ]);
    }

    async onEvent(ev, evtctx) {
        this.logger.info(`${ev.feature} : ${TalentInput.getRawValue(ev)}`);
    }
}

// Update mqttAdapterConfig.config.brokerUrl, if you specified a different one in your configuration !!!
const mqttAdapterConfig = MqttProtocolAdapter.createDefaultConfiguration();
mqttAdapterConfig.config.brokerUrl = 'mqtt://mosquitto:1883'

new SpeedTalent(
    ProtocolGateway.createDefaultConfiguration([mqttAdapterConfig])
).start();
