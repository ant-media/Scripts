
#!/bin/bash
#Pre-requests
# 1. Install jq for json parsing
#    Ubuntu install
#      sudo apt-get install jq 
#    Mac install
#      brew install jq
#
# 2. Learn Ubuntu 16.04 AMI id in your region and replace the UBUNTU_AMI_ID_FOR_MONGODB variable in the script 

# Usage
# ./aws-ams-cluster-install.sh [-i AMI_ID] [-y true|false] [-t install|uninstall] [-c CERTIFICATE_ARN]
# Parameters:
#   -i AMI_ID -> Amazon Machine Image Id(AMI) of the Ant Media Server Enterprise. It's optional. If it's not set, it uses Marketplace image in your region
#   -u UBUNTU_AMI_ID -> Ubuntu 16.04 AMI ID for installing MONGODB. Optional. If not set, try to get find an AMI from marketplace
#   -y true|false -> headless install. Optional. Default value is true
#   -t uninstall|install -> install or uninstalls components elements in the cluster. Optional. Default value is install. 
#   -c CERTIFICATE_ARN -> Write certifate arn from AWS ACM. Binding for HTTPS and WSS connections. Optional. Default value is not set.
#
# Samples
#
# Install Cluster interactively without https with AWS Marketplace AMI
#     ./aws-ams-cluster-install.sh
#
# Install Cluster interactively without https with specified Ant Media Server AMI ID
#    ./aws-ams-cluster-install.sh -i AMI_ID
#
# Install Headless without https 
#    ./aws-ams-cluster-install.sh -y true
#
# Install with https and wss
#    ./aws-ams-cluster-install.sh -c CERTIFICATE_ARN
#
# Uninstall 
#    ./aws-ams-cluster-install.sh -t uninstall



AMS_AMI_ID=
HEADLESS_PROCESS=false
OPERATION_TYPE=install
ACM_CERTIFICATE_ARN=
#ubuntu 16.04 image for installing mongodb. 
UBUNTU_AMI_ID_FOR_MONGODB=

#pem key name
KEYPAIR_NAME=ams-cluster-key

#mongodb instance security group name
MONGODB_SECURITY_GROUP_NAME=ams-cluster-mongodb-security-group

#mongodb instance type 
MONGO_DB_INSTANCE_TYPE=c5.xlarge

#origin scale group security group name
ORIGIN_SCALE_GROUP_SECURITY_GROUP_NAME=ams-cluster-origin-security-group
#origin scale group launnch configuration name
ORIGION_SCALE_GROUP_LAUNCH_CONF_NAME=ams-origin-cluster-launch-conf
#origin instance type in origin scale group
ORIGIN_CLUSTER_INSTANCE_TYPE=c5.2xlarge

#load balancer name
LOAD_BALANCER_NAME=ams-load-balancer
#load balancer security group name
LOAD_BALANCER_SECURITY_GROUP_NAME=ams-lb-security-group
#origin target group name for load balencer forwards request to origin scale group
ORIGIN_TARGET_GROUP_NAME=ams-origin-target-group
#edge target group name for load balancer forward requests to edge scale group 
EDGE_TARGET_GROUP_NAME=ams-edge-target-group

#origin scale group name
ORIGIN_SCALE_GROUP_NAME=ams-origin-scale-group
#origin scale group minimum instance size
ORIGIN_SCALE_GROUP_MIN_SIZE=1
#origin scale group maximum instance size
ORIGIN_SCALE_GROUP_MAX_SIZE=10
#origin group scale out policy name
ORIGIN_GROUP_SCALEOUT_POLICY=ams-origin-scaleout-policy
#origin group scale out adjustment. It means add 2 more instances in scaling out
ORIGIN_GROUP_SCALEOUT_SCALING_ADJUSTMENT=2
#origin group scaleout adjustment type. For more information 
#https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-simple-step.html
ORIGIN_GROUP_SCALEOUT_SCALING_ADJUSTMENT_TYPE=ChangeInCapacity

#origin group scale in policy name
ORIGIN_GROUP_SCALEIN_POLICY=ams-origin-scalein-policy
#origin group scale in adjusment. -1 means decrease number of instances by one 
ORIGIN_GROUP_SCALEIN_SCALING_ADJUSTMENT=-1
#origin group scaleout adjustment type. For more information 
#https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-scaling-simple-step.html
ORIGIN_GROUP_SCALEIN_SCALING_ADJUSTMENT_TYPE=ChangeInCapacity

#origin group add capacity alarm name
ORIGIN_GROUP_ALARM_ADDCAPACITY=ams-origin-alarm-addcapacity
#origin group cloud watch period in seconds
ORIGIN_CLOUDWATCH_PERIOD=60   
#origin cloud watch evaluation period. 
ORIGIN_CLOUDWATCH_EVALUATION_PERIOD=1
#cpu threshold percentage for scaling out.
#this configuration check the cpu  ORIGIN_CLOUDWATCH_PERIOD periods for  ORIGIN_CLOUDWATCH_EVALUATION_PERIOD times
#if threshold is equal or above ORIGIN_SCALEOUT_CLOUDWATCH_THRESHOLD, it creates alarm
ORIGIN_SCALEOUT_CLOUDWATCH_THRESHOLD=60  
#origin group alarm remove capacity name 
ORIGIN_GROUP_ALARM_REMOVECAPACITY=ams-origin-alarm-removecapacity
#cpu threshold percentage for scaling in
ORIGIN_SCALEIN_CLOUDWATCH_THRESHOLD=40

