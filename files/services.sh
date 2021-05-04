#!/usr/bin/dumb-init /bin/sh

/usr/sbin/sshd -D -e &
/usr/local/bin/dockerd-entrypoint.sh
