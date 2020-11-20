#!/bin/bash -x

if [[ $EUID -eq 0 ]]; then
   echo -e "This script must not be run as root" 
   exit 1
fi
if [[ ! -d scripts ]]; then
    echo -e "Run this from the project root directory"
    exit 0
fi

sql_file=$(TZ='Australia/Melbourne' date '+%Y-%m-%d').sql
sql_migrate=sql/migrations/${sql_file}
sql_migrate_dest=/tmp/sql/migrations/${sql_file}
if [[ -f ${sql_migrate} ]]; then
    echo "Manual deployment ${sql_migrate}"
    exit 1
fi

BASE_AMI=$1
if [[ -z "${BASE_AMI}" ]]; then
    echo "define the AMI to use"
    exit 1
fi
NUM_INSTANCES=$2
if [[ -z "${NUM_INSTANCES}" ]] || [[ ${NUM_INSTANCES} =~ ^-?[0-9]+$ ]]; then
    NUM_INSTANCES=1
fi
INSTANCE_TYPE=$3
if [[ -z "${INSTANCE_TYPE}" ]]; then
    INSTANCE_TYPE=t2.micro
fi

SUBNET_ID=subnet-8b05e8c3
SECURITY_GROUP_IDS='sg-0c1d7baef47bb7c14 sg-01bbdeecc61359d59'
IAM_INSTANCE_PROFILE=EC2-TrivialSec
COST_CENTER=saas
PRIV_KEY_NAME=trivialsec-prod
TARGET_GROUP_ARN=arn:aws:elasticloadbalancing:ap-southeast-2:814504268053:targetgroup/trivialsec-prod-sockets/00073980e0e9f7a8

declare -a results=\($(aws ec2 run-instances \
    --no-associate-public-ip-address \
    --image-id ${BASE_AMI} \
    --count ${NUM_INSTANCES} \
    --instance-type ${INSTANCE_TYPE} \
    --key-name ${PRIV_KEY_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${SECURITY_GROUP_IDS} \
    --iam-instance-profile Name=${IAM_INSTANCE_PROFILE} \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Sockets},{Key=webserver,Value=production},{Key=cost-center,Value=${COST_CENTER}}]" "ResourceType=volume,Tags=[{Key=cost-center,Value=${COST_CENTER}}]" \
    --user-data file://scripts/deploy/user-data/stage2-sockets.sh \
    --query 'Instances[].InstanceId' --output text)\)

targets=''
instances=''
for instance in "${results[@]}"; do
    targets="${targets} Id=${instance},Port=5080"
    instances="${instances} ${instance}"
done
aws ec2 wait instance-running --instance-ids${instances}
aws ec2 wait instance-status-ok --instance-ids${instances}
aws elbv2 register-targets \
    --target-group-arn ${TARGET_GROUP_ARN} \
    --targets${targets}
