#!/bin/bash -x

if [[ $EUID -eq 0 ]]; then
   echo -e "This script must not be run as root" 
   exit 1
fi
if [[ ! -d src ]]; then
    echo -e "Run this from the project root directory"
    exit 0
fi

readonly sql_file=$(TZ='Australia/Melbourne' date '+%Y-%m-%d').sql
readonly sql_migrate=sql/migrations/${sql_file}
readonly sql_migrate_dest=/tmp/sql/migrations/${sql_file}
if [[ -f ${sql_migrate} ]]; then
    echo "Manual deployment ${sql_migrate}"
    exit 1
fi

readonly base_ami=$1
num_instances=$2
instance_type=$3
if [[ -z "${base_ami}" ]]; then
    echo "define the AMI to use"
    exit 1
fi
if [[ -z "${num_instances}" ]] || [[ ${num_instances} =~ ^-?[0-9]+$ ]]; then
    num_instances=1
fi
if [[ -z "${instance_type}" ]]; then
    instance_type=${DEFAULT_INSTANCE_TYPE}
fi

declare -a results=\($(aws ec2 run-instances \
    --no-associate-public-ip-address \
    --image-id ${base_ami} \
    --count ${num_instances} \
    --instance-type ${instance_type} \
    --key-name ${PRIV_KEY_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${SECURITY_GROUP_IDS} \
    --iam-instance-profile Name=${IAM_INSTANCE_PROFILE} \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Sockets},{Key=webserver,Value=production},{Key=cost-center,Value=${COST_CENTER}}]" "ResourceType=volume,Tags=[{Key=cost-center,Value=${COST_CENTER}}]" \
    --user-data file://deploy/user-data/stage2-sockets.sh \
    --query 'Instances[].InstanceId' --output text)\)

targets=''
instances=''
for instance in "${results[@]}"; do
    targets="${targets} Id=${instance},Port=${SOCKETS_PORT}"
    instances="${instances} ${instance}"
done
aws ec2 wait instance-running --instance-ids${instances}
aws ec2 wait instance-status-ok --instance-ids${instances}
aws elbv2 register-targets \
    --target-group-arn ${TARGET_GROUP_ARN} \
    --targets${targets}