#edge scale group security name
EDGE_SCALE_GROUP_SECURITY_GROUP_NAME=ams-cluster-edge-security-group
#edge scale group launch configuration name
EDGE_SCALE_GROUP_LAUNCH_CONF_NAME=ams-edge-cluster-launch-conf
#edge scale group instance type
EDGE_CLUSTER_INSTANCE_TYPE=c5.large
#edge scale group name
EDGE_SCALE_GROUP_NAME=ams-edge-scale-group

#edge scale group maximum number of instances
EDGE_SCALE_GROUP_MAX_SIZE=10  
#edge scale group minimum number of instances
EDGE_SCALE_GROUP_MIN_SIZE=1 

#edge group scale out policy name
EDGE_GROUP_SCALEOUT_POLICY=ams-edge-scaleout-policy
#edge group scale out adjustment
EDGE_GROUP_SCALEOUT_SCALING_ADJUSTMENT=2
#edge group scale out adjustment type 
EDGE_GROUP_SCALEOUT_SCALING_ADJUSTMENT_TYPE=ChangeInCapacity
#edge group alarm add capacity name
EDGE_GROUP_ALARM_ADDCAPACITY=ams-edge-alarm-addcapacity
#edge group cloud watch period in seconds
EDGE_CLOUDWATCH_PERIOD=60 
#edge group evaluation period
EDGE_CLOUDWATCH_EVALUATION_PERIOD=1
#edge grooup scaleout threshold. CPU percentage 
EDGE_SCALEOUT_CLOUDWATCH_THRESHOLD=60

#edge group scale in policy name
EDGE_GROUP_SCALEIN_POLICY=ams-edge-scalein-policy
#edge group scaling in adjusment. Decrease number of instances
EDGE_GROUP_SCALEIN_SCALING_ADJUSTMENT=-1
#edge group scaling in adjusment type
EDGE_GROUP_SCALEIN_SCALING_ADJUSTMENT_TYPE=ChangeInCapacity
#edge group remove capacity alarm name 
EDGE_GROUP_ALARM_REMOVECAPACITY=ams-edge-alarm-removecapacity
#edge group cpu threshold for scaling in. If it's less than threshold, instance count is decreased 
EDGE_SCALEIN_CLOUDWATCH_THRESHOLD=40  

AWS_MARKETPLACE_AMS_ENTERPRISE_PRODUCT_CODE=8kf9kapq2qbo37fuekp8k7o6r

############## you do not need to change the parameters below #############
MONGODB_INSTANCE_ID_FILE=.mongodbInstance
ORIGIN_TARGET_GROUP_ARN_FILE=.originTargetGroupArn
EDGE_TARGET_GROUP_ARN_FILE=.edgeTargetGroupArn
EDGE_TARGET_GROUP_LISTENER_ARN_FILE=.edgeTargetGroupListenerArn
ORIGIN_TARGET_GROUP_LISTENER_ARN_FILE=.originTargetGroupListenerArn
EDGE_TARGET_GROUP_SECURE_LISTENER_ARN_FILE=.edgeTargetGroupSecureListenerArn
ORIGIN_TARGET_GROUP_SECURE_LISTENER_ARN_FILE=.originTargetGroupSecureListenerArn
MONGO_DB_INSTANCE_INIT_FILE=mongodb-instance-init.sh
AMS_CHANGE_MODE_TO_CLUSTER=ams-change-mode-to-cluster.sh



#Checks and delete security group by name
#Get one parameter which is security group name
check_and_delete_security_group() 
{
    SECURITY_GROUP_NAME=$1
    TMP_VAR=`aws ec2 describe-security-groups --group-names $SECURITY_GROUP_NAME 2>> .errorFile | jq --raw-output .SecurityGroups[0].GroupName`
    if [ "$TMP_VAR" == "$SECURITY_GROUP_NAME" ]; then
        echo "Security group with name: $SECURITY_GROUP_NAME exists. It'll be replaced"
        aws ec2 delete-security-group --group-name $SECURITY_GROUP_NAME
    fi
}

delete_security_group() {
    echo "Checking security group $1"
    TMP_VAR=`aws ec2 describe-security-groups --group-name $1 2>> .errorFile | jq --raw-output .SecurityGroups[0].GroupName`
    if [ "$TMP_VAR" == "$1" ]; then
       #delete if security group exists
       echo "Deleting security group $1"
       aws ec2 delete-security-group --group-name $1 
       if [ $? -ne 0 ]; then
          echo "Security group is not deleted. Please run this script about 30 seconds later in order to full cleanup"
       fi
    fi 
}

#Add ingress to security group
add_ingress_to_security_group() {
    SECURITY_GROUP_ID=$1
    PROTOCOL_TYPE=$2
    PORT=$3
    CIDR_NETWORK=$4

    aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol $PROTOCOL_TYPE --port $PORT --cidr $CIDR_NETWORK
}

