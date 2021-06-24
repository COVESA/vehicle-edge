REM ##############################################################################
REM # Copyright (c) 2021 Robert Bosch GmbH
REM #
REM # This Source Code Form is subject to the terms of the Mozilla Public
REM # License, v. 2.0. If a copy of the MPL was not distributed with this
REM # file, You can obtain one at https://mozilla.org/MPL/2.0/.
REM #
REM # SPDX-License-Identifier: MPL-2.0
REM ##############################################################################

SETLOCAL EnableExtensions

SET BATCH_PATH=%~dp0
SET CONFIG_DIR=

SET JQ_URL=https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe

SET VSS_REPO=https://github.com/GENIVI/vehicle_signal_specification
SET TMP_VSS_PATH=%TMP%\vss

SET KUKSA_VAL_REPO=https://github.com/eclipse/kuksa.val
SET TMP_KUKSA_VAL_PATH=%TMP%\kuksa.val

SET USE_CONDA=0
WHERE conda

IF %ERRORLEVEL% EQU 0 (
    CALL conda activate
    SET USE_CONDA=1
)

if [%1]==[] (
    SET CONFIG_DIR=%BATCH_PATH%config
) ELSE (
    SET CONFIG_DIR=%1
)

ECHO "Using configuration base directory %CONFIG_DIR%"
PAUSE

IF NOT EXIST %CONFIG_DIR%\ (
    mkdir %CONFIG_DIR%
)

CALL :remove_dir_if_exists %TMP_VSS_PATH%

REM Cloning Vehicle Signal Specification Project
git clone %VSS_REPO% --recurse-submodules %TMP_VSS_PATH%

cd %TMP_VSS_PATH%\vss-tools

CALL :install_python_requirements requirements.txt %USE_CONDA%

SET VSS_TEMP_FILE=%TMP%\vss-1.json
SET VSS_TEMP_FILE_SWAP=%TMP%\vss-2.json

CALL python vspec2json.py -I Vehicle:vehicle.uuid ../spec/VehicleSignalSpecification.vspec "%VSS_TEMP_FILE%"

SET JQ_EXECUTABLE=%TMP%\jq.exe

IF NOT EXIST %JQ_EXECUTABLE% (
    POWERSHELL -Command "Invoke-WebRequest %JQ_URL% -OutFile %JQ_EXECUTABLE%"
)

REM Update the Subject and the Instance in the VSS tree
CALL "%JQ_EXECUTABLE%" ".Vehicle.children.Driver.children.Identifier.children.Subject.value=\"anyone\"" "%VSS_TEMP_FILE%" > "%VSS_TEMP_FILE_SWAP%"
CALL "%JQ_EXECUTABLE%" ".Vehicle.children.VehicleIdentification.children.VIN.value=\"anyinstance\"" "%VSS_TEMP_FILE_SWAP%" >"%CONFIG_DIR%\vss.json"

CALL :remove_dir_if_exists %TMP_KUKSA_VAL_PATH%

REM Cloning Kuksa.VAL Project
git clone %KUKSA_VAL_REPO% %TMP_KUKSA_VAL_PATH%

cd %TMP_KUKSA_VAL_PATH%\kuksa_certificates

SET KUKSA_VAL_CERTS_DIR=%CONFIG_DIR%\certs

REM Copy certificates
CALL :remove_dir_if_exists %KUKSA_VAL_CERTS_DIR%

CALL mkdir %KUKSA_VAL_CERTS_DIR%

COPY Server.* %KUKSA_VAL_CERTS_DIR%
COPY jwt\jwt.key.pub %KUKSA_VAL_CERTS_DIR%

REM Create new Json Web Token
cd %TMP_KUKSA_VAL_PATH%\kuksa_certificates\jwt

CALL :install_python_requirements requirements.txt %USE_CONDA%

CALL python createToken.py super-admin.json

COPY super-admin.json.token %CONFIG_DIR%\jwt.token

REM Update corresponding kuksa.val2iotea- and hal-interface-adapter configuration using jq

SET JWT_TOKEN=
for /F "delims=" %%A in (%CONFIG_DIR%\jwt.token) DO SET JWT_TOKEN=!JWT_TOKEN!%%A

:prompt_hal_interface_adapter_config_file
SET /p HAL_INTERFACE_ADAPTER_CONFIG_FILE="Specify the path to your HAL Interface adapter config.json: "
IF NOT EXIST %HAL_INTERFACE_ADAPTER_CONFIG_FILE% GOTO :prompt_hal_interface_adapter_config_file

CALL :replace_in_json "%JQ_EXECUTABLE%" ".[\"kuksa.val\"].jwt = \"%JWT_TOKEN%\"" "%HAL_INTERFACE_ADAPTER_CONFIG_FILE%"

:prompt_kuksaval2iotea_config_file
SET /p KUKSAVAL2IOTEA_CONFIG_FILE="Specify the path to your Kuksa.VAL2IoTea adapter config.json: "
IF NOT EXIST %KUKSAVAL2IOTEA_CONFIG_FILE% GOTO :prompt_kuksaval2iotea_config_file

CALL :replace_in_json "%JQ_EXECUTABLE%" ".[\"kuksa.val\"].jwt = \"%JWT_TOKEN%\"" "%KUKSAVAL2IOTEA_CONFIG_FILE%"

cd %BATCH_PATH%

ENDLOCAL

GOTO :eof

:replace_in_json
SETLOCAL EnableDelayedExpansion

(SET LF=^
%=DO NOT REMOVE THIS=%
)

SET OUTPUT=""
FOR /F "tokens=* delims=" %%F IN ('%~1 --indent 4 "%~2" "%~3"') DO (
    IF !OUTPUT! EQU "" (
        SET OUTPUT=%%F
    ) ELSE (
        SET OUTPUT=!OUTPUT!!LF!%%F
    )
)

ECHO !OUTPUT! > %~3

ENDLOCAL

GOTO :EOF

:install_python_requirements

IF %~2 EQU 1 (
    CALL pip install -r %~1 --user
) ELSE (
    CALL pip3 install -r %~1 --user
)

GOTO :EOF

:remove_dir_if_exists

IF EXIST %~1\ (
  CALL del /s /q %~1\*
  CALL rmdir /s /q %~1
)

GOTO :EOF