#!/bin/bash
set -o errexit

if test -z "$1"; then
    echo "ERROR: You must supply a name. Usage is $0 <name> <ssh_key_file>"
    exit 1
fi
if test -z "$2"; then
    echo "ERROR: You must supply a SSH public key file. Usage is $0 <name> <ssh_key_file>"
    exit 1
fi

NAME=$1
SSH_KEY_FILE=$2
IMAGE=${3:-nicholasdille/dind-ssh}

if ! test -f "${SSH_KEY_FILE}"; then
    echo "ERROR: SSH key file not found."
    exit 1
fi
if ! test -f "${SSH_KEY_FILE}.pub"; then
    echo "ERROR: No corresponding public key found for SSH key file."
    exit 1
fi

DOCKER_CONFIG=${DOCKER_CONFIG:=${HOME}/.docker}

if test -d "${DOCKER_CONFIG}/machine/machines/${NAME}"; then
    echo "ERROR: Machine already exists."
    exit 1
fi

if ! test -f "${DOCKER_CONFIG}/machine/certs/ca-key.pem"; then
    echo "ERROR: Missing CA key."
    exit 1
fi
if ! test -f "${DOCKER_CONFIG}/machine/certs/ca.pem"; then
    echo "ERROR: Missing CA certificate."
    exit 1
fi

if test "$(docker ps --all --filter "name=${NAME}" | wc -l)" == 2; then
    echo "ERROR: DinD container <${NAME}> already present."
    exit 1
fi
docker run \
    --name "${NAME}" \
    --detach \
    --env "AUTHORIZED_KEYS=$(cat "${SSH_KEY_FILE}.pub")" \
    --env "DOCKER_TLSCAKEY=$(cat "${DOCKER_CONFIG}/machine/certs/ca-key.pem")" \
    --env "DOCKER_TLSCACERT=$(cat "${DOCKER_CONFIG}/machine/certs/ca.pem")" \
    --privileged \
    "${IMAGE}"

echo "Waiting for dockerd..."
while ! docker exec "${NAME}" ps faux | grep -q " dockerd "; do
    sleep 1
done
echo "Dockerd is running"

mkdir -p "${DOCKER_CONFIG}/machine/machines/${NAME}"
docker cp "${NAME}:/certs/client" - | tar -xC "${DOCKER_CONFIG}/machine/machines/${NAME}" --strip-components=1
cp "${SSH_KEY_FILE}" "${SSH_KEY_FILE}.pub" "${DOCKER_CONFIG}/machine/machines/${NAME}"

# create config.json in ~/.docker/machine/machines/NAME
SSH_KEY_FILE_BASENAME="$(basename "${SSH_KEY_FILE}")"
IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${NAME}")"
cat "$(dirname "$(readlink -f "$0")")/config.json" | \
    sed -E "s|@HOME@|${HOME}|g" | \
    sed -E "s|@DOCKER_CONFIG@|${DOCKER_CONFIG}|g" | \
    sed -E "s/@NAME@/${NAME}/g" | \
    sed -E "s/@IP@/${IP}/g" | \
    sed -E "s/@SSH_KEY@/${SSH_KEY_FILE_BASENAME}/g" \
    >"${DOCKER_CONFIG}/machine/machines/${NAME}/config.json"
