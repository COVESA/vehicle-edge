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
import asyncio
from hal_interface import HalInterface

async def main():
    abs_config_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'config', 'config.json')

    hal = HalInterface(abs_config_path)

    await hal.start()

LOOP = asyncio.new_event_loop()
LOOP.run_until_complete(main())
