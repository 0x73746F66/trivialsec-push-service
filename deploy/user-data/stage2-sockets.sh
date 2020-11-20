#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
runuser -l ec2-user -c 'cd /srv/app; nohup nodemon -V --no-stdin start 2>&1 | tee -a /tmp/application.log &'
