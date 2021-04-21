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
(Not completed)
  - Ubuntu Desktop 20.10 (on Raspberry Pi4)
    - Docker Engine v19.03.6
    - Compose 1.27.4

## Setup

- For further information how to build the images (especially, if you are working behind a proxy), please see [here](https://github.com/GENIVI/iot-event-analytics/tree/develop/docker)
- [Install docker-compose and check the version](https://github.com/GENIVI/iot-event-analytics/tree/develop/docker-compose)

### Scripted

Setup can be easily bootstrapped by using the `<run-script>`. In order to do so directly proceed with the [Run](##Run) section

### Manual

- After cloning the vehicle-edge repository, execute `git submodule update --init --recursive` to get the contents of
  [IoT Event Analytics](https://github.com/GENIVI/iot-event-analytics) repository as a submodule<br>
  Update the _.env_ file (IOTEA_PROJECT_DIR) with the absolute path to `<vehicle-edge-dir>/iot-event-analytics`. 
  IOTEA_PROJECT_DIR can also point to an externally cloned iot-event-analytics repository.<br>
  A specific version tag can be checked out if desired. __This version should match the SDKs which are copied in the next steps!__
- Copy `IOTEA_PROJECT_DIR/src/sdk/javascript/lib/boschio.iotea-<version>.tgz` into _/src/edge.hal-interface-adapter_ AND _/docker-compose/talent_<br>
  Update the _.env_ file (IOTEA_JS_SDK) with `boschio.iotea-<version>.tgz`
- Copy `IOTEA_PROJECT_DIR/src/sdk/python/lib/boschio_iotea-<version>-py3-none-any.whl` into the _/src/edge.hal-interface_ directory<br>
  Update the _.env_ file (IOTEA_PYTHON_SDK) with `boschio_iotea-<version>-py3-none-any.whl`
- Follow **Install KUKSA.VAL** section from [https://github.com/GENIVI/iot-event-analytics/tree/develop/docker/vss2iotea/README.md](https://github.com/GENIVI/iot-event-analytics/tree/develop/docker/vss2iotea/README.md) to __download AND load__ the latest version of KUKSA.VAL into your local Docker registry.<br>
  Update the _.env_ file (KUKSA_VAL_IMG) with
  - __>> AMD64 platform only: <<__ `amd64/kuksa-val:<version>`
  - __>> ARM64 platform only: <<__ `arm64/kuksa-val:<version>`
- Check your configuration using `docker-compose -f docker-compose.edge.yml config`
- Now you can run the platform by purely using docker-compose i.e. without the `<run-script>`. See bottom of [Run](Run) section;

## Run

### >> AMD64 platform only <<

- __>> Windows only <<__<br>
  `<run-script>` is _run.bat_
- __>> Linux only <<__<br>
  `<run-script>` is _run.sh_

- Start using the \<run-script\>
  - Update the _IOTEA\_PROJECT\_DIR_ variable in the _.env_  file to the location of the iot-event-analytics
    submodule. If _IOTEA\_PROJECT\_DIR_ does not exist, it will be created and the repository will be cloned. Make sure you specify the
    _IOTEA\_VERSION_ (in `run.properties`) in this case in order to check out a specific version of IoT Event Analytics.<br>
  There is no guarantee, that the stack works, if you choose diverging versions (minor, or major versions) of _IOTEA\_VERSION_, _IOTEA\_JS\_SDK_ and _IOTEA\_PYTHON\_SDK_
  - You can start the platform using `<run-script>` OR equivalently `<run-script> .env run.properties`
  - If you want to change the default configuration, you can EITHER
    - Copy _run.properties_ and _.env_ to a custom location and provide the names as parameters. i.e. `<run-script> <custom .env path> <custom run.properties path>`
    - Merge both files into one and call `<run-script> <custom merged file path>`
    - If you want to configure every single component of the Vehicle Edge stack, copy the whole _./config_ folder to `<some-custom-config-folder>`. Change the _CONFIG\_DIR_ variable to the absolute path to this folder e.g. `/home/user/<some-custom-config-folder>`<br>
      It should look like this<br>

      ```text
      /home/user/<some-custom-config-folder>
      |- hal-interface
      |  L- config.json
      |- hal-interface-adapter
      |  |- config.json             // Needs to have the correct JSON Web token, to authenticate against Kuksa.Val
      |  L- mapping.json
      |- iotea-platform
      |  |- channels
      |  |  |- talent.channel.json
      |  |  |- talent.schema.json
      |  |  |- vss.channel.json
      |  |  |- vss.schema.json
      |  |  L- vss.transform.jna
      |  |- config.json
      |  |- types.json              // Needs to have type configuration, which matches the provided Vehicle Signal Specification
      |  L- uom.json
      |- mosquitto
      |  |- local
      |  |  L- config.json
      |  L- remote
      |  |  L- config.json
      |- vss                        // Read the provided README.md in this folder to obtain all the needed Kuksa.Val configuration files
      |  |- certs
      |  |  |- jwt.key.pub
      |  |  |- Server.key
      |  |  L- Server.pem
      |  L- vss.json
      L- vss2iotea
        L- config.json              // Needs to have the correct JSON Web token, to authenticate against Kuksa.Val
      ```

- Start it without the `<run-script>` script using standalone docker-compose: `docker-compose -f docker-compose.edge.yml --project-name vehicle-edge-platform --env-file .env -- up --build --remove-orphans`<br>
  If you have a custom _.env_ file for your project, you can specify it using a different value for the --env-file parameter

## Test

- Start the Vehicle Edge stack by using the instructions given in the previous __[Run](##Run)__ section
  - The Vehicle Application BrakeLightTalent is automatically started along with the stack
