/*****************************************************************************
 * Copyright (c) 2021 Robert Bosch GmbH
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 ****************************************************************************/

const yargs = require('yargs');
const path = require('path');

const args = yargs
    .option('configDir', {
        alias: 'c',
        description: 'Configuration directory',
        required: false,
        default: path.join(__dirname, 'config')
    })
    .help()
    .alias('help', 'h');

const HalInterfaceAdapter = require('./halInterfaceAdapter');

const argv = args.argv;

const configDir = path.isAbsolute(argv.configDir) ? argv.configDir : path.join(process.cwd(), argv.configDir);

(new HalInterfaceAdapter()).start(
    path.join(configDir, 'config.json'),
    path.join(configDir, 'mapping.json')
);