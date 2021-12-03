FROM docker.io/library/amazonlinux:2-with-sources

ARG NODE_ENV
ARG NODE_ENV
ARG NODE_PATH

ENV NODE_PATH $NODE_PATH
ENV PATH="$PATH:$NODE_PATH/.bin"
ENV NODE_ENV $NODE_ENV
ENV CONFIG_FILE ${CONFIG_FILE}
ENV NODE_ENV $NODE_ENV

WORKDIR /srv/app
RUN mkdir -p /usr/share/man/man1mkdir /usr/share/man/man1 \
    && yum update -q -y \
    && yum install -q -y deltarpm \
    && yum groupinstall -q -y  "Development Tools" \
    && update-ca-trust force-enable \
    && curl -sL https://rpm.nodesource.com/setup_14.x | bash - \
    && curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo \
    && yum install -q -y \
        hostname \
        zip \
        jq \
        wget \
        nodejs \
        yarn \
        jq \
        shadow-utils \
        procps \
        nano \
    && adduser --create-home --user-group trivialsec \
    && chown -R trivialsec: /srv/app \
    && yum clean metadata \
    && yum -q -y clean all

USER trivialsec
COPY --chown=trivialsec:trivialsec .yarnrc .yarnrc
COPY --chown=trivialsec:trivialsec src/ src/
COPY --chown=trivialsec:trivialsec package.json package.json

RUN wget -q https://publicsuffix.org/list/public_suffix_list.dat -O /tmp/public_suffix_list.dat \
    && yarn -s --ignore-optional --non-interactive --no-progress --network-timeout 1800 --use-yarnrc .yarnrc

ENTRYPOINT ["/usr/bin/env"]
CMD ["/srv/app/node_modules/nodemon/bin/nodemon.js", "-V", "--no-stdin", "start"]
