FROM trivialsec/node-base

ENV CONFIG_FILE ${CONFIG_FILE}
ARG NODE_ENV
ENV NODE_ENV $NODE_ENV
ARG NODE_PATH
ENV NODE_PATH $NODE_PATH
ENV PATH="$PATH:$NODE_PATH/.bin"

WORKDIR /srv/app
COPY package.json .
COPY src/ src/

USER root
RUN touch /tmp/application.log && \
    chown -R ec2-user: /tmp/application.log /srv/app

USER ec2-user
COPY package.json package.json
RUN yarn -s --ignore-optional --non-interactive --no-progress --network-timeout 1800 --use-yarnrc .yarnrc
ENTRYPOINT ["/usr/bin/env"]
CMD ["/srv/app/node_modules/.bin/nodemon", "-V", "--no-stdin", "start"]