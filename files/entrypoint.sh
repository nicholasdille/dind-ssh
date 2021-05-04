#!/bin/sh
set -o errexit

if test -z "${AUTHORIZED_KEYS}"; then
    echo "ERROR: You must supply AUTHORIZED_KEYS."
    exit 1
fi
echo "Creating ~/.ssh and setting permissions"
mkdir -p /root/.ssh
chmod 0700 /root/.ssh
echo "Adding authorized keys"
echo "${AUTHORIZED_KEYS}" > /root/.ssh/authorized_keys

echo "Generating root password"
ROOT_PW="$(openssl rand -hex 32)"
echo "Changing root password"
echo "root:${ROOT_PWD}" | chpasswd
echo "Root password is ${ROOT_PW}"

echo "Preparing SSHd"
mkdir -p /var/run/sshd
ssh-keygen -A 2>&1

if test -n "${DOCKER_TLSCAKEY}"; then
    mkdir -p /certs/ca
    echo "${DOCKER_TLSCAKEY}" >/certs/ca/key.pem
fi
if test -n "${DOCKER_TLSCACERT}"; then
    mkdir -p /certs/ca
    echo "${DOCKER_TLSCACERT}" >/certs/ca/cert.pem
fi

if test -n "${DOCKER_DAEMON_JSON}"; then
    echo "Adding Docker daemon config"
    mkdir -p /etc/docker
    echo ${DOCKER_DAEMON_JSON} >/etc/docker/daemon.json
fi

if test -n "${DOCKER_CONFIG_JSON}"; then
    echo "Adding Docker client config"
    mkdir -p /root/.docker
    echo ${DOCKER_CONFIG_JSON} >/root/.docker/config.json
fi

echo "Starting services"
exec /services.sh
