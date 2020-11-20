#!/bin/bash -x

if [[ $EUID -eq 0 ]]; then
   echo -e "This script must not be run as root" 
   exit 1
fi
if [[ ! -d src ]]; then
    echo -e "Run this from the project root directory"
    exit 0
fi

NUM_INSTANCES=$1
if [[ -z "${NUM_INSTANCES}" ]]; then
    NUM_INSTANCES=1
fi
TARGET_GROUP_ARN=arn:aws:elasticloadbalancing:ap-southeast-2:814504268053:targetgroup/trivialsec-prod-sockets/00073980e0e9f7a8

declare -a old_instances=\($(aws elbv2 describe-target-health --target-group-arn ${TARGET_GROUP_ARN} --query 'TargetHealthDescriptions[].Target.Id' --output text)\)
targets=''
instances=''
for instanceId in "${old_instances[@]}"; do
    targets="${targets} Id=${instanceId},Port=${SOCKETS_PORT}"
    instances="${instances} ${instanceId}"
done

imageId=$(deploy/bake-ami.sh sockets sg-0c1d7baef47bb7c14 | tail -n1)
if [[ ${imageId} == ami-* ]]; then
    ./deploy/stage2-sockets.sh ${imageId} ${NUM_INSTANCES}
    if ! [[ -z "${targets}" ]]; then
        aws elbv2 deregister-targets --target-group-arn ${TARGET_GROUP_ARN} --targets${targets}
        aws ec2 terminate-instances --instance-ids${instances}
    fi
fi
echo "$imageId"