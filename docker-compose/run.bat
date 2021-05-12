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

SET DOCKER_IMAGE_PREFIX=vehicle-edge
SET BATCH_PATH=%~dp0

REM Load environment variables from provided scripts
:LoadEnvFilesLoop
    IF "%1"=="" (
        GOTO LoadEnvFilesLoopComplete
    )
    FOR /F "tokens=1,2 delims==" %%G IN (%1) DO (
        SET %%G=%%H
    )
    REM Remove the first variable from the inputs parameters
    SHIFT
    GOTO LoadEnvFilesLoop
:LoadEnvFilesLoopComplete

IF %USE_KUKSA_VAL% == 1 (
    GOTO UseKuksa
) ELSE (
    GOTO NoKuksa
)

:UseKuksa

REM Check if local image of Kuksa.val is already loaded
SET DOCKER_LOAD_COMMAND=docker images %KUKSA_VAL_IMG%
FOR /f "tokens=1-2" %%i IN ('%DOCKER_LOAD_COMMAND%') DO SET EXISTING_KUKSA_IMAGE=%%i:%%j

IF NOT %EXISTING_KUKSA_IMAGE% == %KUKSA_VAL_IMG% (
    REM Download image of Kuksa.val
    powershell -Command "Invoke-WebRequest %KUKSA_URL% -OutFile %TMP%\kuksa-val-amd64.tar.xz"
    REM Loading kuksa val and setting environment variable
    SET DOCKER_LOAD_COMMAND=docker image load --input %TMP%\kuksa-val-amd64.tar.xz
    REM Store image name in variable KUKSA_VAL_IMG
    REM Output of command is Loaded image: image_name_and_tag -- pick 3rd token - maybe a bit fragile
    FOR /f "tokens=3" %%i IN ('%DOCKER_LOAD_COMMAND%') DO SET KUKSA_VAL_IMG=%%i
    REM Remove the file after loading
    del %TMP%\kuksa-val-amd64.tar.xz
) ELSE (
    echo Using existing image %KUKSA_VAL_IMG%
)

REM Print configuration
docker-compose -f docker-compose.edge.yml config

REM Build all images
docker-compose -f docker-compose.edge.yml --project-name %DOCKER_IMAGE_PREFIX% up --build --no-start --remove-orphans --force-recreate

GOTO EndKuksa

:NoKuksa

REM Print configuration
docker-compose -f docker-compose.edge-no-kuksa.val.yml config

REM Build all images
docker-compose -f docker-compose.edge-no-kuksa.val.yml --project-name %DOCKER_IMAGE_PREFIX% up --build --no-start --remove-orphans --force-recreate

:EndKuksa

IF %DOCKER_IMAGE_EXPORT% == 1 (
    SET DOCKER_IMAGE_DIR = %BATCH_PATH%images

    REM Make image dir
    IF NOT EXIST %DOCKER_IMAGE_DIR%\NUL (
        mkdir %DOCKER_IMAGE_DIR%
    )

    REM Export images
    FOR /f "skip=1 tokens=1,2" %%i IN ('docker images -f "reference=%DOCKER_IMAGE_PREFIX%*"') DO (
        docker save %%i:%%j -o %DOCKER_IMAGE_DIR%\%i.%IOTEA_VERSION%.amd64.tar
    )
)

IF %DOCKER_CONTAINER_START% == 1 (
    REM Starting containers
    REM Since environment variables have precedence over variables defined in .env, nothing has to be changed here, if another .env-file is chosen as startup parameter
    docker-compose -f docker-compose.edge.yml --project-name %DOCKER_IMAGE_PREFIX% up
)

ENDLOCAL

:error
cd %BATCH_PATH%