###
### install mongodb instance function 
###
install_mongodb_instance() 
{

    check_and_delete_security_group $MONGODB_SECURITY_GROUP_NAME
    #create security group for mongodb
    MONGODB_SECURITY_GROUP_ID=`aws ec2 create-security-group --group-name $MONGODB_SECURITY_GROUP_NAME \
                                --description "Security group for mongodb instance" \
                                --vpc-id $VPC_NETWORK_ID | jq --raw-output .GroupId`

    #add SSH(22) port to the mongodb security group. 22 port access is open to whole world
    add_ingress_to_security_group $MONGODB_SECURITY_GROUP_ID tcp 22 0.0.0.0/0
    #add 27017 port to the mongodb security group. 27017 port is open to VPC network $VPC_CIDR_NETWORK
    add_ingress_to_security_group $MONGODB_SECURITY_GROUP_ID tcp 27017 $VPC_CIDR_NETWORK

    #create mongodb instance
    #TODO: make user-data script downloadable from github, get the file from wget and use below
    #TODO: attach device volume and use it for mongodb storage
    #create instance in the default subnet
    echo "Creating MongoDB Instance"
    MONGODB_INSTANCE_ID=`aws ec2 run-instances --image-id $UBUNTU_AMI_ID_FOR_MONGODB --count 1 \
    --instance-type $MONGO_DB_INSTANCE_TYPE --key-name $KEYPAIR_NAME \
    --security-group-ids $MONGODB_SECURITY_GROUP_ID --user-data file://$MONGO_DB_INSTANCE_INIT_FILE | jq --raw-output .Instances[0].InstanceId`

    if [ "$MONGODB_INSTANCE_ID" != "" ]; then
        echo $MONGODB_INSTANCE_ID > $MONGODB_INSTANCE_ID_FILE
    fi
    MONGODB_SERVER_IP=`aws ec2 describe-instances --instance-ids $MONGODB_INSTANCE_ID | jq --raw-output .Reservations[0].Instances[0].PrivateIpAddress`
    #create tag to mongodb instance 
    aws ec2 create-tags --resources $MONGODB_INSTANCE_ID --tags Key=name,Value=mongodb-instance-ams-cluster

    if [ "$MONGODB_SERVER_IP" != "" ]; then
        echo "MongoDB Installed with instance-id: $MONGODB_INSTANCE_ID  private IP: $MONGODB_SERVER_IP"
    fi
}

uninstall_mongodb_instance() 
{   
    MONGODB_INSTANCE_ID=`cat $MONGODB_INSTANCE_ID_FILE 2>> .errorFile`
    if [ "$MONGODB_INSTANCE_ID" != "" ]; then
        TMP_VAR=`aws ec2 describe-instances --instance-ids $MONGODB_INSTANCE_ID 2>> .errorFile | jq --raw-output .Reservations[0].Instances[0].InstanceId`
        if [ "$TMP_VAR" == "$MONGODB_INSTANCE_ID" ]; then
           echo "Deleting MongoDB Instance $MONGODB_INSTANCE_ID"
            aws ec2 terminate-instances --instance-ids $MONGODB_INSTANCE_ID  > /dev/null
            
            if [ $? -eq 0 ]; then
                rm $MONGODB_INSTANCE_ID_FILE
            fi
            
        fi 
    fi
    delete_security_group $MONGODB_SECURITY_GROUP_NAME
}    


