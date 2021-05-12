<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Hardware Abstraction Layer Interface Adapter - HAL Interface Adapter

## Prerequisites

### >> ARM64 target platform only <<

- Make sure you have Docker 19.03 or above installed and experimental CLI features enable to be able to perform cross platform builds

## Install

- Run `yarn` in the project root to install all required dependencies

## Run from source

- Open the project root directory in a terminal
- Run `node src/edge.hal-interface-adapter/src/index.js -c ./setup/general/hal-interface-adapter/config-no-kuksa`

## Custom configuration

- Create a folder to store the configuration `<some folder>`
- Copy the contents of the configuration folder _./setup/general/hal-interface-adapter/config_ to `<some folder>`<br>
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

## Build

### >> ARM64 target platform only <<

- Build your Docker image and export the image as tar-archive<br>
  `docker buildx build --platform linux/arm64 -t hal-interface-adapter-arm64:<version> -o type=oci,dest=./hal-interface-adapter-arm64-<version>.tar -f src/edge.hal-interface-adapter/Dockerfile.arm64 .`
- Import this image
  - `sudo docker load --input hal-interface-adapter-arm64.<version>.tar`
  - `sudo docker tag <SHA256-Hash> hal-interface-adapter-arm64:<version>`

### >> AMD64 target platform only <<

- Build your Docker image using the local registry<br>
  `docker build -t hal-interface-adapter-amd64:<version> -f src/edge.hal-interface-adapter/Dockerfile.amd64 .`

## Run within container

- `docker run --log-opt max-size=1m --log-opt max-file=5 --network="host" --restart=unless-stopped -d=true --name=hal-interface-adapter-<version> -v <some folder>:/app/config hal-interface-adapter-<arch>:<version>`

### >> Linux only <<

- You have to prepend `sudo` to the docker call if you run docker as root (and you are not)
