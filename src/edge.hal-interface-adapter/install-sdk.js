/*****************************************************************************
 * Copyright (c) 2021 Robert Bosch GmbH
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 ****************************************************************************/

const fs = require('fs');
const path = require('path');
const Terminal = require('../../iot-event-analytics/src/tools/terminal');

function resolvePathFromCurrentDir(relPath) {
    return path.resolve(__dirname, relPath);
}

(async() => {
    const t = new Terminal();

    console.log(`Installing IoT Event Analytics dependencies in submodule...`);

    await t.runCommand('yarn', [ '--silent', '--dev', '--optional' ], path.resolve('../../iot-event-analytics'), msg => {
        console.log(`  ${msg.trim()}`);
    });

    console.log(`Building IoT Event Analytics SDK...`);
    let sdkFilePath;
    await t.runCommand('yarn', [ 'sdk.build', '-d', __dirname ], path.resolve('../../iot-event-analytics'), msg => {
        sdkFilePath = msg.trim();
    });

    const sdkFileName = path.basename(sdkFilePath);

    console.log(`Installing SDK ${sdkFileName}...`);

    const packageJson = fs.readFileSync(resolvePathFromCurrentDir('./package.json'));
    const yarnLock = fs.readFileSync(resolvePathFromCurrentDir('./yarn.lock'));

    try {
        await t.runCommand('yarn', [ 'add', `file:${sdkFileName}`, '--ignore-scripts', '--no-progress', '--ignore-optional' ], __dirname);
    }
    finally {
        // Restore the prior state of these files before installing the SDK
        fs.writeFileSync(resolvePathFromCurrentDir('./package.json'), packageJson);
        fs.writeFileSync(resolvePathFromCurrentDir('./yarn.lock'), yarnLock);
        fs.unlinkSync(resolvePathFromCurrentDir(sdkFileName));
    }
})();