###
### install origin scale group function 
###
install_origin_scale_group() {
    #create security group for origin

    check_and_delete_security_group $ORIGIN_SCALE_GROUP_SECURITY_GROUP_NAME
    ORIGION_SCALE_GROUP_SECURITY_GROUP_ID=`aws ec2 create-security-group --group-name $ORIGIN_SCALE_GROUP_SECURITY_GROUP_NAME \
                                --description "Security group for ams origin scale group instances" \
                                --vpc-id $VPC_NETWORK_ID | jq --raw-output .GroupId`

    #add 22 tcp port. Open for world
    add_ingress_to_security_group $ORIGION_SCALE_GROUP_SECURITY_GROUP_ID tcp 22 0.0.0.0/0
    #add 5000-65000 UDP ports for ingesting live streams. Open for world
    add_ingress_to_security_group $ORIGION_SCALE_GROUP_SECURITY_GROUP_ID udp 5000-65000 0.0.0.0/0
    #add 5000 tcp port for cluster communication for VPC. Open for VPC
    add_ingress_to_security_group $ORIGION_SCALE_GROUP_SECURITY_GROUP_ID tcp 5000 $VPC_CIDR_NETWORK
    #add 5080 for websocket/http communication. Open for world
    add_ingress_to_security_group $ORIGION_SCALE_GROUP_SECURITY_GROUP_ID tcp 5080 0.0.0.0/0

    #add 6000-65000 tcp ports for streaming to edge nodes. Open for VPC
    add_ingress_to_security_group $ORIGION_SCALE_GROUP_SECURITY_GROUP_ID tcp 6000-65000 $VPC_CIDR_NETWORK

    #Create launch configuration for origin cluster
    USER_DATA_INIT="`cat $AMS_CHANGE_MODE_TO_CLUSTER` $MONGODB_SERVER_IP" 

    aws autoscaling create-launch-configuration --launch-configuration-name $ORIGION_SCALE_GROUP_LAUNCH_CONF_NAME \
    --image-id $AMS_AMI_ID --instance-type $ORIGIN_CLUSTER_INSTANCE_TYPE --associate-public-ip-address \
    --security-groups $ORIGION_SCALE_GROUP_SECURITY_GROUP_ID --user-data "$USER_DATA_INIT"


    #create auto scaling group for origin nodes
    aws autoscaling create-auto-scaling-group --auto-scaling-group-name $ORIGIN_SCALE_GROUP_NAME \
    --launch-configuration-name $ORIGION_SCALE_GROUP_LAUNCH_CONF_NAME \
    --vpc-zone-identifier "$VPC_SUBNET1_ID,$VPC_SUBNET2_ID" \
    --max-size $ORIGIN_SCALE_GROUP_MAX_SIZE --min-size $ORIGIN_SCALE_GROUP_MIN_SIZE

    #attach auto scaling group to target group
    aws autoscaling attach-load-balancer-target-groups --auto-scaling-group-name $ORIGIN_SCALE_GROUP_NAME \
    --target-group-arns $ORIGIN_TARGET_GROUP_ARN


    #create scaleout policy

    ORIGIN_GROUP_SCALE_OUT_POLICY_ARN=`aws autoscaling put-scaling-policy --policy-name $ORIGIN_GROUP_SCALEOUT_POLICY \
    --auto-scaling-group-name $ORIGIN_SCALE_GROUP_NAME --scaling-adjustment $ORIGIN_GROUP_SCALEOUT_SCALING_ADJUSTMENT \
    --adjustment-type $ORIGIN_GROUP_SCALEOUT_SCALING_ADJUSTMENT_TYPE | jq --raw-output .PolicyARN`

    #bind with cloud watch
    aws cloudwatch put-metric-alarm --alarm-name $ORIGIN_GROUP_ALARM_ADDCAPACITY \
    --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average \
    --period $ORIGIN_CLOUDWATCH_PERIOD --evaluation-periods $ORIGIN_CLOUDWATCH_EVALUATION_PERIOD --threshold $ORIGIN_SCALEOUT_CLOUDWATCH_THRESHOLD \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions "Name=AutoScalingGroupName,Value=$ORIGIN_SCALE_GROUP_NAME" \
    --alarm-actions $ORIGIN_GROUP_SCALE_OUT_POLICY_ARN  

    #create scalein policy
    ORIGIN_GROUP_SCALE_IN_POLICY_ARN=`aws autoscaling put-scaling-policy --policy-name $ORIGIN_GROUP_SCALEIN_POLICY \
    --auto-scaling-group-name $ORIGIN_SCALE_GROUP_NAME --scaling-adjustment $ORIGIN_GROUP_SCALEIN_SCALING_ADJUSTMENT \
    --adjustment-type $ORIGIN_GROUP_SCALEIN_SCALING_ADJUSTMENT_TYPE | jq --raw-output .PolicyARN`

    #bind with cloud watch
    aws cloudwatch put-metric-alarm --alarm-name $ORIGIN_GROUP_ALARM_REMOVECAPACITY \
    --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average \
    --period $ORIGIN_CLOUDWATCH_PERIOD --evaluation-periods $ORIGIN_CLOUDWATCH_EVALUATION_PERIOD --threshold $ORIGIN_SCALEIN_CLOUDWATCH_THRESHOLD \
    --comparison-operator LessThanOrEqualToThreshold \
    --dimensions "Name=AutoScalingGroupName,Value=$ORIGIN_SCALE_GROUP_NAME" \
    --alarm-actions $ORIGIN_GROUP_SCALE_IN_POLICY_ARN  
}

uninstall_origin_scale_group() 
{
    echo "Uninstalling origin scale group"
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ORIGIN_SCALE_GROUP_NAME --force-delete 2>> .errorFile
    aws autoscaling delete-launch-configuration --launch-configuration-name $ORIGION_SCALE_GROUP_LAUNCH_CONF_NAME 2>> .errorFile
    aws cloudwatch delete-alarms --alarm-names $ORIGIN_GROUP_ALARM_ADDCAPACITY $ORIGIN_GROUP_ALARM_REMOVECAPACITY
    delete_security_group $ORIGIN_SCALE_GROUP_SECURITY_GROUP_NAME
}

