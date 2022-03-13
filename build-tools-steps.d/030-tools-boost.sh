#!/bin/bash
VERSION='1.78.0'

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
    echo -e "build-boost-${VERSION}"
    echo -e "This script does not support long options!"
    echo -e "Usage: $0"
    echo -e "\t[-h]\t\tProvides this help"
    echo -e "\t[-c <string>]\tboost version {$VERSION}"
}

builder_work() {
    local RESOURCES_DIR=${RESOURCES_DIR}
    local VERSION=${VERSION}

    THIRD_PARTY_DIR="${RESOURCES_DIR}/third-party"

    #Install boost
    RESOURCE_PATH="${THIRD_PARTY_DIR}/boost-${VERSION}.tar.gz"
    if [[ ! -f ${RESOURCE_PATH} ]]
    then
        mkdir -p $(dirname ${RESOURCE_PATH}) && \
        wget --max-redirect 3 "https://boostorg.jfrog.io/artifactory/main/release/${VERSION}/source/boost_${VERSION//./_}.tar.gz" -O ${RESOURCE_PATH}
    fi 

    if [[ -f ${RESOURCE_PATH} ]]
    then
        UNPACK_DIR=$(tar -axvf ${RESOURCE_PATH} | head -1 | cut -d / -f 1)
        SOURCE_PATH="$(dirname ${RESOURCE_PATH})/${UNPACK_DIR}"
        echo "Unpacking $(basename ${RESOURCE_PATH}) into ${SOURCE_PATH}"
        pv "${RESOURCE_PATH}" | tar xz -C $(dirname ${RESOURCE_PATH}) && \
        cd ${SOURCE_PATH} && \
        ./bootstrap.sh --with-python=python3 && \
        run_privileged "install boost-${VERSION}" "./b2" "threading=multi" "--without-graph_parallel" "--without-mpi" "--layout=system" "-j${NUMBER_OF_CORES}" "install"
    else
        echo "FATAL_ERROR: Failed to download boost-${VERSION}"
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

PREREQUISITES=('python3' 'python3-dev')
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
