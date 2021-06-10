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
const Terminal = require('../iot-event-analytics/src/tools/terminal');

let targetDir = __dirname;

for (let i = 0; i < process.argv.length; i++) {
    const arg = process.argv[i];

    if (i < process.argv.length - 1 && arg === '-d' || arg === '--directory') {
        const dir = process.argv[i + 1].trim();

        if (path.isAbsolute(dir)) {
            targetDir = dir;
            break;
        }

        targetDir = resolvePathFromCurrentDir(dir);
        break;
    }
}

console.log(`Target directory ${targetDir}`);

function resolvePathFromCurrentDir(relPath) {
    return path.resolve(__dirname, relPath);
}

(async() => {
    const t = new Terminal();

    console.log(`Installing IoT Event Analytics dependencies in submodule...`);

    await t.runCommand('yarn', [ '--silent', '--dev', '--optional' ], resolvePathFromCurrentDir('../iot-event-analytics'), msg => {
        console.log(`  ${msg.trim()}`);
    });

    console.log(`Building IoT Event Analytics SDK...`);
    let sdkFilePath;
    await t.runCommand('yarn', [ 'sdk.build', '-d', targetDir ], resolvePathFromCurrentDir('../iot-event-analytics'), msg => {
        sdkFilePath = msg.trim();
    });

    const sdkFileName = path.basename(sdkFilePath);

    console.log(`Installing SDK ${sdkFileName}...`);

    const packageJson = fs.readFileSync(resolvePathFromCurrentDir(path.join(targetDir, 'package.json')));
    const yarnLock = fs.readFileSync(resolvePathFromCurrentDir(path.join(targetDir, './yarn.lock')));

    try {
        await t.runCommand('yarn', [ 'add', `file:${sdkFileName}`, '--ignore-scripts', '--no-progress', '--ignore-optional' ], targetDir);
    }
    finally {
        // Restore the prior state of these files before installing the SDK
        fs.writeFileSync(resolvePathFromCurrentDir(path.join(targetDir, 'package.json')), packageJson);
        fs.writeFileSync(resolvePathFromCurrentDir(path.join(targetDir, 'yarn.lock')), yarnLock);
        fs.unlinkSync(resolvePathFromCurrentDir(path.join(targetDir, sdkFileName)));
    }
})();