###
### install edge scale group function 
###
install_edge_scale_group () {
    #create security group for edge nodes

    EDGE_SCALE_GROUP_SECURITY_GROUP_ID=`aws ec2 create-security-group --group-name $EDGE_SCALE_GROUP_SECURITY_GROUP_NAME \
                            --description "Security group for ams edge scale group instances" \
                            --vpc-id $VPC_NETWORK_ID | jq --raw-output .GroupId`

    #add 22 tcp port. Open for world
    add_ingress_to_security_group $EDGE_SCALE_GROUP_SECURITY_GROUP_ID tcp 22 0.0.0.0/0
    #add 5000 tcp port for cluster communication for VPC. Open for VPC
    add_ingress_to_security_group $EDGE_SCALE_GROUP_SECURITY_GROUP_ID tcp 5000 $VPC_CIDR_NETWORK
    #add 5080 for websocket/http communication. Open for world
    add_ingress_to_security_group $EDGE_SCALE_GROUP_SECURITY_GROUP_ID tcp 5080 0.0.0.0/0

    USER_DATA_INIT="`cat $AMS_CHANGE_MODE_TO_CLUSTER` $MONGODB_SERVER_IP" 
    aws autoscaling create-launch-configuration --launch-configuration-name $EDGE_SCALE_GROUP_LAUNCH_CONF_NAME \
        --image-id $AMS_AMI_ID --instance-type $EDGE_CLUSTER_INSTANCE_TYPE --associate-public-ip-address \
        --security-groups $EDGE_SCALE_GROUP_SECURITY_GROUP_ID  --user-data "$USER_DATA_INIT"

    #create auto scaling group for edge nodes
    aws autoscaling create-auto-scaling-group --auto-scaling-group-name $EDGE_SCALE_GROUP_NAME \
        --launch-configuration-name $EDGE_SCALE_GROUP_LAUNCH_CONF_NAME \
        --vpc-zone-identifier "$VPC_SUBNET1_ID,$VPC_SUBNET2_ID" \
        --max-size $EDGE_SCALE_GROUP_MAX_SIZE --min-size $EDGE_SCALE_GROUP_MIN_SIZE     

    aws autoscaling attach-load-balancer-target-groups --auto-scaling-group-name $EDGE_SCALE_GROUP_NAME \
        --target-group-arns $EDGE_TARGET_GROUP_ARN   


    #create scaleout policy
    EDGE_GROUP_SCALE_OUT_POLICY_ARN=`aws autoscaling put-scaling-policy --policy-name $EDGE_GROUP_SCALEOUT_POLICY \
    --auto-scaling-group-name $EDGE_SCALE_GROUP_NAME --scaling-adjustment $EDGE_GROUP_SCALEOUT_SCALING_ADJUSTMENT \
    --adjustment-type $EDGE_GROUP_SCALEOUT_SCALING_ADJUSTMENT_TYPE | jq --raw-output .PolicyARN`

    #bind with cloud watch
    aws cloudwatch put-metric-alarm --alarm-name $EDGE_GROUP_ALARM_ADDCAPACITY \
    --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average \
    --period $EDGE_CLOUDWATCH_PERIOD --evaluation-periods $EDGE_CLOUDWATCH_EVALUATION_PERIOD --threshold $EDGE_SCALEOUT_CLOUDWATCH_THRESHOLD \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions "Name=AutoScalingGroupName,Value=$EDGE_SCALE_GROUP_NAME" \
    --alarm-actions $EDGE_GROUP_SCALE_OUT_POLICY_ARN  

    #create scalein policy
    EDGE_GROUP_SCALE_IN_POLICY_ARN=`aws autoscaling put-scaling-policy --policy-name $EDGE_GROUP_SCALEIN_POLICY \
    --auto-scaling-group-name $EDGE_SCALE_GROUP_NAME --scaling-adjustment $EDGE_GROUP_SCALEIN_SCALING_ADJUSTMENT \
    --adjustment-type $EDGE_GROUP_SCALEIN_SCALING_ADJUSTMENT_TYPE | jq --raw-output .PolicyARN`

    #bind with cloud watch
    aws cloudwatch put-metric-alarm --alarm-name $EDGE_GROUP_ALARM_REMOVECAPACITY \
     --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average \
     --period $EDGE_CLOUDWATCH_PERIOD --evaluation-periods $EDGE_CLOUDWATCH_EVALUATION_PERIOD --threshold $EDGE_SCALEIN_CLOUDWATCH_THRESHOLD \
     --comparison-operator LessThanOrEqualToThreshold \
     --dimensions "Name=AutoScalingGroupName,Value=$EDGE_SCALE_GROUP_NAME" \
     --alarm-actions $EDGE_GROUP_SCALE_IN_POLICY_ARN                
}

uninstall_edge_scale_group() 
{
    echo "Uninstalling edge scale group"
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $EDGE_SCALE_GROUP_NAME --force-delete 2>> .errorFile
    aws autoscaling delete-launch-configuration --launch-configuration-name $EDGE_SCALE_GROUP_LAUNCH_CONF_NAME 2>> .errorFile
    aws cloudwatch delete-alarms --alarm-names $EDGE_GROUP_ALARM_ADDCAPACITY $EDGE_GROUP_ALARM_REMOVECAPACITY
    delete_security_group $EDGE_SCALE_GROUP_SECURITY_GROUP_NAME
}

