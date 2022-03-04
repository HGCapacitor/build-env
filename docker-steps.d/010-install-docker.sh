#!/bin/bash
BUILD_ENV_ROOT="$(readlink -f $(dirname $0)/..)"

COMMON="${BUILD_ENV_ROOT}/common.sh"
if [[ -f ${COMMON} ]]
then
    echo "Sourcing the ${COMMON} file"
    . ${COMMON}
else
    echo "FATAL_ERROR: The file containing the common functions is not found!"
    exit 11
fi

usage() {
    echo -e "install-docker-1.0"
    echo -e "This script does not support long options!"
    echo -e "Usage: $0"
    echo -e "\t[-h]\t\tProvides this help"
}

while getopts ":h" opt; do
    case "$opt" in
    h)
        usage
        exit 0
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

PREREQUISITES=('curl' 'gnupg-agent' 'apt' 'software-properties-common' 'lsb-release' 'coreutils')
if ! check_prerequisites "${PREREQUISITES[@]}"
then
    echo "Failed to comply to the prerequisites!"
    exit 12
fi

LSB_ID=$(lsb_release -is | awk '{print tolower($0)}')
LSB_CODE=$(lsb_release -cs)

if [[ $(find /etc/apt/ -name "*.list" | xargs cat | grep -c "docker") -eq 0 ]]
then
    run_privileged "add docker repository signature" "curl" "-fsSL https://download.docker.com/linux/${LSB_ID}/gpg | apt-key add -"
    if [[ $? -ne 0 ]]
    then
        exit 13
    fi

    run_privileged "add the docker registry" "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/${LSB_ID} ${LSB_CODE} stable'"
    if [[ $? -ne 0 ]]
    then
        exit 14
    fi

    run_privileged "update the apt repository" "apt-get update"
    if [[ $? -ne 0 ]]
    then
        exit 15
    fi
else
    echo Docker repository already exists
fi

PREREQUISITES=('containerd.io' 'docker-ce' 'docker-ce-cli' 'docker-compose')
if ! check_prerequisites "${PREREQUISITES[@]}"
then
    echo "Failed to install docker tools!"
    exit 17
fi

if [[ $EUID -ne 0 ]]
then
    USER=$(whoami)
    if [[ $(groups | grep -c docker) -eq 0 ]]
    then
	run_privileged "add user (${USER}) to the docker group" "usermod -aG docker $(whoami)"
        if [[ $? -ne 0 ]]
        then
            echo "Consider manual action to overcome using sudo constantly"
        fi
    else
        echo "User $USER is already member of the docker group"
    fi
fi
