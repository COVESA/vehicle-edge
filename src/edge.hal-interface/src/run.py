##############################################################################
# Copyright (c) 2021 Robert Bosch GmbH
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# SPDX-License-Identifier: MPL-2.0
##############################################################################

import os
import sys
import asyncio
from hal_interface import HalInterface

async def main():
    abs_config_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'config', 'config.json')

    for i in range(len(sys.argv)):
        if i < len(sys.argv) - 1 and (sys.argv[i] == '-c' or sys.argv[i] == '--configDir'):
            config_path_override = sys.argv[i + 1]
            abs_config_path = config_path_override if os.path.isabs(config_path_override) else os.path.realpath(os.path.join(os.getcwd(), config_path_override))
            abs_config_path = os.path.join(abs_config_path, 'config.json')
            break

    print(f'Read configuration from {abs_config_path}')

    hal = HalInterface(abs_config_path)

    await hal.start()

LOOP = asyncio.new_event_loop()
LOOP.run_until_complete(main())
