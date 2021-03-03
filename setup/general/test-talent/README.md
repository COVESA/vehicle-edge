<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Test Talent

## Prerequisites

### >> ARM64 target platform only <<

- Make sure you have Docker 19.03 or above installed and experimental CLI features enable to be able to perform cross platform builds

## Build

- Download the latest npm package from [here](https://<Github IoTea repo>/src/sdk/javascript/lib) and copy it into the _setup/general/test-talent_ folder
- Open the folder _setup/general/test-talent_
- Docker build arguments:
  - _IOTEA_JS_SDK_ (__mandatory__): Specify the npm module e.g. `boschio.iotea-1.7.0.tgz`, that you downloaded above. It is needed at buildtime

### >> ARM64 target platform only <<

- Build your Docker image and export the image as tar-archive<br>
  `docker buildx build --platform linux/arm64 -t test-talent-arm64:<version> -o type=oci,dest=./test-talent-arm64.<version>.tar --build-arg IOTEA_JS_SDK=boschio.iotea-<version> -f Dockerfile.arm64 .`
- Import this image
  - `sudo docker load --input test-talent-arm64.<version>.tar`
  - `sudo docker tag <SHA256-Hash> test-talent-arm64:<version>`

### >> AMD64 target platform only <<

- Build your Docker image using the local registry<br>
  `docker build --build-arg IOTEA_JS_SDK=boschio.iotea-<version> -t test-talent-amd64:<version> -f Dockerfile.amd64 .`

## Run

- `docker run --log-opt max-size=1m --log-opt max-file=5 --network="host" --restart=unless-stopped -d=true --name=test-talent-<version> test-talent-<arch>:<version>`

### >> Linux only <<

- You have to prepend `sudo` to the docker call if you run docker as root (and you are not)
