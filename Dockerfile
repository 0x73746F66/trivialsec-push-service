FROM docker.io/library/amazonlinux:2-with-sources
ARG NODE_ENV
ARG NODE_PATH

ENV NODE_ENV $NODE_ENV
ENV NODE_PATH $NODE_PATH
ENV PATH="$PATH:$NODE_PATH/.bin"
ENV CONFIG_FILE ${CONFIG_FILE}

WORKDIR /srv/app
RUN mkdir -p /usr/share/man/man1mkdir /usr/share/man/man1
RUN yum update -q -y && \
    yum install -q -y deltarpm
RUN yum groupinstall -q -y  "Development Tools"
RUN update-ca-trust force-enable
RUN curl -sL https://rpm.nodesource.com/setup_17.x | bash -
RUN curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
RUN yum install -q -y  \
        hostname \
        zip \
        jq \
        wget \
        nodejs \
        yarn \
        jq \
        shadow-utils \
        procps \
        nano
RUN adduser --create-home --user-group trivialsec
RUN yum clean metadata && \
    yum -q -y clean all

COPY --chown=trivialsec:trivialsec .yarnrc .yarnrc
COPY --chown=trivialsec:trivialsec package.json .
COPY --chown=trivialsec:trivialsec src/ src/
RUN touch /tmp/application.log && \
    chown -R trivialsec:trivialsec /tmp/application.log /srv/app

COPY --chown=trivialsec:trivialsec package.json package.json
USER trivialsec
RUN yarn -s --ignore-optional --non-interactive --no-progress --network-timeout 1800 --use-yarnrc .yarnrc
ENTRYPOINT ["/usr/bin/env"]
CMD ["/srv/app/node_modules/.bin/nodemon", "-V", "--no-stdin", "start"]
