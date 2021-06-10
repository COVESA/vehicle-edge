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

# Default values for missing vars
ARCH="amd64"
DOCKER_IMAGE_PREFIX=vehicle-edge
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DOCKER_IMAGE_DIR=$SCRIPT_DIR/images
YML="-f docker-compose.stack.yml"
WITH_KUKSA_VAL=1
WITH_TALENT=0
DOCKER_IMAGE_BUILD=1
DOCKER_IMAGE_EXPORT=0
DOCKER_CONTAINER_START=1
SUDO_PREFIX="sudo "
ENV_CONFIG=

# Enable buildkit support
export DOCKER_BUILDKIT=1

while [ $# -ne 0 ]
do
    arg="$1"
    case "$arg" in
        --no-sudo)
            echo "Running all docker-compose and docker commands as non super user i.e. WITHOUT sudo"
            SUDO_PREFIX=""
            ;;
        *)
            echo "Set environment configuration to $arg"
            ENV_CONFIG=$arg
            ;;
    esac
    shift
done

if [ ! -f "$ENV_CONFIG" ]; then
    echo "Can't find: $ENV_CONFIG"
    echo "Usage $0 {*.env file}"
    exit 1
fi

# Load the configurations
load_config "$ENV_CONFIG"
load_config "$SCRIPT_DIR/run.properties"

cd $SCRIPT_DIR

if [ "$WITH_TALENT" = "1" ]; then
    YML="${YML} -f docker-compose.talent.yml"
fi

if [ "$WITH_KUKSA_VAL" = "1" ]; then
    # Check if local image of KUKSA.VAL is already loaded
    echo "# Checking for KUKSA_VAL_IMG: $KUKSA_VAL_IMG"
    EXISTING_KUKSA_IMAGE=`$SUDO_PREFIX docker images --format '{{.Repository}}:{{.Tag}}' $KUKSA_VAL_IMG`

    if [ -z "$EXISTING_KUKSA_IMAGE" ] || [ "$EXISTING_KUKSA_IMAGE" != "$KUKSA_VAL_IMG" ]; then
        # Download latest kuksa for $ARCH, KUKSA_VAL_IMG must be updated in $CONFIG with it's version
        if [ -z "$KUKSA_URL" ]; then
            echo "Warning! Missing KUKSA_URL in: $ENV_CONFIG"
            echo "Copy download link from: https://kuksaval.northeurope.cloudapp.azure.com/job/kuksaval-upstream/job/master/lastSuccessfulBuild/artifact/artifacts/kuksa-val-*-${ARCH}.tar.xz"
            exit 1
        fi

        echo "# Tyrying to download $KUKSA_VAL_IMG from: $KUKSA_URL ..."
        wget -q --no-check-certificate "$KUKSA_URL" -O kuksa-val-$ARCH.tar.xz
        exit_on_error

        # Store image name in variable KUKSA_VAL_IMG
        DOCKER_LOAD_RESULT=`$SUDO_PREFIX docker load --input kuksa-val-$ARCH.tar.xz`
        # Remove the file after loading
        rm kuksa-val-$ARCH.tar.xz

        # remove prefix from result
        LOADED_IMAGE="${DOCKER_LOAD_RESULT#Loaded image: *}"
        echo "# Imported kuksa.val: $LOADED_IMAGE"

        # As docker-compose uses KUKSA_VAL_IMG in $ENV_CONFIG, we can't override it, needs to be updated after each kuksa.val build.
        if [ "$LOADED_IMAGE" != "$KUKSA_VAL_IMG" ]; then
            echo "# WARNING! $KUKSA_URL image has version: $LOADED_IMAGE"
            echo "Please, check KUKSA_URL and KUKSA_VAL_IMG in $ENV_CONFIG"
            exit 1
        fi

        $SUDO_PREFIX docker images $KUKSA_VAL_IMG
        exit_on_error
    else
        echo "# Using local image: $KUKSA_VAL_IMG"
    fi

    YML="${YML} -f docker-compose.kuksa.val.yml"
fi

# docker-compose always uses .env file if it exists, so it overrides ARM64 variables with AMD..
# There is no option except putting all refered variables in .yml into dedicated .env file so sudo docker-compose
# can actually load those variables. Otherwise use -E to inherit exported variables in sudo session:
#  $ sudo -E docker-compose --env-file /dev/null
if [ -n "$($SUDO_PREFIX docker-compose --help | grep env-file)" ]; then
    # NOTE: This change breaks old docker-compose without --env-file support.
    DOCKER_OPT="--env-file $ENV_CONFIG $DOCKER_OPT"
else
    echo "docker-compose version does not support --env-file argument"
    exit 1
fi

echo ""
echo "# Using docker-compose version:"
docker-compose --version

# Print configuration
echo
echo "# Print configuration: $YML"
$SUDO_PREFIX docker-compose $DOCKER_OPT $YML config
echo

if [ "$DOCKER_IMAGE_BUILD" = "1" ]; then
    # Build all images
    echo "# Build all images"
    # Since environment variables have precedence over variables defined in .env, nothing has to be changed here, if another .env-file is chosen as startup parameter
    $SUDO_PREFIX docker-compose $DOCKER_OPT $YML --project-name $DOCKER_IMAGE_PREFIX build --force-rm --no-cache
    exit_on_error
fi

if [ "$DOCKER_IMAGE_EXPORT" = "1" ]; then
    # Export images
    [ -d $DOCKER_IMAGE_DIR ] || mkdir -p $DOCKER_IMAGE_DIR

    echo
    echo # Exporting images to: $DOCKER_IMAGE_DIR ..."
    echo

    DOCKER_IMAGES=`$SUDO_PREFIX docker images -f "reference=${DOCKER_IMAGE_PREFIX}_*" -f "label=arch=${ARCH}" --format '{{.Repository}}:{{.Tag}}'`

    for img in $DOCKER_IMAGES; do
        IMG_REPO=`echo ${img} | cut -d ':' -f 1`
        FILENAME=$( echo $IMG_REPO.${ARCH}.tar | tr '/' '_' )
        echo "# Exporting $img as $FILENAME"
        $SUDO_PREFIX docker save $img -o $DOCKER_IMAGE_DIR/$FILENAME
    done

    if [ "$WITH_KUKSA_VAL" = "1" ]; then
        $SUDO_PREFIX docker save $KUKSA_VAL_IMG -o $DOCKER_IMAGE_DIR/${DOCKER_IMAGE_PREFIX}_kuksa.val.$ARCH.tar
    fi
fi

if [ "$DOCKER_CONTAINER_START" = "1" ]; then
    # Starting containers
    # Since environment variables have precedence over variables defined in .env, nothing has to be changed here, if another .env-file is chosen as startup parameter
    $SUDO_PREFIX docker-compose $DOCKER_OPT $YML --project-name $DOCKER_IMAGE_PREFIX up --remove-orphans
    exit_on_error
fi
