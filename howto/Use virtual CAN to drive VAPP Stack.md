Use virtual CAN to drive VAPP Stack
===================================

When installing the Vehicle-Edge stack and run it via Docker-Compose the virtual CAN Bus is not accessible. To prepare real-live scenarios this is essential. This tutorial describes how to set things up to use the virtual CAN Bus.

Assuming the VAPP stack was started with `vehicle-edge/docker-compose/run.sh` you should have this containers running:

``` 
my_vm:~$ sudo docker ps
CONTAINER ID        IMAGE                                       COMMAND                         NAMES
d3aec28732e0        vehicleedgeplatform_hal-interface           "python run.py"                 vehicleedgeplatform_hal-interface_1
8218fc328651        vehicleedgeplatform_test-talent             "docker-entrypoint.s…"          vehicleedgeplatform_test-talent_1
eb4cb67afb2d        vehicleedgeplatform_hal-interface-adapter   "docker-entrypoint.s…"          vehicleedgeplatform_hal-interface-adapter_1
d4bcfd92b633        vehicleedgeplatform_vss2iotea               "node /app/docker/vs…"          vehicleedgeplatform_vss2iotea_1
0c271a73ed3f        vehicleedgeplatform_pipeline                "node /app/docker/pi…"          vehicleedgeplatform_pipeline_1
e52206ac8d56        vehicleedgeplatform_configmanager           "node /app/docker/co…"          vehicleedgeplatform_configmanager_1
abac1f5483ef        vehicleedgeplatform_mosquitto-local         "/mosquitto/run.sh"             vehicleedgeplatform_mosquitto-local_1
e73570a42919        amd64/kuksa-val:863db65                     "/bin/sh -c /kuksa.v…"          vehicleedgeplatform_kuksa-val_1
36d82ab6d0ae        vehicleedgeplatform_mosquitto-remote        "/mosquitto/run.sh"             vehicleedgeplatform_mosquitto-remote_1
```


To get to the CAN Bus the HAL-Interface container is stopped and HAL-Interface started as a process:
``` 
my_vm:~$ sudo docker rm -f vehicleedgeplatform_hal-interface_1
vehicleedgeplatform_hal-interface_1
```

Setup your HAL-Interface config:

*   copy the content of [https://github.com/GENIVI/vehicle-edge/tree/develop/src/edge.hal-interface/src](https://github.com/GENIVI/vehicle-edge/tree/develop/src/edge.hal-interface/src) or your local ~/vehicle-edge/src/edge.hal-interface/src into a new directory
    
*   add a subdirectory "resources" and put in your dbc file
    
*   add a subdirecory "config" and put in a config.json. The details of config.json are [documented here](https://github.com/GENIVI/vehicle-edge/blob/develop/setup/general/hal-interface/README.md). See also "The directory structure should look like this" in the documentation.
    

A sample config.json could look like this:
```
{
    "loglevel": "DEBUG",
    "mqtt": {
        "connectionString": "mqtt://localhost:1883",
        "ns": "hal/"
    },
    "can": [
        {
            "interface": "vcan0",
            "bustype": "socketcan",
            "dbc": [
                "resources/ESP9.3_Doors3.35_v01.dbc"
            ],
            "signalThrottleMs": {
                "foo.bar": 1000
            }
        }       
    ]
}
```

Note the "connectionString": "[mqtt://localhost:1883](mqtt://localhost:1883)" opposed to "connectionString": "[mqtt://mosquitto-local:1883](mqtt://mosquitto-local:1883)"

Now start the HAL-Interface with python `run.py` .. you are ready to use the virutal CAN Bus on your VM.
