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

SET ARCH=amd64
SET VARIANT
SET DOCKER_IMAGE_PREFIX=vehicle-edge
SET BATCH_PATH=%~dp0
SET DOCKER_IMAGE_DIR=%BATCH_PATH%images
SET YML=-f docker-compose.stack.yml
SET WITH_KUKSA_VAL=0
SET WITH_TALENT=0
SET DOCKER_IMAGE_BUILD=1
SET DOCKER_IMAGE_EXPORT=0
SET DOCKER_CONTAINER_START=1

echo %DOCKER_IMAGE_DIR%

REM Enable buildkit support
SET DOCKER_BUILDKIT=1

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

IF %WITH_TALENT% == 1 (
    SET YML=%YML% -f docker-compose.talent.yml
)

IF NOT %WITH_KUKSA_VAL% == 1 (
    GOTO SkipKuksaVal
)

REM Check if local image of Kuksa.val is already loaded
SET DOCKER_LIST_COMMAND=docker images %KUKSA_VAL_IMG%
FOR /f "tokens=1-2" %%i IN ('%DOCKER_LIST_COMMAND%') DO SET EXISTING_KUKSA_IMAGE=%%i:%%j

REM Load the downloaded image into the local registry
SET DOCKER_LOAD_COMMAND=docker image load --input "%TMP%\kuksa-val-%ARCH%.tar.xz"

IF NOT %EXISTING_KUKSA_IMAGE% == %KUKSA_VAL_IMG% (
    REM Download image of Kuksa.val
    powershell -Command "Invoke-WebRequest %KUKSA_URL% -OutFile %TMP%\kuksa-val-%ARCH%.tar.xz"
    REM Store image name in variable KUKSA_VAL_IMG
    REM Output of command is Loaded image: image_name_and_tag -- pick 3rd token - maybe a bit fragile
    FOR /f "tokens=3" %%i IN ('%DOCKER_LOAD_COMMAND%') DO SET KUKSA_VAL_IMG=%%i
    REM Remove the file after loading
    DEL "%TMP%\kuksa-val-%ARCH%.tar.xz"
) ELSE (
    echo Using existing image %KUKSA_VAL_IMG%
)

SET YML=%YML% -f docker-compose.kuksa.val.yml

:SkipKuksaVal

REM Print configuration
docker-compose %YML% config

IF %DOCKER_IMAGE_BUILD% == 1 (
    REM Build all images
    docker-compose %YML% --project-name %DOCKER_IMAGE_PREFIX% build --force-rm --no-cache
)

IF %DOCKER_IMAGE_EXPORT% == 1 (
    REM Make image dir
    IF NOT EXIST "%DOCKER_IMAGE_DIR%\" (
        mkdir "%DOCKER_IMAGE_DIR%"
    )

    REM Export images
    FOR /f "skip=1 tokens=1,2" %%i IN ('docker images -f "reference=%DOCKER_IMAGE_PREFIX%*" -f "label=arch=%ARCH%"') DO (
        docker save %%i:%%j -o "%DOCKER_IMAGE_DIR%\%%i.%ARCH%.tar"
    )

    REM Export Kuksa.VAL image
    IF %WITH_KUKSA_VAL% == 1 (
        docker save %KUKSA_VAL_IMG% -o "%DOCKER_IMAGE_DIR%\%DOCKER_IMAGE_PREFIX%_kuksa.val.%ARCH%.tar"
    )
)

IF %DOCKER_CONTAINER_START% == 1 (
    REM Starting containers
    REM Since environment variables have precedence over variables defined in .env, nothing has to be changed here, if another .env-file is chosen as startup parameter
    docker-compose %YML% --project-name %DOCKER_IMAGE_PREFIX% up --remove-orphans
)

ENDLOCAL

:error
cd %BATCH_PATH%