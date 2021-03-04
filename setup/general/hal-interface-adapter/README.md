<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Hardware Abstraction Layer Interface Adapter - HAL Interface Adapter

## Important: ONLY WORKS WITH >= boschio.iotea-2.1.0.tgz PACKAGE

## Prerequisites

### >> ARM64 target platform only <<

- Make sure you have Docker 19.03 or above installed and experimental CLI features enable to be able to perform cross platform builds

## Build

- Download the latest npm package from [here](https://github.com/GENIVI/iot-event-analytics/src/sdk/javascript/lib) and copy it into the _src/vapp.hal-interface-adapter_ folder
- Open the folder _src/vapp.hal-interface-adapter_
- Docker build arguments:
  - _IOTEA_JS_SDK_ (__mandatory__): Specify the npm module e.g. `boschio.iotea-1.7.0.tgz`, that you downloaded above. It is needed at buildtime
- For further information how to build the images (especially, if you are working behind a proxy), please see [here](https://github.com/GENIVI/iot-event-analytics/docker/)

### >> ARM64 target platform only <<

- Build your Docker image and export the image as tar-archive<br>
  `docker buildx build --platform linux/arm64 -t hal-interface-adapter-arm64:<version> -o type=oci,dest=./hal-interface-adapter-arm64.<version>.tar --build-arg IOTEA_JS_SDK=boschio.iotea-<version> -f Dockerfile.arm64 .`
- Import this image
  - `sudo docker load --input hal-interface-adapter-arm64.<version>.tar`
  - `sudo docker tag <SHA256-Hash> hal-interface-adapter-arm64:<version>`

### >> AMD64 target platform only <<

- Build your Docker image using the local registry<br>
  `docker build --build-arg IOTEA_JS_SDK=boschio.iotea-<version> -t hal-interface-adapter-amd64:<version> -f Dockerfile.amd64 .`

## Install

- Create a folder to store the configuration `<some folder>`
- Copy the contents of the configuration folder _./config_ to `<some folder>`<br>
  The directory structure looks like this<br>

  ```code
  <some-folder>
  |- config.json
  L- mapping.json
  ```

- Edit the files to match your needs<br>
  All configuration options in _mapping.json_

  ```json
  [
    {
      "halResourceId": "8.BrakeSwitchStatus",
      "halValuePath": "value",
      "halValueMapping": {                            // raw value mapping (optional)
        "Normal Condition": 0,
        "Brake Pedal Pressed": 1,
        "(Undefined)": 2,
        "Brake Switch Fault": 3
      },
      "retainValue": true,                            // If true, retain the last value and republish it if the feature is requested (default = true)
      "halValueFactor": 0.5,                          // scaling for numerical values (optional)
      "halValueOffset": 100,                          // offsetting for numerical values (optional)
      "vssPath": "Vehicle.Body.Lights.IsBrakeOn",     // MAKE SURE it's compatible path notation for the current Kuksa.VAL version
      "vssBypass": false                              // Send events directly to IoT Event Analytics Platform without publishing them to Kuksa.VAL
                                                      // Global setting in config.json will be overridden by this signal-based value
    },
    {
      ...
    }
  ]
  ```

  All configuration options in _config.json_

  ```json
  {
    "loglevel": "DEBUG",                                    // Can be VERBOSE, DEBUG, INFO, WARN, ERROR
    "iotea": {
      "mqtt": {
        "connectionString": "mqtt://localhost:1883",
        "ns": "iotea/"
      },
      "subject": "<Some userId>",                           // Mandatory, if Kuksa.VAL should be bypasseed, vss.ws is not given and/or vss.subjectPath is undefined
      "instance": "<The VIN, or serial number>"             // Mandatory, if Kuksa.VAL should be bypasseed, vss.ws is not given and/or vss.instancePath is undefined
    },
    "vss": {
      "ws": "ws://localhost:8090",                          // (Default: undefined) If not given, all events will be automatically sent to IoT Event Analytics
                                                            // iotea.subject AND iotea.instance are mandatory
      "jwt": "<JSON Web Token>",                            // (Default: undefined) If not given, all events will be automatically sent to IoT Event Analytics
                                                            // iotea.subject AND iotea.instance are mandatory
      "bypass": false,                                      // (Default: false) If true, send all signal events to IoT Event Analytics Event Analytics per default
                                                            // You can override this globel setting, by setting the bypass flag in your mapping configuration (mapping.json)
      "subjectPath": "Vehicle.VehicleIdentification.VIN",   // (Default: undefined) Subject will be read from the given path, if vss.ws and vss.jwt are also given
                                                            // If undefined AND at least one event has to be bypass Kuksa.VAL, iotea.subject is mandatory
                                                            // MAKE SURE it's compatible path notation for the current Kuksa.VAL version
      "instancePath": "Vehicle.Driver.Identifier.Subject",  // (Default: undefined) Instance will be read from the given path, if vss.ws and vss.jwt are also given
                                                            // If undefined AND at least one event has to be bypass Kuksa.VAL, iotea.instance is mandatory
                                                            // MAKE SURE it's compatible path notation for the current Kuksa.VAL version
      "pathConfig": {
        "separator": ".",                                   // Separators, which are used for different hierarchical layers in VSS paths
        "replacer": {
          ".": "$"                                          // Which characters have to be replaced (from left to right) to derive IoT Event Analytics compatible type and feature from VSS paths
                                                            // Also used to transform given type and feature from IoT Event Analytics into VSS paths to check whether mappings are present in mapping.json
        }
      }
    },
    "hal": {
      "mqtt": {
        "connectionString": "mqtt://localhost:1883",
        "ns": "hal/"
      }
    }
  }
  ```

## Run

- `docker run --log-opt max-size=1m --log-opt max-file=5 --network="host" --restart=unless-stopped -d=true --name=hal-interface-adapter-<version> -v <some folder>:/home/node/app/config hal-interface-adapter-<arch>:<version>`

### >> Linux only <<

- You have to prepend `sudo` to the docker call if you run docker as root (and you are not)

## Test

- __Prerequisites__
  - NodeJS has to be installed >=12.13.0
  - Python has to be installed >=3.6.8
- [Start the IoT Event Analytics platform using docker-compose](https://github.com/GENIVI/iot-event-analytics)
- Start KUKSA Val server following the guide [here](../vss/README.md)
- Copy __../hal-interface/config_ into _../../src/hal-interface/src_
  - Open a console at _../../src/hal-interface/src_ and execute `python run.py`
- Copy __./config_ into _../../src/hal-interface-adapter/src_
  - Open a console at _../../src/hal-interface-adapter/src_ and execute `node index.js`
- Send the following MQTT message to `iotea/platform/$events`

  ```json
  {
    "type": "platform.talent.rules.set",
    "data": {
      "talent": "Some-Test-Talent",
      "rules": {
        "typeSelector": "Vehicle",
        "feature": "Body$Lights$IsBrakeOn"
      }
    }
  }
  ```

- Now you should see in the logs, that HAL Interface adapter is continuously pushing values into KUKSA.Val
