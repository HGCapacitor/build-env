FROM ubuntu:focal

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y sudo

ARG BUILD_USER_NAME=builder
ARG BUILD_USER_ID=1000
ARG BUILD_GROUP_NAME=builder
ARG BUILD_USER_GID=1000

RUN groupadd -g $BUILD_USER_GID $BUILD_GROUP_NAME && \
    useradd -ms /bin/bash -u $BUILD_USER_ID -g $BUILD_USER_GID $BUILD_USER_NAME && \
    usermod -aG sudo $BUILD_USER_NAME && \
    echo "$BUILD_USER_NAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 

USER $BUILD_USER_NAME
