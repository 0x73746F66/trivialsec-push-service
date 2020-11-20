#!/bin/bash -x

if [[ $EUID -eq 0 ]]; then
   echo -e "This script must not be run as root" 
   exit 1
fi
if [[ ! -d src ]]; then
    echo -e "Run this from the project root directory"
    exit 0
fi

readonly base_ami=ami-0ded330691a314693
readonly sg_ids='sg-04a8dac724adcad3c sg-01bbdeecc61359d59'
readonly ami_name=${workload_type}-$(date +'%F')
readonly workload_type=$1
additional_sgs=$2
build_check_delay=$3
if [[ -z "${workload_type}" ]]; then
    echo 'pass in a workload_type'
    exit 1
fi
if [[ ! -z "${additional_sgs}" ]]; then
    additional_sgs=" ${additional_sgs}"
fi
if [[ -z "${build_check_delay}" ]]; then
    build_check_delay=600
fi
if [[ ! -f deploy/user-data/bake-${workload_type}.sh ]]; then
    echo "couldn't locate userdata script [deploy/user-data/bake-${workload_type}.sh]"
    exit 1
fi

instanceId=$(aws ec2 run-instances \
    --no-associate-public-ip-address \
    --image-id ${base_ami} \
    --count 1 \
    --instance-type t3a.medium \
    --key-name ${PRIV_KEY_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${sg_ids} ${additional_sgs} \
    --iam-instance-profile Name=${IAM_INSTANCE_PROFILE} \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Baker-${workload_type}},{Key=webserver,Value=baking},{Key=cost-center,Value=${COST_CENTER}}]" "ResourceType=volume,Tags=[{Key=cost-center,Value=${COST_CENTER}}]" \
    --user-data file://deploy/user-data/bake-${workload_type}.sh \
    --query 'Instances[].InstanceId' \
    --output text)

if [[ ${instanceId} == i-* ]]; then
    aws ec2 wait instance-running --instance-ids ${instanceId}
    echo "PrivateIpAddress $(aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[].Instances[].PrivateIpAddress' --output text)"
    aws ec2 wait instance-status-ok --instance-ids ${instanceId}
    sleep ${build_check_delay}
    existingImageId=$(aws ec2 describe-images --owners self --filters "Name=name,Values=${ami_name}" --query 'Images[].ImageId' --output text)
    if [[ "${existingImageId}" == ami-* ]]; then
        aws ec2 deregister-image --image-id ${existingImageId}
        sleep 3
    fi
    imageId=$(aws ec2 create-image --instance-id ${instanceId} --name ${ami_name} --description "Baked $(date +'%F %T')" --query 'ImageId' --output text)
    sleep 60
    aws ec2 wait image-available --image-ids ${imageId}
    aws ec2 terminate-instances --instance-ids ${instanceId}
    echo ${imageId}
fi