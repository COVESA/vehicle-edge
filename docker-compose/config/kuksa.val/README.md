<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Prerequisites

The contents of this folder has to look like

```code
certs
|- jwt.key.pub
|- Server.key
L- Server.pem
vss.json
```

You can find out, where to get these files [here](https://github.com/GENIVI/iot-event-analytics/blob/develop/docker/kuksa.val2iotea/README.md)

You can also run the helper script to generate vss.json, add required values and download kuksa.val certs:

```code
cd vehicle-edge/setup/general/kuksa.val
./generate-config.sh
cp config/vss-mod.json ../../../docker-compose/config/kuksa.val/vss.json
cp -r config/certs ../../../docker-compose/config/kuksa.val/
```
