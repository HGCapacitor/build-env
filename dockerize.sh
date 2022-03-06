#!/bin/bash
BUILD_ENV_ROOT="$(dirname $(readlink -f $0))"

COMMON="${BUILD_ENV_ROOT}/common.sh"
if [[ -f ${COMMON} ]]
then
    echo "Sourcing the ${COMMON} file"
    . ${COMMON}
else
    echo "FATAL_ERROR: The file containing the common functions is not found!"
    exit 1
fi

DOCKER_IMAGE_TAG="${PROJECT_NAME,,}-builder:latest"

usage() {
    echo -e "dockerize-1.0"
    echo -e "This script does not support long options!"
    echo -e "Usage: $0"
    echo -e "\t[-h]\t\tProvides this help"
    echo -e "\t[-d <choice>]\tSpecify what to dockerize [build-tools]"
    echo -e "\t[-i]\t\tInteractive shell in the docker container"
    echo -e "\t[-l]\t\tList the executable docker steps"
    echo -e "\t[-p <string>]\tParameters to pass the dockerized script"
    echo -e "\t[-s <string>]\tExecute one of the available docker steps"
}

PROGRAM_ACTION='DEFAULT'

while getopts ":hd:ilp:s:" opt; do
    case "$opt" in
    h)
        usage
        exit 0
        ;;
    d)
	DOCKERIZE=${OPTARG}
	;;
    i)
        PROGRAM_ACTION='INTERACTIVE_SHELL'
        ;;
    l)
        PROGRAM_ACTION='LIST_DOCKER_STEPS'
        ;;
    p)
        DOCKERIZE_PARAMS=${OPTARG}
        ;;
    s)
        PROGRAM_ACTION='EXECUTE_DOCKER_STEP'
        STEP_NAME=${OPTARG}
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

docker_commit() {
    CONTAINER_ID=$(docker ps -a | grep ${DOCKER_IMAGE_TAG} | head -n 1 | awk '{print $1}')
    if [[ -z "${CONTAINER_ID}" ]]
    then
        echo "Failed to get the container id!"
        echo "All your changes are lost!"
    else
        echo "Committing ${CONTAINER_ID}"
        docker commit $CONTAINER_ID "$DOCKER_IMAGE_TAG"
    fi
}

docker_run() {
    local SCRIPT_WITH_PARAMS=${1}
    local DOCKER_SWITCHES=${2}

    if [ -z SSH_AUTH_SOCK ]
    then
        eval `ssh-agent`
        ssh-add -k
    fi

    if [[ -z "${SCRIPT_WITH_PARAMS}" ]]
    then
        docker run -it ${DOCKER_SWITCHES} -v ${REPOS_ROOT}:${MOUNTED_SOURCES_DIR} -v ${RESOURCES_DIR}:${MOUNTED_RESOURCES_DIR} -v ${BUILD_DIR}:${MOUNTED_BUILD_DIR} -v ${SSH_AUTH_SOCK}:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent "$DOCKER_IMAGE_TAG" /bin/bash
        return $?
    else
        docker run -it ${DOCKER_SWITCHES} -v ${REPOS_ROOT}:${MOUNTED_SOURCES_DIR} -v ${RESOURCES_DIR}:${MOUNTED_RESOURCES_DIR} -v ${BUILD_DIR}:${MOUNTED_BUILD_DIR} -v ${SSH_AUTH_SOCK}:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -e DEBIAN_FRONTEND=noninteractive "$DOCKER_IMAGE_TAG" /bin/bash -c "sudo chown -R ${BUILD_USER}:${BUILD_GROUP} ${MOUNTED_PROJECT_DIR}; cd ${MOUNTED_BUILD_DIR}; ${MOUNTED_SOURCES_DIR}/${SCRIPT_WITH_PARAMS}"
        return $?
    fi
}

DOCKER_STEPS_DIR="${BUILD_ENV_ROOT}/docker-steps.d"
MOUNTED_PROJECT_DIR='/project'
MOUNTED_SOURCES_DIR="${MOUNTED_PROJECT_DIR}/sources"
MOUNTED_RESOURCES_DIR="${MOUNTED_PROJECT_DIR}/resources"
MOUNTED_BUILD_DIR="${MOUNTED_PROJECT_DIR}/build"

PREREQUISITES=('coreutils')
if ! check_prerequisites "${PREREQUISITES[@]}"
then
    echo "FATAL_ERROR: Failed to comply to the prerequisites!"
    exit 2
fi

#Special program actions after which the script terminates

case ${PROGRAM_ACTION} in
    "LIST_DOCKER_STEPS")
	list_steps ${DOCKER_STEPS_DIR}
        exit 0
        ;;
    "EXECUTE_DOCKER_STEP")
        COMMAND="${DOCKER_STEPS_DIR}/${STEP_NAME}.sh"
    	execute_step ${COMMAND}
        exit 0
        ;;
    "INTERACTIVE_SHELL")
    docker_run
    docker_commit
    exit 0
    ;;
esac

#From here the DEFAULT program action

if ! which docker > /dev/null 2>&1
then
    echo "WARNING: Docker is not available, will try to install"
    execute_step "${DOCKER_STEPS_DIR}/010-install-docker.sh"
    EXIT_CODE="$?"
    if [[ ${EXIT_CODE} -ne 0 ]]
    then
        echo "FATAL_ERROR: Could not install docker!"
        exit ${EXIT_CODE}
    fi
fi

if [[ $(docker image ls | grep -c ${DOCKER_IMAGE_TAG/:/.*}) -eq 0 ]]
then
    echo "WARNING: ${DOCKER_IMAGE_TAG} is not available, will try to build it"
    execute_step "${DOCKER_STEPS_DIR}/020-build-container.sh"
    EXIT_CODE="$?"
    if [[ ${EXIT_CODE} -ne 0 ]]
    then
        echo "FATAL_ERROR: Could not build the container!"
        exit ${EXIT_CODE}
    fi
fi

case "${DOCKERIZE}" in
    "build-tools")
        echo "INFO: Will dockerize: ${DOCKERIZE}"
        COMMAND="build-tools.sh ${DOCKERIZE_PARAMS}"
        docker_run ${COMMAND}
        docker_commit
        ;;
    *)
        echo "FATAL: Unknown step to dockerize: ${DOCKERIZE}"
	exit 1
esac
