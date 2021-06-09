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

You can find out, where to get these files [here](https://github.com/GENIVI/iot-event-analytics/blob/develop/docker/vss2iotea/README.md)

For creating a Kuksa.VAL configuration on a Linux terminal, use the provided _./generate-config.sh_ script. This will create a configuration in the _./config_ directory.
