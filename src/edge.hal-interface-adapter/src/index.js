/*****************************************************************************
 * Copyright (c) 2021 Robert Bosch GmbH
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 ****************************************************************************/

const path = require('path');

const HalInterfaceAdapter = require('./halInterfaceAdapter');

(new HalInterfaceAdapter()).start(
    path.resolve(__dirname, 'config/config.json'),
    path.resolve(__dirname, 'config/mapping.json')
);