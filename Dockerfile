ARG DOCKER_VERSION=20.10.6

FROM docker:${DOCKER_VERSION}-dind AS alpine
RUN apk add --update-cache --no-cache \
        bash \
        curl \
        jq \
        ca-certificates \
		openssh \
        dumb-init
COPY files /
EXPOSE 2376 22
ENTRYPOINT ["/entrypoint.sh"]
