FROM registry.gitlab.com/trivialsec/containers-common/nodejs

ENV CONFIG_FILE ${CONFIG_FILE}
ARG NODE_ENV
ENV NODE_ENV $NODE_ENV

WORKDIR /srv/app
COPY src/ src/

USER root
RUN touch /tmp/application.log && \
    chown -R trivialsec: /tmp/application.log /srv/app && \
    wget -q https://publicsuffix.org/list/public_suffix_list.dat -O /tmp/public_suffix_list.dat

USER trivialsec
COPY package.json package.json
RUN yarn -s --ignore-optional --non-interactive --no-progress --network-timeout 1800 --use-yarnrc .yarnrc
ENTRYPOINT ["/usr/bin/env"]
CMD ["/srv/app/node_modules/nodemon/bin/nodemon.js", "-V", "--no-stdin", "start"]