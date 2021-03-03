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

const JsonModel = iotea.util.JsonModel;
const config = new JsonModel(require('../config/config.json'));

process.env.MQTT_TOPIC_NS = config.get('mqtt.ns');
process.env.LOG_LEVEL = config.get('loglevel');

const Talent = iotea.Talent;

const {
    VALUE_TYPE_RAW
} = iotea.constants;

class BrakeLightTalent extends Talent {
    constructor(connectionString) {
        super('brake-light-talent', connectionString);
    }

    getRules() {
        return new iotea.AndRules([
            new iotea.Rule(
                new iotea.OpConstraint('Body$Lights$IsBrakeOn', iotea.OpConstraint.OPS.ISSET, null, 'Vehicle', VALUE_TYPE_RAW)
            )
        ]);
    }

    async onEvent(ev, evtctx) {
        this.logger.info(`${JSON.stringify(ev.$feature.raw)}`, evtctx);
    }
}

new BrakeLightTalent(config.get('mqtt.connectionString')).start();