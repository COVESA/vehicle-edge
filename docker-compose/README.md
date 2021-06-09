<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Start the Vehicle Edge stack on your local machine using docker-compose

## Prerequisites

- Tested with
  - Windows
    - Docker desktop v2.4.0.0
    - Docker Engine v19.03.13
    - Compose: 1.27.4
  - Ubuntu 18.04.5
    - Docker Engine v19.03.6
    - Compose 1.27.4
  - Ubuntu Desktop 20.10 (on Raspberry Pi4)
    - Docker Engine v19.03.6
    - Compose 1.27.4

## Setup

- For further information how to build the images (especially, if you are working behind a proxy), please see [here](https://github.com/GENIVI/iot-event-analytics/tree/develop/docker)
- [Install docker-compose and check the version](https://github.com/GENIVI/iot-event-analytics/tree/develop/docker-compose)

## Custom configuration

- Copy the _./docker-compose/config_ folder. For further information about the configuration for a specific component, read _setup/general/\<component-name\>_
- Copy the respective _.env_ file matching your deployment architecture (Either _.arm64.env_ or _.amd64.env_)
- The contents should look like this<br>

  ```text
  <custom config folder>
  |- hal-interface
  |  L- config.json
  |- hal-interface-adapter
  |  |- config.json                 // Needs to have the correct JSON Web token, to authenticate against Kuksa.val
  |  L- mapping.json
  |- iotea
  |  |- channels
  |  |  |- talent.channel.json
  |  |  |- talent.schema.json
  |  |  |- kuksa.val.channel.json
  |  |  |- kuksa.val.schema.json
  |  |  L- kuksa.val.transform.jna
  |  |- config.json
  |  |- types.json                  // Needs to have types configuration, which matches the provided Vehicle Signal Specification
  |  L- uom.json
  |- mosquitto
  |  L- config.json
  |- kuksa.val                      // (optional, needed if Kuksa.val should be used)
  |  |- certs                       // Read in setup/general/kuksa.val/README.md how to create the required configuration files
  |  |  |- jwt.key.pub
  |  |  |- Server.key
  |  |  L- Server.pem
  |  L- vss.json
  L- kuksa.val2iotea                // (optional, needed if Kuksa.val should be used)
     L- config.json                 // Needs to have the correct JSON Web token, to authenticate against Kuksa.Val
  ```

- Update the your _.env_ file and set the value _CONFIG\_DIR_ to `/abs/path/to/<custom config folder>`

## Run manually

- Clone this repository with `--recurse-submodules` flag. If you already cloned it, but you do not have the submodule, run `git submodule update --init --recursive`

### No Kuksa.val

- __>> AMD64 platform only: <<__<br>
  - Run `docker-compose --env-file .amd64.env -f docker-compose-no-kuksa.val.yml`
- __>> ARM64 platform only: <<__<br>
  - Run `docker-compose --env-file .arm64.env -f docker-compose-no-kuksa.val.yml`

### With Kuksa.val

- Follow **Install Kuksa.val** section from [https://github.com/GENIVI/iot-event-analytics/tree/develop/docker/kuksa.val2iotea/README.md](https://github.com/GENIVI/iot-event-analytics/tree/develop/docker/kuksa.val2iotea/README.md) to __download AND load__ the latest version of KUKSA.VAL into your local Docker registry.<br>
  - __>> AMD64 platform only: <<__<br>
    Set the property KUKSA_VAL_IMG to `amd64/kuksa-val:<version>` in the _.env_ file
  - __>> ARM64 platform only: <<__<br>
    Set the property KUKSA_VAL_IMG to `arm64/kuksa-val:<version>` in the _.arm64.env_ file
- Check your configuration using `docker-compose -f docker-compose.edge.yml config`
- __>> AMD64 platform only: <<__<br>
  Run `docker-compose -f docker-compose.edge.yml --project-name vehicle-edge-platform --env-file <path to your env file OR .amd64.env> up --build --remove-orphans`
- __>> ARM64 platform only: <<__<br>
  Run `docker-compose -f docker-compose.edge.yml --project-name vehicle-edge-platform --env-file <path to your env file OR .arm64.env> up --build --remove-orphans`

## Run scripted

### >> AMD64 platform only <<

- __>> Windows only <<__<br>
  `<run-script>` is _run.bat_
- __>> Linux only <<__<br>
  `<run-script>` is _run.sh_

- Start using the \<run-script\>
  - You can start the platform `<run-script> <path to your env file or .amd64.env or .arm64.env> <path to run.properties>`
