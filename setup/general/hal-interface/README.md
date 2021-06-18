<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Hardware Abstraction Layer Interface - HAL Interface

## Prerequisites

- Make sure your installed version of Python is 3.6.x or above
  - Check that with `python --version`

## Run from source

- Open the the project root directory in a terminal
- Run `python src/edge.hal-interface/src/run.py -c ./setup/general/hal-interface/config`

## Configure

- Copy the contents from _./config_ into a new folder
  - Adapt this configuration according to your needs (see below)
- Optionally create the folder `resources` e.g. for mock CAN-signal files
- The directory structure of your configuration folder should look like this<br>

  ```code
  config
  |- config.json
  L- resources
     |- sampledata.txt (optional)
     L- *.dbc (optional)
  ```

### Configuration

Configure start of mock, by setting _interface_ property in _config.json_ to "mock"

```json
{
    "loglevel": "DEBUG",               // One of [ DEBUG, INFO, WARNING, ERROR, CRITICAL ]
    "can": [
        {
            "interface": "mock",
            "signals": {
                "8.BrakeSwitchStatus": {
                    "values": [
                        "Normal Condition",
                        "Brake Pedal Pressed",
                        "(Undefined)",
                        "Brake Switch Fault"
                    ],
                    "intervalMs": 1000,
                    "jitterMs": 500,
                    "useSignalRequestTriggers": true // defaults to true, Uses messages via enable/disable to start and stop the generator
                },
                "9.Test": {
                    "min": 0,
                    "max": 3,
                    "multipleOf": 0.1, // defaults to 1
                    "maxDelta": 0.5, // Maxiumum difference between subsequent values
                    "intervalMs": 500, // defaults to 1000
                    "jitterMs": 100,    // defaults to 500
                    "useSignalRequestTriggers": true // defaults to true, Uses messages via enable/disable to start and stop the generator
                },
                "10.Test": {
                    "pattern": [1, 2, 3, 4, 5], // values are sent one after another
                    "intervalMs": 1500,
                    "jitterMs": 1000,
                    "useSignalRequestTriggers": true // defaults to true, Uses messages via enable/disable to start and stop the generator
                },
                "11.Test": {
                    "file": "", // relative filepath to hal-interface executable or absolute filepath i.e. resources/sampledata.txt
                                // The filename determines the singnals datatype
                                // sampledata-int.txt >> signals are treated as integers
                                // sampledata-float.txt >> signals are treated as float values
                                // sampledata.txt and sampledata-string.txt >> signals are treated as string values
                    "baseTimeMs": 0, // defaults to 0, Time, which will be subtracted from all given times in the file
                    "useSignalRequestTriggers": false // Use messages via start/stop to start and stop the generator manually
                }
            }
        },
        {
            "interface": "can0",
            "bustype": "socketcan",
            "dbc": [
                "resources/X590_18MY_Hi_PMZ_HSCAN.dbc"
            ],
            "signalThrottleMs": {
                "foo.bar": 1000
            }
        }
    ],
    "protocolGateway": {
        "adapters": [
            {
                "platform": true,
                "module": {
                    "name": ".util.mqtt_client",
                    "class": "MqttProtocolAdapter"
                },
                "config": {
                    "topicNamespace": "hal/",
                    "brokerUrl": "mqtt://mosquitto:1883"
                }
            }
        ]
    }
}
```

### >> CANMock only <<

Each signal can be configured either by specifying a minimum and a maximum with stepping or by specifying all possible values. The interval specifies the base time interval in which events are sent. The jitter in milliseconds is the variation of the base timeinterval.<br>
Example: _intervalMs_ = 1000 and _jitterMs_ = 500 means, that events have a delay between 500ms and 1500ms.

By specifiying the _file_ property as timeseries input, the file needs to look like this:

```text
1,1000
2,2000
3,3000
4,3100
5,3200
6,3300
7,3400
```

The first entry is the signal value, the second entry is the timestamp in milliseconds on which the signal ocurred. To baseline the given timestamps, the property _baseTimeMs_ in the configuration of this signal.

### >> CAN only <<

Specify an arbitary amount of dbc files, which should be used to decode the received signals from the given CAN bus.
As default, all signals are published when they change. For continuous values like speed, _signalThrottleMs_ gives the opportunity to set the minimum delay between to signals until they are published again.

## Build

### >> ARM64 target platform only <<

- Build your Docker image and export the image as tar-archive<br>
  `docker buildx build --platform linux/arm64 -t hal-interface-arm64:<version> -o type=oci,dest=./hal-interface-arm64.<version>.tar -f src/hal-interface/Dockerfile.arm64 .`
- Import this image
  - `sudo docker load --input hal-interface-arm64.<version>.tar`
  - `sudo docker tag <SHA256-Hash> hal-interface-arm64:<version>`

### >> AMD64 target platform only <<

- Build your Docker image using the local registry<br>
  `docker build -t hal-interface-amd64:<version> -f src/hal-interface/Dockerfile.amd64 .`

## Run within container

`docker run hal-interface-<arch>:<version> -v <config folder>:/app/config`

## Misc

### >> Linux only <<

- check if a virtual CAN bus device is there `sudo modprobe vcan`

- setting up virtual CAN port: <br>
  `sudo ip link add dev vcan0 type vcan` <br>
  `sudo ifconfig vcan0 up`

- See statistics of CAN device<br>
  `ip -details -statistics link show can0`
- Configure loopback for canX to be able to write frames directly to the socketcan driver<br>
  See [here](https://wiki.rdu.im/_pages/Application-Notes/Software/can-bus-in-linux.html)
  - `sudo nano /etc/network/scripts/can0.sh`
    - Add `loopback on` to line with `/sbin/ip link set....loopback on`
    - Repeat for with file _/etc/network/scripts/can1.sh_
