#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
runuser -l ec2-user -c 'cd /srv/app; nohup ./run.sh /home/ec2-user/.yarn/bin/nodemon --no-stdin start &'