###
### install load balancer function 
###
install_load_balancer() {

    check_and_delete_security_group $LOAD_BALANCER_SECURITY_GROUP_NAME
    #preparing security group for load balancer
    LOAD_BALANCER_SECURITY_GROUP_ID=`aws ec2 create-security-group --group-name $LOAD_BALANCER_SECURITY_GROUP_NAME \
                                --description "Security group for load balancer" \
                                --vpc-id $VPC_NETWORK_ID | jq --raw-output .GroupId`

    #add 5080 port to the lb security group.
    add_ingress_to_security_group $LOAD_BALANCER_SECURITY_GROUP_ID tcp 5080 0.0.0.0/0
    #add 5443 port to the lb security group.
    add_ingress_to_security_group $LOAD_BALANCER_SECURITY_GROUP_ID tcp 5443 0.0.0.0/0
    #add 80 port to the lb security group.
    add_ingress_to_security_group $LOAD_BALANCER_SECURITY_GROUP_ID tcp 80 0.0.0.0/0
    #add 443 port to the lb security group.
    add_ingress_to_security_group $LOAD_BALANCER_SECURITY_GROUP_ID tcp 443 0.0.0.0/0

    #delete load balancer if exists
    echo "Checking a load balancer with name: $LOAD_BALANCER_NAME "
    LOAD_BALANCER_ARN=`aws elbv2 describe-load-balancers --name $LOAD_BALANCER_NAME 2> /dev/null | jq --raw-output .LoadBalancers[0].LoadBalancerArn`
    if [ "$LOAD_BALANCER_ARN" != "" ]; then
        echo "Deleting $LOAD_BALANCER_NAME for fresh install"
        aws elbv2 delete-load-balancer --load-balancer-arn $LOAD_BALANCER_ARN
    fi

    #create load balancer
    LOAD_BALANCER_ARN=`aws elbv2 create-load-balancer --name $LOAD_BALANCER_NAME  \
    --subnets $VPC_SUBNET1_ID $VPC_SUBNET2_ID --security-groups $LOAD_BALANCER_SECURITY_GROUP_ID | jq --raw-output .LoadBalancers[0].LoadBalancerArn`
    if [ "$LOAD_BALANCER_ARN" == "" ]; then
         echo "Load balancer cannot be created. Check the logs above"
         exit 1
    fi

    #create target group for origin

    ORIGIN_TARGET_GROUP_ARN=`aws elbv2 create-target-group --name $ORIGIN_TARGET_GROUP_NAME --protocol HTTP --port 5080 \
    --vpc-id $VPC_NETWORK_ID | jq --raw-output .TargetGroups[0].TargetGroupArn`
    if [ "$ORIGIN_TARGET_GROUP_ARN" != "" ]; then
        echo $ORIGIN_TARGET_GROUP_ARN > $ORIGIN_TARGET_GROUP_ARN_FILE
    fi

    #enable session stickyness for origin target group
    #sticky session is good for logging in to web console
    ENABLE_STICKY_SESSION_RESULT=`aws elbv2 modify-target-group-attributes --target-group-arn $ORIGIN_TARGET_GROUP_ARN \
            --attributes Key=stickiness.enabled,Value=true Key=stickiness.type,Value=lb_cookie Key=stickiness.lb_cookie.duration_seconds,Value=3600 | jq --raw-output .Attributes[0].Value`

    if [ $ENABLE_STICKY_SESSION_RESULT != true ]; then
        echo "Warning: Origin Target group cannot be set for sticky session. You can enable it on AWS Console"
    fi

    #create target group for edge
    EDGE_TARGET_GROUP_ARN=`aws elbv2 create-target-group --name $EDGE_TARGET_GROUP_NAME --protocol HTTP --port 5080 \
    --vpc-id $VPC_NETWORK_ID | jq --raw-output .TargetGroups[0].TargetGroupArn`

    if [ "$EDGE_TARGET_GROUP_ARN" != "" ]; then
        echo $EDGE_TARGET_GROUP_ARN > $EDGE_TARGET_GROUP_ARN_FILE
    fi

    #enable session stickyness for origin target group
    #sticky session is good for logging in to web console
    ENABLE_STICKY_SESSION_RESULT=`aws elbv2 modify-target-group-attributes --target-group-arn $EDGE_TARGET_GROUP_ARN \
            --attributes Key=stickiness.enabled,Value=true Key=stickiness.type,Value=lb_cookie Key=stickiness.lb_cookie.duration_seconds,Value=3600 | jq --raw-output .Attributes[0].Value`

    if [ $ENABLE_STICKY_SESSION_RESULT != true ]; then
        echo "Warning: Edge Target group cannot be set for sticky session. You can enable it on AWS Console"
    fi

    #create listener 80 port forwared to edge target group arn
    EDGE_TARGET_GROUP_LISTENER_ARN=`aws elbv2 create-listener --load-balancer-arn $LOAD_BALANCER_ARN \
    --protocol HTTP --port 80  \
    --default-actions Type=forward,TargetGroupArn=$EDGE_TARGET_GROUP_ARN | jq --raw-output .Listeners[0].ListenerArn`
    if [ "$EDGE_TARGET_GROUP_LISTENER_ARN" != "" ]; then
        echo $EDGE_TARGET_GROUP_LISTENER_ARN > $EDGE_TARGET_GROUP_LISTENER_ARN_FILE
    fi

    #create listener, 5080 is forwarded to origin target group 
    ORIGIN_TARGET_GROUP_LISTENER_ARN=`aws elbv2 create-listener --load-balancer-arn $LOAD_BALANCER_ARN \
    --protocol HTTP --port 5080  \
    --default-actions Type=forward,TargetGroupArn=$ORIGIN_TARGET_GROUP_ARN | jq --raw-output .Listeners[0].ListenerArn`
    if [ "$ORIGIN_TARGET_GROUP_LISTENER_ARN" != "" ]; then
        echo $ORIGIN_TARGET_GROUP_LISTENER_ARN > $ORIGIN_TARGET_GROUP_LISTENER_ARN_FILE
    fi

    if [ "$ACM_CERTIFICATE_ARN"  != "" ]; then
        #create listener for https ports 443 -> edge 
        EDGE_TARGET_GROUP_LISTENER_ARN=`aws elbv2 create-listener --load-balancer-arn $LOAD_BALANCER_ARN \
            --protocol HTTPS --port 443  --certificates CertificateArn=$ACM_CERTIFICATE_ARN \
            --default-actions Type=forward,TargetGroupArn=$EDGE_TARGET_GROUP_ARN | jq --raw-output .Listeners[0].ListenerArn`
            if [ "$EDGE_TARGET_GROUP_LISTENER_ARN" != "" ]; then
                echo $EDGE_TARGET_GROUP_LISTENER_ARN > $EDGE_TARGET_GROUP_SECURE_LISTENER_ARN_FILE
            fi

        #create listener for https ports 5443 -> origin
        ORIGIN_TARGET_GROUP_LISTENER_ARN=`aws elbv2 create-listener --load-balancer-arn $LOAD_BALANCER_ARN \
            --protocol HTTPS --port 5443  --certificates CertificateArn=$ACM_CERTIFICATE_ARN \
            --default-actions Type=forward,TargetGroupArn=$ORIGIN_TARGET_GROUP_ARN | jq --raw-output .Listeners[0].ListenerArn`
            if [ "$ORIGIN_TARGET_GROUP_LISTENER_ARN" != "" ]; then
                echo $ORIGIN_TARGET_GROUP_LISTENER_ARN > $ORIGIN_TARGET_GROUP_SECURE_LISTENER_ARN_FILE
            fi
    fi
    
}

