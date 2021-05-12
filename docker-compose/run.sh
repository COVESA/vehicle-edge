#!/bin/bash

##############################################################################
# Copyright (c) 2021 Robert Bosch GmbH
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# SPDX-License-Identifier: MPL-2.0
##############################################################################

load_config()
{
    local file="$1"
    while IFS='=' read -r key value; do
        # fix problems with crlf incompatiblities in read...
        key=${key//$'\r'}
        value=${value//$'\r'}
        # skip comments & empty lines
        if [ "$key" = "" ] || [ "${key:0:1}" = "#" ]; then
            continue
        fi
        echo "[`basename $file`] ${key}=${value}"
        export ${key}=${value}
    done < $file
}

exit_on_error()
{
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "$0 failed."
        exit $rc
    fi
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Create a subshell to allow local modifications, which do not affect the actual environment variables
DOCKER_IMAGE_PREFIX=vehicle-edge

CONFIG="$1"

if [ ! -f "$CONFIG" ]; then
	echo "Can't find: $CONFIG"
	echo "Usage $0 {.env file}"
	exit 1
fi

# Load the configurations

# default values for missing vars
ARCH="amd64"
USE_KUKSA_VAL=1
DOCKER_IMAGE_EXPORT=0
DOCKER_CONTAINER_START=1

# Load the configurations
load_config "$CONFIG"
load_config "$SCRIPT_DIR/run.properties"

# Check if project dir exists
if [ -d $IOTEA_PROJECT_DIR ]; then
    echo "Using folder: $IOTEA_PROJECT_DIR"
    # Go into the project directory
    cd $IOTEA_PROJECT_DIR
else
    # Create the iotea project directory
    mkdir -p $IOTEA_PROJECT_DIR
    # Clone boschio.iotea Repo
    git clone https://github.com/GENIVI/iot-event-analytics $IOTEA_PROJECT_DIR
    exit_on_error
    # Go into the project directory
    cd $IOTEA_PROJECT_DIR
    # Checkout the appropriate tag
    git checkout $IOTEA_VERSION
    exit_on_error
fi

echo

cd $SCRIPT_DIR

# Copy JS SDK
echo "# Copy JS SDK"
cp -v $IOTEA_PROJECT_DIR/src/sdk/javascript/lib/$IOTEA_JS_SDK $SCRIPT_DIR/../src/edge.hal-interface-adapter/
exit_on_error
# Copy <any folder>/src/sdk/javascript/lib/boschio.iotea-<version>.tgz into the ./talent
cp -v $IOTEA_PROJECT_DIR/src/sdk/javascript/lib/$IOTEA_JS_SDK $SCRIPT_DIR/talent/
exit_on_error

# Copy Python SDK
echo "# Copy Python SDK"
cp -v $IOTEA_PROJECT_DIR/src/sdk/python/lib/$IOTEA_PYTHON_SDK $SCRIPT_DIR/../src/edge.hal-interface/
exit_on_error

# Check if local image of KUKSA.VAL is already loaded
echo "# Checking for KUKSA_VAL_IMG: $KUKSA_VAL_IMG"
EXISTING_KUKSA_IMAGE=`sudo docker images --format '{{.Repository}}:{{.Tag}}' $KUKSA_VAL_IMG`

if [ -z "$EXISTING_KUKSA_IMAGE" ] || [ "$EXISTING_KUKSA_IMAGE" != "$KUKSA_VAL_IMG" ]; then

    # Download latest kuksa for $ARCH, KUKSA_VAL_IMG must be updated in $CONFIG with it's version
    if [ -z "$KUKSA_URL" ]; then
        echo "Warning! Missing KUKSA_URL in: $CONFIG"
        echo "Copy download link from: https://kuksaval.northeurope.cloudapp.azure.com/job/kuksaval-upstream/job/master/lastSuccessfulBuild/artifact/artifacts/kuksa-val-*-${ARCH}.tar.xz"
        exit 1
    fi

    echo "# Tyrying to download $KUKSA_VAL_IMG from: $KUKSA_URL ..."
    wget -q --no-check-certificate "$KUKSA_URL" -O kuksa-val-$ARCH.tar.xz
    exit_on_error

    # Store image name in variable KUKSA_VAL_IMG
    DOCKER_LOAD_RESULT=`sudo docker load --input kuksa-val-$ARCH.tar.xz`
    # Remove the file after loading
    rm kuksa-val-$ARCH.tar.xz

    # remove prefix from result
    LOADED_IMAGE="${DOCKER_LOAD_RESULT#Loaded image: *}"
    echo "# Imported kuksa.val: $LOADED_IMAGE"

    # As docker-compose uses KUKSA_VAL_IMG in $CONFIG, we can't override it, needs to be updated after each kuksa.val build.
    if [ "$LOADED_IMAGE" != "$KUKSA_VAL_IMG" ]; then
        echo "# WARNING! $KUKSA_URL image has version: $LOADED_IMAGE"
        echo "Please, check KUKSA_URL and KUKSA_VAL_IMG in $CONFIG"
        exit 1
    fi

    sudo docker images $KUKSA_VAL_IMG
    exit_on_error
else
    echo "# Using local image: $KUKSA_VAL_IMG"
fi

# docker-compose always uses .env file if it exists, so it overrides ARM64 variables with AMD..
# There is no option except putting all refered variables in .yml into dedicated .env file so sudo docker-compose
# can actually load those variables. Otherwise use -E to inherit exported variables in sudo session:
#  $ sudo -E docker compose --env-file /dev/null
# NOTE: This change breaks old docker-compose withoud --env-file support.
DOCKER_OPT="--env-file $CONFIG $DOCKER_OPT"

echo
echo "# Using docker-compose version:"
docker-compose --version

# Print configuration
echo
echo "# Print configuration"
sudo docker-compose $DOCKER_OPT -f docker-compose.edge.yml config
echo

if [ "$DOCKER_IMAGE_BUILD" = "1" ]; then
    # Build all images
    echo "# Build all images"
    # Since environment variables have precedence over variables defined in .env, nothing has to be changed here, if another .env-file is chosen as startup parameter
    sudo docker-compose $DOCKER_OPT -f docker-compose.edge.yml --project-name $DOCKER_IMAGE_PREFIX up --build --no-start --remove-orphans --force-recreate
	exit_on_error
fi

if [ "$DOCKER_IMAGE_EXPORT" = "1" ]; then
    # Export images
    DOCKER_IMAGE_DIR=$SCRIPT_DIR/images
    [ -d $DOCKER_IMAGE_DIR ] || mkdir -p $DOCKER_IMAGE_DIR

	echo
	echo # Exporting images to: $DOCKER_IMAGE_DIR ..."
	echo

    DOCKER_IMAGES=`sudo docker images -f "reference=$DOCKER_IMAGE_PREFIX*" --format '{{.Repository}}:{{.Tag}}'`
	### add kuksa-val image to exports
	DOCKER_IMAGES="$DOCKER_IMAGES
	$KUKSA_VAL_IMG"

    for img in $DOCKER_IMAGES; do
        IMG_REPO=`echo ${img} | cut -d ':' -f 1`
        FILENAME=$( echo $IMG_REPO.$IOTEA_VERSION.${ARCH}.tar | tr '/' '_' )
        echo "# Exporting $img as $FILENAME"
        sudo docker save $img -o $DOCKER_IMAGE_DIR/$FILENAME
    done
fi

if [ "$DOCKER_CONTAINER_START" = "1" ]; then
    # Starting containers
    # Since environment variables have precedence over variables defined in .env, nothing has to be changed here, if another .env-file is chosen as startup parameter
    sudo docker-compose $DOCKER_OPT -f docker-compose.edge.yml --project-name $DOCKER_IMAGE_PREFIX up
	exit_on_error
fi
