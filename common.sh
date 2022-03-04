#[START]Default settings and paranoia tests
if [[ "/" == ${PWD} ]]
then
    echo "FATAL_ERROR: Build cannot run from the root of the filesystem"
    echo "FATAL_ERROR: Please create a subdirectory to run from"
    exit 100
fi
REPOS_ROOT="$(readlink -f $(dirname $0)/..)"
if [[ -z "${REPOS_ROOT}" ]]
then
    echo "FATAL_ERROR: REPOS_ROOT was not set"
    exit 101
fi
BUILD_USER='builder'
BUILD_GROUP='builder'
PROJECT_NAME=$(basename ${REPOS_ROOT})
PROJECT_DIR=$(dirname ${PWD})
PROJECT_DIR_RESOURCES='/resources'
PROJECT_DIR_BUILD="/${PWD/*\//}"
#Reading overruled defaults
if [[ -f build.config ]]
then
    echo "Sourcing the build.config file"
    . build.config
fi
#Setting up global variables
if [[ ! -w ${PROJECT_DIR} ]]
then
    echo "FATAL_ERROR: No write access to the parent directory. ${POJECT_DIR}"
    echo "FATAL_ERROR: The project can not store downloaded resources"
    exit 102
fi
RESOURCES_DIR="${PROJECT_DIR}${PROJECT_DIR_RESOURCES}"
BUILD_DIR="${PROJECT_DIR}${PROJECT_DIR_BUILD}"
if [[ ! -w ${BUILD_DIR} ]]
then
    echo "FATAL_ERROR: Build directory does not allow writing. (${BUILD_DIR})"
    exit 103
fi
if [[ "${BUILD_DIR}" == "${REPOS_ROOT}"* ]]
then
    echo "FATAL_ERROR: Never build from the sources directory."
    echo "DEBUG: build_dir(${BUILD_DIR}) == repos_root(${REPOS_ROOT})"
    exit 104
else
    echo "INFO: Building from ${BUILD_DIR}"
fi
#[END]Default settings and paranoia tests

#Common functions
run_privileged() {
    local COMMENT=${1}
    local COMMAND=${2}

    echo "INFO: ${COMMENT}"
    "${COMMAND}" "${@:3}"
    if [[ $? -ne 0 ]] && [[ $EUID -ne 0 ]] && which sudo > /dev/null 2>&1
    then
        echo "Failed to ${COMMENT}, trying with sudo"
        sudo "${COMMAND}" "${@:3}"
        if [[ $? -ne 0 ]]
        then
            echo "Failed to ${COMMENT} with sudo"
            exit 1
        fi
    fi
    return 0
}

check_prerequisites() {
    PACKAGES=("${@}")
    PACKAGES_TO_INSTALL=()
    for i in "${PACKAGES[@]}"
    do
        echo -ne "Checking for ${i}"
        if [[ $(dpkg -l ${i} | grep -c ii) -gt 0 ]] > /dev/null 2>&1
        then
            echo ": Installed"
        else
            echo ": Missing"
            PACKAGES_TO_INSTALL+=("$i")
        fi
    done
    if [[ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]]
    then
        echo "Will install: ${PACKAGES_TO_INSTALL[@]}"

        run_privileged "update apt repositories" "apt-get" "update"
        if [[ $? -ne 0 ]]
        then
            return 1
        fi
        run_privileged "install prerequisites" "apt-get" "install" "-y" "${PACKAGES_TO_INSTALL[@]}" 
        if [[ $? -ne 0 ]]
        then
            return 1
        fi
    fi
    return 0
}

read_boolean_answer() {
    while true; do
        echo -e "$1"
        if [ "x$AUTOBUILD" == "xy" ]; then	
            echo "AUTOBUILD says yes"			
            REPLY="y"
            break;
        else
            read -r -n 1
            echo # print empty line after input
            case $REPLY in
                [Yy]* ) REPLY="y"; break;;
                [Nn]* ) REPLY="n"; break;;
                * ) echo "Please answer yes or no.";;
            esac
        fi
    done
}

list_steps() {
    local STEPS_DIR=${1}

    echo "Listing the steps to choose from:"
    for i in ${STEPS_DIR}/*.sh; do
        if [ -x $i ]
        then
            STEP_NAME=$(basename -s .sh ${i})
            echo -e "\t${STEP_NAME}"
        fi
    done
    return 0
}

execute_step() {
    local STEP=${1}
    local STEP_PARAMS=${2}

    STEP_BASENAME=$(basename -s .sh ${STEP})
    echo "Executing step: ${STEP_BASENAME}"
    if [[ ! -x ${STEP} ]]
    then
        echo "FATAL_ERROR: Step ${STEP} is not found or not executable!"
        return 2
    else
        if [[ -z ${STEP_PARAMS} ]]
        then
            "${STEP}"
        else
            echo "INFO: using parameters: ${STEP_PARAMS}"
            "${STEP}" $STEP_PARAMS}
        fi
        EXIT_CODE="$?"
        if [[ ${EXIT_CODE} -ne 0 ]]
        then
            echo "FATAL_ERROR: ${STEP} Failed with exitcode ${EXIT_CODE}!"
            return ${EXIT_CODE}
        else 
            echo "INFO: Step ${STEP} was successfull"
            return 0
        fi
    fi
}