delete_lb_listener() 
{
    FILE_NAME=$1
    LISTENER_ARN=`cat $FILE_NAME 2>> /dev/null`
    if [ "$LISTENER_ARN" != "" ]; then
        aws elbv2 delete-listener --listener-arn $LISTENER_ARN 
        if [ $? -eq 0 ]; then
            #delete the file if listener is deleted
            rm $FILE_NAME
        fi
    fi
}

uninstall_load_balancer() {

    echo "Uninstalling load balancer components"

    delete_lb_listener $ORIGIN_TARGET_GROUP_LISTENER_ARN_FILE
   
    delete_lb_listener $EDGE_TARGET_GROUP_LISTENER_ARN_FILE

    delete_lb_listener $ORIGIN_TARGET_GROUP_SECURE_LISTENER_ARN_FILE

    delete_lb_listener $EDGE_TARGET_GROUP_SECURE_LISTENER_ARN_FILE


    LOAD_BALANCER_ARN=`aws elbv2 describe-load-balancers --name $LOAD_BALANCER_NAME 2> /dev/null | jq --raw-output .LoadBalancers[0].LoadBalancerArn`
    if [ "$LOAD_BALANCER_ARN" != "" ]; then
        echo "Deleting load balancer"
        aws elbv2 delete-load-balancer --load-balancer-arn $LOAD_BALANCER_ARN
    fi

    TMP_ARN=`cat $ORIGIN_TARGET_GROUP_ARN_FILE 2>> .errorFile`
    if [ "$TMP_ARN" != "" ]; then
        echo "Deleting origin target group"
        aws elbv2 delete-target-group --target-group-arn $TMP_ARN
        if [ $? -eq 0 ]; then
            #delete if it's succesfull
           rm $ORIGIN_TARGET_GROUP_ARN_FILE
        fi
    fi

    TMP_ARN=`cat $EDGE_TARGET_GROUP_ARN_FILE 2>> .errorFile`
    if [ "$TMP_ARN" != "" ]; then
        echo "Deleting edge target group"
        aws elbv2 delete-target-group --target-group-arn $TMP_ARN
         if [ $? -eq 0 ]; then
             #delete if it's succesfull
           rm $EDGE_TARGET_GROUP_ARN_FILE
         fi
    fi
    
    delete_security_group $LOAD_BALANCER_SECURITY_GROUP_NAME
}

print_sample_usage() {
      echo "You should enter Ant Media Server Enterprise Edition AMI ID to continue"
      echo ""
      echo "Sample usage:"
      echo "$0  [-i AMI_ID] [-y true|false] [-t install|uninstall] [-c CERTIFICATE_ARN]"
      echo ""
      echo "Parameters:"
      echo "-i AMI_ID -> Amazon Machine Image Id of the Ant Media Server Enterprise. Optional. If not specified. Uses AWS Marketplace Image "
      echo "-y true|false -> true: Headless install for automation. false: Interactive install. Optional. Default value is false"
      echo "-t uninstall|install -> uninstalls the whole elements in the cluster. Optional. Default value is install"
      echo "-c CERTIFICATE_ARN -> Write certifate arn from AWS ACM binding for HTTPS and WSS connections. Optional. No default value"
      echo ""
}


###########################################################
#### Start Running 
###########################################################

# Usage 
#  -i AMI_ID -y true|false 
# 
# -i AWS AMI ID 
# -y headless process if true,  
# -t install / uninstall
#
while getopts i:y:t:c:u: option
do
  case "${option}" in
    i) 
    AMS_AMI_ID=${OPTARG}
    ;;
    y) 
    HEADLESS_PROCESS=${OPTARG}
    ;;
    t) 
    OPERATION_TYPE=${OPTARG}
    ;;
    c)
    ACM_CERTIFICATE_ARN=${OPTARG}
    ;;
    u)
    UBUNTU_AMI_ID_FOR_MONGODB=${OPTARG}
    ;;
   esac
done


command -v aws > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "aws cli is not installed. Please install aws cli tools."
    exit 1
fi

command -v jq > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "jq is not installed. Please install jq"
    exit 1
fi

