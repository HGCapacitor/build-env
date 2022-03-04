#!/bin/bash
BUILD_ENV_ROOT="$(readlink -f $(dirname $0)/..)"

COMMON="${BUILD_ENV_ROOT}/common.sh"
if [[ -f ${COMMON} ]]
then
    echo "Sourcing the ${COMMON} file"
    . ${COMMON}
else
    echo "FATAL_ERROR: The file containing the common functions is not found!"
    exit 21
fi

DOCKER_FILE="${BUILD_ENV_ROOT}/docker-steps.d/builder.dockerfile"
DOCKER_IMAGE_TAG="${PROJECT_NAME}-builder:latest"

usage() {
    echo -e "build-container-1.0"
    echo -e "This script does not support long options!"
    echo -e "Usage: $0"
    echo -e "\t[-h]\t\tProvides this help"
    echo -e "\t[-t <string>]\tTag of the docker image {$DOCKER_IMAGE_TAG}"
}

while getopts ":ht:" opt; do
    case "$opt" in
    h)
        usage
        exit 0
        ;;
    t)
        DOCKER_IMAGE_TAG=${OPTARG}
        ;;
    :)
        echo "Error: Option -$OPTARG requires an argument"
        usage
        exit 1
        ;;
    \?)
        echo "Error: Invalid option -$OPTARG"
        usage
        exit 1
        ;;
    esac
done

if [[ $EUID -ne 0 ]]
then
    GUID=$(id -g)
    echo "Building docker image with builder user ids $EUID:$GUID"
    docker build --build-arg BUILD_USER_NAME=${BUILD_USER} --build-arg BUILD_USER_ID=$EUID --build-arg BUILD_GROUP_NAME=${BUILD_GROUP} --build-arg BUILD_USER_GID=$GUID -t "$DOCKER_IMAGE_TAG" -f "$DOCKER_FILE" .
    exit $?
else
    echo "Building docker image as root using default builder user and group ids"
    docker build -t "$DOCKER_IMAGE_TAG" -f "$DOCKER_FILE" .
    exit $?
fi
