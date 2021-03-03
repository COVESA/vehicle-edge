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
const { VALUE_TYPE_RAW } = require('boschio.iotea/src/core/constants');

const {
    Rule,
    OrRules,
    OpConstraint,
    Talent
} = iotea;

const Logger = iotea.util.Logger;

const JsonModel = iotea.util.JsonModel;

const config = new JsonModel(require('./config/config.json'));

process.env.LOG_LEVEL = config.get('loglevel', Logger.ENV_LOG_LEVEL.DEBUG);

try {
    process.env.MQTT_TOPIC_NS = config.get('mqtt.ns');
}
catch(err) {
    delete process.env.MQTT_TOPIC_NS;
}

class TestTalent extends Talent {
    constructor(connectionString) {
        super('test-talent', connectionString);
        this.logger.info(`Talent ${this.id} created on ${connectionString} using namespace ${process.env.MQTT_TOPIC_NS}`);
    }

    getRules() {
        return new OrRules([
            new Rule(
                new OpConstraint('Body$Lights$IsBrakeOn', OpConstraint.OPS.ISSET, null, 'Vehicle', VALUE_TYPE_RAW)
            )
        ]);
    }

    onEvent(ev, evctx) {
        this.logger.info(`Received ${ev.type}.${ev.feature} = ${ev.$feature.raw.value}`);
    }
}

new TestTalent(config.get('mqtt.connectionString')).start();