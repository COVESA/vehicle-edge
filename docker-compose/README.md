<!---
  Copyright (c) 2021 Robert Bosch GmbH

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  SPDX-License-Identifier: MPL-2.0
-->

# Start the whole VAPP Stack on your local machine using docker-compose

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

### (Optional) Linux px-proxy configuration

If you are running behind a px-proxy on Linux (e.g. using [Bosch Open Source desktop](https://inside-docupedia.bosch.com/confluence/x/nRujEQ)) you need to ensure the binding between your docker network and proxy is configured.

- __~/.px/config.ini:__ Ensure binding ___"binds = [...], \<docker network proxy\>___ (e.g. 172.17.0.1:3128) exists

  ```code
  [server]
  binds = 127.0.0.1:3128, 172.17.0.1:3128#`
  ```

  If not, add it and restart your proxy (e.g. via _osd-proxy-restart_ for osd)

  To check that the binding exists you can call for your proxy port (e.g. 3128):
  `netstat -ntlpn | grep -i 3128`

  Which should show the your docker-network proxy (e.g. 172.17.0.1:3128):
  `tcp       0     0 172.17.0.1:3128        0.0.0.0:*              LISTEN     12391/python3`

- __~/.docker/config.json:__ Ensure _http(s)Proxys_ in your docker-network have the same port as your host proxy (e.g. (´[http://172.17.0.1:__3128__](http://172.17.0.1:__3128__))

```json
{
 "proxies":
 {
   "default":
   {
     "httpProxy": "http://172.17.0.1:3128",
     "httpsProxy": "http://172.17.0.1:3128"
   }
 }
}
```

- __/etc/systemd/system/docker.service.d/http_proxy.conf__: Ensure that the http(s)_proxies are set

```code
[Service]
Environment=HTTP_PROXY=http://localhost:3128/
Environment=HTTPS_PROXY=http://localhost:3128/
```

Afterwards you have to restart your docker daemon:
`sudo systemctl daemon-reload`
`sudo systemctl restart docker`

To check your env-variables for docker you can call:
`sudo systemctl show --property=Environment docker`

## Setup

- If you are behind a corporate proxy, specify DOCKER_HTTP_PROXY and DOCKER_HTTPS_PROXY in the _.env_ file. __If NOT, remove these lines completly from the .env file__
  - __>> Windows only: <<__ Use `docker.for.win.localhost` to refer to your computer i.e. _[http://docker.for.win.localhost:3128](http://docker.for.win.localhost:3128)_ assuming your proxy is running locally on Port 3128
  - __>> Linux only: <<__ Use _[http://172.17.0.1:3128](http://172.17.0.1:3128)_ as proxy address

### Scripted

Setup can be easily bootstrapped by using the `<run-script>`. In order to do so directly proceed with the [Run](##Run) section

### Manual

- Clone the [IoT Event Analytics](https://github.com/GENIVI/iot-event-analytics) repository into `<any folder>` using git<br>
  Update the _.env_ file (IOTEA_PROJECT_DIR) with the absolute path to `<any folder>` - could be any valid local folder<br>
  You can checkout a specific version tag if desired. __This version should match the SDKs you are copying in the next steps!__
- Copy `<any folder>/src/sdk/javascript/lib/boschio.iotea-<version>.tgz` into _/src/vapp.hal-interface-adapter_ AND _/docker-compose/talent_<br>
  Update the _.env_ file (IOTEA_JS_SDK) with `boschio.iotea-<version>.tgz`
- Copy `<any folder>/src/sdk/python/lib/boschio_iotea-<version>-py3-none-any.whl` into the _/src/vapp.hal-interface_ directory<br>
  Update the _.env_ file (IOTEA_PYTHON_SDK) with `boschio_iotea-<version>-py3-none-any.whl`
- Follow **Install KUKSA.VAL** section from [https://github.com/GENIVI/iot-event-analytics/docker/vss2iotea/README.md](https://https://github.com/GENIVI/iot-event-analytics/browse/docker/vss2iotea/README.md) to __download AND load__ the latest version of KUKSA.VAL into your local Docker registry.<br>
  Update the _.env_ file (KUKSA_VAL_IMG) with
  - __>> AMD64 platform only: <<__ `amd64/kuksa-val:<version>`
  - __>> ARM64 platform only: <<__ `arm64/kuksa-val:<version>`
- Check your configuration using `docker-compose -f docker-compose.vapp.amd64.yml config`
- Now you can run the platform by purely using docker-compose i.e. without the `<run-script>`. See bottom of [Run](Run) section;

## Run

### >> AMD64 platform only <<

- Make sure docker-compose is installed on your system `docker-compose --version`
  - __>> Linux only <<__ To install missing docker-compose<br>
    `sudo apt-get -y -q install docker-compose`<br>
    If docker-compose packgage is missing or too old, directly download the binary<br>

    ```text
    sudo curl -q -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    ```

- __>> Windows only <<__<br>
  `<run-script>` is _run.bat_
- __>> Linux only <<__<br>
  `<run-script>` is _run.sh_

- Starting the \<run-script\>
  - If you want to keep the current configuration in _run.properties_ and _.env_ simply call `<run-script>` OR equivalently `<run-script> .env run.properties`
  - The variables _IOTEA\_VERSION_ (in `run.properties`) and _IOTEA_PROJECT_DIR_ (in `.env`) are only important, if the IoT Event Analytics respository is cloned for the first time. This given tag will be checked out to the given project directory.<br>
    There is no guarantee, that the stack works, if you choose diverging versions in _IOTEA\_VERSION_, _IOTEA\_JS\_SDK_ and _IOTEA\_PYTHON\_SDK_
  - If you want to change the default configuration, you can EITHER
    - Copy _run.properties_ and _.env_ to a custom location and provide the names as parameters. i.e. `<run-script> <custom .env path> <custom run.properties path>`
    - Merge both files into one and call `<run-script> <custom merged file path>`
    - If you want to configure every single component of the VAPP-Stack, copy the whole _./config_ folder to `<some-custom-config-folder>`. Change the _CONFIG\_DIR_ variable to the absolute path to this folder e.g. `/home/user/<some-custom-config-folder>`<br>
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

- Start it without the `<run-script>` script using standalone docker-compose: `docker-compose -f docker-compose.vapp.amd64.yml --project-name vapp-platform --env-file .env -- up --build --remove-orphans`<br>
  If you have a custom _.env_ file for your project, you can specify it using the --env-file parameter (Requires Compose >1.27.0)

## Test

- Start the VAPP stack by using the instructions given in the previous __[Run](##Run)__ section
  - The talent BrakeLightTalent is automatically started along with the stack
- If you want to additionally test your own talent do the following:
  - Install NodeJS
    - Verify installed version. It should be >12.13.0<br>
      `node --version`
    - __>> Linux only <<__ To update old/missing NodeJS<br>

    ```text
    sudo apt install npm nodejs -y
    sudo npm install -g n
    sudo n latest
    ```

  - Install docker-compose
    - Check your installed version by executing `docker-compose --version`
      - It should be > 1.27.4
    - __>> Linux only <<__<br>
      `sudo apt-get -y -q install docker.io docker-compose`
      - If docker-compose packgage is missing or too old, directly download binary:

        ```text
        sudo curl -q -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        ```

  - Copy `<any folder>/src/sdk/javascript/lib/boschio.iotea-<version>.tgz` into your talent directory
    - Pick the same file as defined in the _.env_ file IOTEA_JS_SDK
  - Install it by typing `npm install boschio.iotea-<version>.tgz`
    - If you have problems with the installation behind the corporate proxy try the following:

      ```text
      npm config set proxy ${HTTP_PROXY}
      npm config set https-proxy ${HTTPS_PROXY}
      npm config set strict-ssl false -g
      npm config set maxsockets 5 -g
      ```

    - If npm still can't successfully install the needed packages, it is possible to execute the installation on your host (e.g. Windows) and copy downloaded `node_modules` dir to Linux VM.
  - You can use the following connectionString to connect your talent to:
    - `mqtt://localhost:1883` for a local talent
    - `mqtt://localhost:1884` for a remote talent (Do not forget to override function isRemote/is_remote and return `true`)
  - Run `node index.js` to start the test talent. You should see incoming events, after your talent was registered successfully. You may have to wait up to 30 seconds until the next discovery is sent around.
