#!/bin/bash
VERSION='3.22.2'

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

usage() {
    echo -e "build-cmake-${VERSION}"
    echo -e "This script does not support long options!"
    echo -e "Usage: $0"
    echo -e "\t[-h]\t\tProvides this help"
    echo -e "\t[-c <string>]\tCMake version {$VERSION}"
}

builder_work() {
    local RESOURCES_DIR=${RESOURCES_DIR}
    local VERSION=${VERSION}

    THIRD_PARTY_DIR="${RESOURCES_DIR}/third-party"

    #Install cmake
    RESOURCE_PATH="${THIRD_PARTY_DIR}/cmake-${VERSION}.tar.gz"
    if [[ ! -f ${RESOURCE_PATH} ]]
    then
        mkdir -p $(dirname ${RESOURCE_PATH}) && \
        wget --max-redirect 3 "https://github.com/Kitware/CMake/releases/download/v${VERSION}/cmake-${VERSION}.tar.gz" -O ${RESOURCE_PATH}
    fi 

    if [[ -f ${RESOURCE_PATH} ]]
    then
        SOURCE_PATH="$(dirname ${RESOURCE_PATH})/$(basename -s .tar.gz ${RESOURCE_PATH})"
        echo "Unpacking $(basename ${RESOURCE_PATH})"
        pv "${RESOURCE_PATH}" | tar xz -C $(dirname ${SOURCE_PATH}) && \
        cd ${SOURCE_PATH} && \
        ./bootstrap --parallel=${NUMBER_OF_CORES} && make -j ${NUMBER_OF_CORES} && run_privileged "install cmake-${VERSION}" "make" "install"
    else
        echo "FATAL_ERROR: Failed to download cmake-${VERSION}"
        exit 22
    fi
}

while getopts ":hc:" opt; do
    case "$opt" in
    h)
        usage
        exit 0
        ;;
    c)
        VERSION=${OPTARG}
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

PREREQUISITES=('build-essential' 'libssl-dev' 'pv' 'wget')
if ! check_prerequisites "${PREREQUISITES[@]}"
then
    echo "Failed to comply to the prerequisites!"
    exit 22
fi

#Execute unprivileged
if [[ $EUID -ne 0 ]]
then
    builder_work
else
    export -f builder_work
    export -f run_privileged
    su ${BUILD_USER} -c "export RESOURCES_DIR=${RESOURCES_DIR}; export VERSION=${VERSION}; bash -c builder_work"
fi