if [ "$OPERATION_TYPE" == "install" ]; then

    if [ -z "$AMS_AMI_ID" ]; then

        echo "Getting Ant Media Server Enterprise AMI ID from AWS Marketplace"
        AMS_AMI_ID=`aws ec2 describe-images  --filters Name=product-code,Values=$AWS_MARKETPLACE_AMS_ENTERPRISE_PRODUCT_CODE Name=is-public,Values=true | jq --raw-output .Images[0].ImageId`
        if [ "$AMS_AMI_ID" == "null" ]; then
            echo "Cannot find Ant Media Server Enterprise AMI in your region. Please specify it on command line parameter"
            echo ""
            echo ""
            print_sample_usage
            exit 1 
        fi
    fi

    if [ -z "$UBUNTU_AMI_ID_FOR_MONGODB" ]; then

        echo "Getting Ubuntu 16.04 AMI ID for installing MongoDB"
        UBUNTU_AMI_ID_FOR_MONGODB=`aws ec2 describe-images  --owners 099720109477 --filters Name=name,Values=*ubuntu-xenial-16.04-amd64-server* Name=virtualization-type,Values=hvm Name=architecture,Values=x86_64 Name=is-public,Values=true | jq --raw-output .Images[0].ImageId`
        if [ "$UBUNTU_AMI_ID_FOR_MONGODB" == "null" ]; then
           echo "Cannot find Ubuntu 16.04 AMI ID in your region. Please specify it on command line"
           echo ""
           echo ""
           print_sample_usage
           exit 1
        fi
     fi
    


    #check if key pair exists
    TMP_VAR=`aws ec2 describe-key-pairs --key-names $KEYPAIR_NAME | jq --raw-output .KeyPairs[0].KeyName`

    if [ "$TMP_VAR" != "$KEYPAIR_NAME" ]; then
        #if not equals, it means key pair does not exist, create the key pair
        echo "Creating key pair $KEYPAIR_NAME"
        aws ec2 create-key-pair --key-name $KEYPAIR_NAME --query 'KeyMaterial' --output text > $KEYPAIR_NAME.pem
        #change mod to 400 for security 
        chmod 400 $KEYPAIR_NAME.pem
    else
        echo "$KEYPAIR_NAME already exists. Skipping creating key pair"
    fi


    # get mongo db instance init file
    if [ ! -f $MONGO_DB_INSTANCE_INIT_FILE ]; then
        wget -O $MONGO_DB_INSTANCE_INIT_FILE https://raw.githubusercontent.com/ant-media/Scripts/master/aws_cluster_install/mongodb-instance-init.sh 
    fi

    # get instance init file
    if [ ! -f $AMS_CHANGE_MODE_TO_CLUSTER ]; then 
        wget -O $AMS_CHANGE_MODE_TO_CLUSTER https://raw.githubusercontent.com/ant-media/Scripts/master/aws_cluster_install/ams-change-mode-to-cluster.sh
    fi

    

    

    ################################################
    ############ Getting VPC Parameters ############
    ################################################
    #Get the first VPC, it's the default VPC

    VPC_DESC=`aws ec2 describe-vpcs`
    VPC_NETWORK_ID=`echo $VPC_DESC | jq --raw-output .Vpcs[0].VpcId`

    if [ "$VPC_NETWORK_ID" == "" ]; then
    echo "VPC network not available in your AWS account. Make sure you have one VPC network"
    exit 1
    fi

    VPC_CIDR_NETWORK=`echo $VPC_DESC | jq --raw-output .Vpcs[0].CidrBlock`

    VPC_SUBNETS_DESC=`aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_NETWORK_ID`
    #assuming default vpc has more than 2 subnets and they are in different availability zones
    #TODO: check that subnets exists and they are in different availability zones

    VPC_SUBNET1_ID=`echo $VPC_SUBNETS_DESC | jq --raw-output .Subnets[0].SubnetId`
    if [ "$VPC_SUBNET1_ID" == "" ]; then
    echo "VPC network's subnet not available in your AWS account. Make sure you have at least two subnets"
    exit 1
    fi

    VPC_SUBNET2_ID=`echo $VPC_SUBNETS_DESC | jq --raw-output .Subnets[1].SubnetId`
    if [ "$VPC_SUBNET2_ID" == "" ]; then
    echo "VPC network's subnet[1] not available in your AWS account. Make sure you have at least two subnets"
    exit 1
    fi


    #####################################################
    ############ Installing MONGODB Instance ############
    #####################################################
    input=Y
    if [ "$HEADLESS_PROCESS" == "false" ]; then
        read -p "Do you need to install MongoDB instance to run the cluster?(Y/n)" input
    fi

    case $input in
        [nN][oO]|[nN])
    echo "Skipping MongoDB instance installation"
        ;;
        *)
    #install mongodb instance by default
    echo "Installing MongoDB instance"
    install_mongodb_instance
    ;;
    esac

    ###########################################################
    ############ Installing  Elastic Load Balancer ############
    ###########################################################

    input=Y
    if [ "$HEADLESS_PROCESS" == "false" ]; then
        read -p "Do you need to install Load Balancer?(Y/n) " input
    fi

    case $input in
        [nN][oO]|[nN])
    echo "Skipping Load Balancer Installation"
        ;;
        *)
    #install mongodb instance by default
    echo "Installing Load Balancer"
    install_load_balancer
    ;;
    esac


    ########################################################
    ############ Installing  Origin Scale Group ############
    ########################################################

    input=Y
    if [ "$HEADLESS_PROCESS" == "false" ]; then
        read -p "Do you need to install Origin Scale Group?(Y/n)" input
    fi

    case $input in
        [nN][oO]|[nN])
    echo "Skipping Origin Scale Group Installation"
        ;;
        *)
    #install mongodb instance by default
    echo "Installing Origin Scale Group"
    install_origin_scale_group
    ;;
    esac

    ########################################################
    ############ Installing Edge Scale Group ############
    ########################################################

    input=Y
    if [ "$HEADLESS_PROCESS" == "false" ]; then
        read -p "Do you need to install Edge Scale Group?(Y/n)" input
    fi

    case $input in
        [nN][oO]|[nN])
    echo "Skipping Edge Scale Group Installation"
        ;;
        *)
    #install mongodb instance by default
    echo "Installing Edge Scale Group"
    install_edge_scale_group
    ;;
    esac


elif [ "$OPERATION_TYPE" == "uninstall" ]; then
    ########################################################
    ############     Uninstalling Everything    ############
    ########################################################
    uninstall_load_balancer
    uninstall_mongodb_instance
    uninstall_edge_scale_group
    uninstall_origin_scale_group
else 
   echo "Unspecified operation type. Choose install or uninstall"
   print_sample_usage
   exit 1;
fi