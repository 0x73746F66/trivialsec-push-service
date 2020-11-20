#!/bin/bash -x

if [[ $EUID -eq 0 ]]; then
   echo -e "This script must not be run as root" 
   exit 1
fi
if [[ ! -d scripts ]]; then
    echo -e "Run this from the project root directory"
    exit 0
fi

TYPE=$1
if [[ -z "${TYPE}" ]]; then
    echo 'pass in a TYPE'
    exit 1
fi
ADD_SG=$2
if [[ ! -z "${ADD_SG}" ]]; then
    ADD_SG=" ${ADD_SG}"
fi
BUILD_TIME=$3
if [[ -z "${BUILD_TIME}" ]]; then
    BUILD_TIME=600
fi
if [[ ! -f scripts/deploy/user-data/bake-${TYPE}.sh ]]; then
    echo "couldn't locate userdata script [scripts/deploy/user-data/bake-${TYPE}.sh]"
    exit 1
fi
BASE_AMI=ami-0ded330691a314693
SUBNET_ID=subnet-8b05e8c3
SECURITY_GROUP_IDS='sg-04a8dac724adcad3c sg-01bbdeecc61359d59'
IAM_INSTANCE_PROFILE=EC2-TrivialSec
COST_CENTER=saas
PRIV_KEY_NAME=trivialsec-prod
IMAGE_NAME=${TYPE}-$(date +'%F')

instanceId=$(aws ec2 run-instances \
    --no-associate-public-ip-address \
    --image-id ${BASE_AMI} \
    --count 1 \
    --instance-type t3a.medium \
    --key-name ${PRIV_KEY_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${SECURITY_GROUP_IDS} ${ADD_SG} \
    --iam-instance-profile Name=${IAM_INSTANCE_PROFILE} \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Baker-${TYPE}},{Key=webserver,Value=baking},{Key=cost-center,Value=${COST_CENTER}}]" "ResourceType=volume,Tags=[{Key=cost-center,Value=${COST_CENTER}}]" \
    --user-data file://scripts/deploy/user-data/bake-${TYPE}.sh \
    --query 'Instances[].InstanceId' \
    --output text)

if [[ ${instanceId} == i-* ]]; then
    aws ec2 wait instance-running --instance-ids ${instanceId}
    echo "PrivateIpAddress $(aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[].Instances[].PrivateIpAddress' --output text)"
    aws ec2 wait instance-status-ok --instance-ids ${instanceId}
    sleep ${BUILD_TIME}
    existingImageId=$(aws ec2 describe-images --owners self --filters "Name=name,Values=${IMAGE_NAME}" --query 'Images[].ImageId' --output text)
    if [[ "${existingImageId}" == ami-* ]]; then
        aws ec2 deregister-image --image-id ${existingImageId}
        sleep 3
    fi
    imageId=$(aws ec2 create-image --instance-id ${instanceId} --name ${IMAGE_NAME} --description "Baked $(date +'%F %T')" --query 'ImageId' --output text)
    sleep 60
    aws ec2 wait image-available --image-ids ${imageId}
    aws ec2 terminate-instances --instance-ids ${instanceId}
    echo ${imageId}
fi