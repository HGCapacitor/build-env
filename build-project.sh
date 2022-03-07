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

usage() {
    echo -e "build-project-1.0"
    echo -e "This script does not support long options!"
    echo -e "Usage: $0"
    echo -e "\t[-h]\t\tProvides this help"
    echo -e "\t[-l]\t\tList the executable build steps"
    echo -e "\t[-s <string>]\tExecute one of the available build steps"
    echo -e "\t[-y]\t\tAnswer yes to everything"
}

PROGRAM_ACTION='DEFAULT'

while getopts ":hls:y" opt; do
    case "$opt" in
    h)
        usage
        exit 0
        ;;
    l)
        PROGRAM_ACTION='LIST_STEPS'
        ;;
    s)
        PROGRAM_ACTION='EXECUTE_STEP'
        STEP_NAME=${OPTARG}
        ;;
    y)
        AUTOBUILD="y"
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

BUILD_STEPS_DIR="${REPOS_ROOT}/build-project-steps.d"

PREREQUISITES=('coreutils')
if ! check_prerequisites "${PREREQUISITES[@]}"
then
    echo "FATAL_ERROR: Failed to comply to the prerequisites!"
    exit 2
fi

#Special program actions after which the script terminates

case ${PROGRAM_ACTION} in
    "LIST_STEPS")
       	list_steps ${BUILD_STEPS_DIR}
        exit 0
        ;;
    "EXECUTE_STEP")
        COMMAND="${BUILD_STEPS_DIR}/${STEP_NAME}.sh"
      	execute_step ${COMMAND}
        exit 0
        ;;
esac

#From here the DEFAULT program action

if [ -d ${BUILD_STEPS_DIR} ]
then
    for i in ${BUILD_STEPS_DIR}/*.sh; do
        if [ -x $i ]
        then
            STEP_NAME=$(basename -s .sh ${i})
            read_boolean_answer "Do you want to execute ${STEP_NAME} (y/n)?"
            if [ "x$REPLY" == "xy" ]
            then
                execute_step ${i}
            else
                echo "Skipping step: ${STEP_NAME}"
            fi
        else
            echo "WARNING: File ${i} is not executable, please validate if this is correct"
        fi
    done
    unset i
else
    echo "WARNING: No build-project-steps.d directory, please validate if this is correct"
fi
