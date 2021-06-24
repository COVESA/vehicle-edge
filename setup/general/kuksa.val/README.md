<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Prerequisites

The contents of the folder _./config_ has to contain the following directory structure

```code
certs
|- jwt.key.pub
|- Server.key
L- Server.pem
vss.json
```

You can find out, where to get these files manually [here](https://github.com/GENIVI/iot-event-analytics/blob/develop/docker/kuksa.val2iotea/README.md)

For automatic configuration creation use one of the tools for your platform

- __>> Linux only <<__<br>
  Run _./generate-config.sh_. This will create a configuration in the _./config_ directory.
- __>> Windows only <<__<br>
  Run `generate-config.bat <optional Kuksa.Val configuration directory>`. Without the optional argument, which needs to be an absolute path, the configuration will be created in the _./config_ directory. The tool will also assist in updating the required JSON Web Tokens in the HAL Interface Adapter configuration and the Kuksa.VAL2IoTea Adapter configuration. You will be prompted to specify the absolute location of these files when running the script.
