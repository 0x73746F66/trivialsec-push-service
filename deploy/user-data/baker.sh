#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
export COMMON_VERSION=0.3.8
export NODE_PATH=/srv/app/node_modules

function proxy_on() {
    local proxyPrivateAddr=proxy.trivialsec.local
    export http_proxy=http://${proxyPrivateAddr}:3128/
    export https_proxy=http://${proxyPrivateAddr}:3128/
    export no_proxy=169.254.169.254,cloudformation-trivialsec.s3.amazonaws.com,s3.ap-southeast-2.amazonaws.com,ssm.ap-southeast-2.amazonaws.com,logs.ap-southeast-2.amazonaws.com,sts.amazonaws.com
}
function proxy_off() {
    unset http_proxy
    unset https_proxy
    unset no_proxy
}
function echo_proxy() {
    echo $http_proxy
    echo $https_proxy
    echo $no_proxy
}
function proxy_persist() {
    local proxyPrivateAddr=proxy.trivialsec.local
    proxy_on
    cat > /etc/profile.d/http_proxy.sh << EOF
export http_proxy=${http_proxy}
export https_proxy=${https_proxy}
export no_proxy=${no_proxy}

EOF
    cat >> /etc/environment << EOF
export http_proxy=${http_proxy}
export https_proxy=${https_proxy}
export no_proxy=${no_proxy}

EOF
}
function setup_centos() {
    sysctl -w net.core.somaxconn=1024
    echo 'net.core.somaxconn=1024' >> /etc/sysctl.conf
    mkdir -p /usr/share/man/man1mkdir /usr/share/man/man1
    proxy_on
    amazon-linux-extras enable epel
    yum update -q -y
    yum install -q -y deltarpm
    yum groupinstall -q -y "Development Tools"
    yum install -q -y pcre-devel ca-certificates curl epel-release
    update-ca-trust force-enable
    proxy_off
}
function setup_logging() {
    proxy_on
    yum install -q -y https://s3.us-east-1.amazonaws.com/amazoncloudwatch-agent-us-east-1/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm || true
    proxy_off
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-trivialsec-prod
}
function install_nodejs() {
    proxy_on
    curl -sL https://rpm.nodesource.com/setup_14.x | bash -
    yum install -q -y nodejs
    wget -q https://dl.yarnpkg.com/rpm/yarn.repo -O /etc/yum.repos.d/yarn.repo
    yum install -y yarn
    proxy_off
}
function install_sockets_deps() {
    proxy_on
    yum install -q -y jq
    proxy_off
    runuser -l ec2-user -c "node -e \"console.log('Running Node.js '+process.version)\""
    runuser -l ec2-user -c 'yarn --version'
    runuser -l ec2-user -c 'make --version'
}
function deploy_sockets() {
    aws s3 cp --only-show-errors s3://cloudformation-trivialsec/deploy-packages/sockets-${COMMON_VERSION}.zip /tmp/trivialsec/sockets.zip
    unzip -qo /tmp/trivialsec/sockets.zip -d /srv/app
}
function configure_sockets() {
    mkdir -p /srv/app
    touch /tmp/application.log
    cat > /srv/app/.env << EOF
CONFIG_FILE=src/config.yaml
NODE_ENV=production
NODE_PATH=${NODE_PATH}
AWS_ACCOUNT=$(TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" --stderr /dev/null) && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/iam/info --stderr /dev/null | jq -r '.InstanceProfileArn' | cut -d ":" -f 5)
AWS_REGION=ap-southeast-2

EOF
    cat > /srv/app/.yarnrc << EOF
--modules-folder ${NODE_PATH}

EOF
    chown -R ec2-user: /srv/app
    proxy_persist
    runuser -l ec2-user -c 'cd /srv/app/; yarn -s --ignore-optional --non-interactive --no-progress --network-timeout 1800 --use-yarnrc .yarnrc'
    runuser -l ec2-user -c 'cd /srv/app/; yarn -s --ignore-optional --non-interactive --no-progress --network-timeout 1800 --use-yarnrc .yarnrc global add nodemon'
}
function cleanup() {
    chown -R ec2-user: /srv/app /tmp/application.log
    yum groupremove -q -y "Development Tools"
    yum -y clean all
    rm -rf /tmp/trivialsec /var/cache/yum
}
function do_release() {
    setup_logging
    setup_centos
    install_nodejs
    install_sockets_deps
    deploy_sockets
    configure_sockets
    cleanup
}

time do_release
echo $(date +'%F') > /home/ec2-user/.deployed
