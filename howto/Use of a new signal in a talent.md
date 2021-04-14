When designing a new use case the need to implement a new or additional signal into the stack will arise. This tutorial will step through the needed configuration tasks for a signal not yet present in VSS. When using an existing signal skip the 1st step.


Assuming we want signals from the break subsystem on an occurance of a PotHole as outlined below:
```
vcan0       709   [8]  E0 4D 79 60 01 00 00 00 ::
CBDS_Connectivity_data(
    CBS_Message_ID: 'PotHole105',
    CBS_Event_ID: 3,
    CBS_PotHole_Time_Since_System_On: 931.56 s,
    CBS_PotHole_Amplitude_FL: 1100,
    CBS_PotHole_Amplitude_FR: 0,
    CBS_PotHole_Amplitude_RL: 0,
    CBS_PotHole_Amplitude_RR: 0 )
 
vcan0       709   [8]  E1 CF 00 00 00 00 00 00 ::
CBDS_Connectivity_data(
    CBS_Message_ID: 'PotHole106',
    CBS_Event_ID: 3,
    CBS_PotHole_Vehicle_Speed_Start: 10.3 m/s,
    CBS_PotHole_reserved: 0,
    CBS_PotHole_IsWiperStrokActive: 0 )
 
vcan0       709   [8]  60 F5 79 80 E6 01 00 00 ::
CBDS_Connectivity_data(
    CBS_Message_ID: 'PotHole105',
    CBS_Event_ID: 2,
    CBS_PotHole_Time_Since_System_On: 936.5999999999999 s,
    CBS_PotHole_Amplitude_FL: 5200,
    CBS_PotHole_Amplitude_FR: 750,
    CBS_PotHole_Amplitude_RL: 0,
    CBS_PotHole_Amplitude_RR: 0 )
```

To include this indication the `~/vehicle-edge/docker-compose/config/vss/vss.json` file has to be extended:
```
{
  "Vehicle": {
   ....
    "children": {
    .....
      "CBS": {
        "description": "Break System Data",
        "uuid": "bc7ba9a6-c10f-453b-a0e8-5db9ed7b47df",
        "type": "branch",
        "children": {
          "CBS_PotHole_Time_Since_System_On": {
            "description": "Time since system start, when pothole was detected.",
            "datatype": "float",
            "type": "sensor",
            "uuid": "ec433a35-57ad-4eb4-9547-30cb87580d01",
            "unit": "s"
          },
          "CBS_PotHole_Amplitude_FL": {
            "description": "Front Left tyre amplitude",
            "datatype": "uint32",
            "type": "sensor",
            "uuid": "ec433a35-57ad-4eb4-9547-30cb87580d02"
          },
          "CBS_PotHole_Amplitude_FR": {
            "description": "Front Right tyre amplitude",
            "datatype": "uint32",
            "type": "sensor",
            "uuid": "ec433a35-57ad-4eb4-9547-30cb87580d03"
 
            .......
```
The syntax of the [vss.json](https://genivi.github.io/vehicle_signal_specification/) file is decribed in the Vehicle Signal Specification project.

Note that the uuids need to be unique.


The talent can now register for this information, modify `~/vehicle-edge/docker-compose/talent/src/talent.js`:
```
getRules() {
    return new iotea.AndRules(
    [
        new iotea.Rule(new iotea.OpConstraint('CBS$CBS_PotHole_Time_Since_System_On', iotea.OpConstraint.OPS.ISSET, null, 'Vehicle', VALUE_TYPE_RAW)),
        new iotea.OrRules(
            [
                new iotea.Rule(new iotea.OpConstraint('CBS$CBS_PotHole_Amplitude_FL', iotea.OpConstraint.OPS.GREATER_THAN_EQUAL, 1500, 'Vehicle', VALUE_TYPE_RAW)),
                new iotea.Rule(new iotea.OpConstraint('CBS$CBS_PotHole_Amplitude_FR', iotea.OpConstraint.OPS.GREATER_THAN_EQUAL, 1500, 'Vehicle', VALUE_TYPE_RAW))
            ])
    ]);
}
```

The IoTea platform needs to learn about this signals via `~/vehicle-edge/docker-compose/config/iotea-platform/types.json` :

A detailed description of the types.json format is in the [IoTea documentation](https://sourcecode.socialcoding.bosch.com/projects/DBAO/repos/boschio.iotea/browse/docs/topics/iotea-types.md).
```
{
    "100000": {
        "features": {},
        "types": {
            "Vehicle": {
                "features": {
                    "CBS$CBS_Message_ID": {
                        "description": "Multiplex ID",
                        "idx": 0,
                        "history": 0,
                        "encoding": {
                            "type": "string",
                            "encoder": null
                        }
                    },
                    "CBS$CBS_PotHole_Time_Since_System_On": {
                        "description": "Time since system start, when pothole was detected.",
                        "idx": 1,
                        "history": 5,
                        "encoding": {
                            "type": "number",
                            "encoder": null
                        }
                    },
                    "CBS$CBS_PotHole_Amplitude_FL": {
                        "description": "Front Left tyre amplitude",
                        "idx": 2,
                        "history": 5,
                        "encoding": {
                            "type": "number",
                            "encoder": null
                        }
                    },
                    "CBS$CBS_PotHole_Amplitude_FR": {
                        "description": "Front Right tyre amplitude",
                        "idx": 3,
                        "history": 5,
                        "encoding": {
                            "type": "number",
                            "encoder": null
                        }
                    },             
                 ......
```

When reading this signal from the CAN Bus it needs to be translated into the stack by the HAL-Interface Adapter in `~/vehicle-edge/docker-compose/config/hal-interface-adapter/mapping.json`
```
[
    {
        "halResourceId": "709.CBS_Message_ID",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_Message_ID"
    },
    {
        "halResourceId": "709.CBS_PotHole_Time_Since_System_On",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_Time_Since_System_On"
    },
    {
        "halResourceId": "709.CBS_PotHole_Amplitude_FL",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_Amplitude_FL"
    },
    {
        "halResourceId": "709.CBS_PotHole_Amplitude_FR",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_Amplitude_FR"
    },
    {
        "halResourceId": "709.CBS_PotHole_Amplitude_RL",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_Amplitude_RL"
    },
    {
        "halResourceId": "709.CBS_PotHole_Amplitude_RR",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_Amplitude_RR"
    },
    {
        "halResourceId": "709.CBS_PotHole_Vehicle_Speed_Start",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_Vehicle_Speed_Start"
    },
    {
        "halResourceId": "709.CBS_PotHole_reserved",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_reserved"
    },
    {
        "halResourceId": "709.CBS_PotHole_IsWiperStrokActive",
        "halValuePath": "value",
        "vssPath": "Vehicle.CBS.CBS_PotHole_IsWiperStrokActive"
    }
]
```
The content of the mapping.json is outlined in the [HAL-Interface Adapter documentation](https://github.com/GENIVI/vehicle-edge/tree/develop/setup/general/hal-interface-adapter).


Once all this changes are implemented, you can start inject CAN signals into the system and react as needed. A typicaal inject might look like this:
```
cangen vcan0 -L 8 -I 709 -D e0ab2048006aa731
```