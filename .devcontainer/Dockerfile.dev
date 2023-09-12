FROM mcr.microsoft.com/devcontainers/python:3

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install sshpass

RUN pip install --upgrade pip
RUN pip3 install ansible paramiko pyopenssl pywinrm