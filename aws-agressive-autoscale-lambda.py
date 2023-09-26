# This Lambda function calculates the number of instances based on the number of Viewers and Publishers coming from the API and quickly increases the instance in Auto Scaling.

import boto3, os

def lambda_handler(event, context):
    # Get the viewer_count and publisher_count from api gateway
    viewer_count = event['params']['querystring']['viewer_count']
    publisher_count = event['params']['querystring']['publisher_count']

    # Constants for instance limits
    C5_XLARGE_EDGE_LIMIT = 150
    C5_4XLARGE_EDGE_LIMIT = C5_XLARGE_EDGE_LIMIT * 4
    C5_9XLARGE_EDGE_LIMIT = C5_XLARGE_EDGE_LIMIT * 7
    C5_XLARGE_ORIGIN_LIMIT = 40
    C5_4XLARGE_ORIGIN_LIMIT = C5_XLARGE_ORIGIN_LIMIT * 4
    C5_9XLARGE_ORIGIN_LIMIT = C5_XLARGE_ORIGIN_LIMIT * 9

    # Initialize AWS clients (use the environment variables)
    autoscaling_client = boto3.client('autoscaling')
    ec2_client = boto3.client('ec2')
    # Find Auto Scaling Group names with specific prefixes
    asg_names = autoscaling_client.describe_auto_scaling_groups()
    asg_edge_name = [group for group in asg_names['AutoScalingGroups'] if 'EdgeGroup' in group['AutoScalingGroupName']]
    asg_origin_name = [group for group in asg_names['AutoScalingGroups'] if
                       'OriginGroup' in group['AutoScalingGroupName']]
    asg_edge_group_names = [group['AutoScalingGroupName'] for group in asg_edge_name][0]
    asg_origin_group_names = [group['AutoScalingGroupName'] for group in asg_origin_name][0]

    print(asg_edge_name)
    print(asg_edge_group_names)

    # Describe Auto Scaling Groups
    edge_autoscaling_group = autoscaling_client.describe_auto_scaling_groups(
        AutoScalingGroupNames=[asg_edge_group_names])
    origin_autoscaling_group = autoscaling_client.describe_auto_scaling_groups(
        AutoScalingGroupNames=[asg_origin_group_names])

    # Get instance types and current instance counts
    edge_instance_type = edge_autoscaling_group['AutoScalingGroups'][0]['Instances'][0]['InstanceType']
    origin_instance_type = edge_autoscaling_group['AutoScalingGroups'][0]['Instances'][0]['InstanceType']
    edge_current_instance_count = len(edge_autoscaling_group['AutoScalingGroups'][0]['Instances'])
    origin_current_instance_count = len(origin_autoscaling_group['AutoScalingGroups'][0]['Instances'])

    # Check and upgrade Auto Scaling Groups based on instance type
    if edge_instance_type == "c5.xlarge":
        edge_count = -(-viewer_count // C5_XLARGE_EDGE_LIMIT)
        print(edge_count)
        check_and_upgrade(edge_count, edge_current_instance_count, asg_edge_group_names)
    if origin_instance_type == "c5.xlarge":
        origin_count = -(-publisher_count // C5_XLARGE_ORIGIN_LIMIT)
        print(origin_count)
        check_and_upgrade(origin_count, origin_current_instance_count, asg_origin_group_names)
    if edge_instance_type == "c5.4xlarge":
        edge_count = -(-viewer_count // C5_4XLARGE_EDGE_LIMIT)
        print(edge_count)
        check_and_upgrade(edge_count, edge_current_instance_count, asg_edge_group_names)
    if origin_instance_type == "c5.4xlarge":
        origin_count = -(-publisher_count // C5_4XLARGE_ORIGIN_LIMIT)
        print(origin_count)
        check_and_upgrade(origin_count, origin_current_instance_count, asg_origin_group_names)
    if edge_instance_type == "c5.9xlarge":
        edge_count = -(-viewer_count // C5_9XLARGE_EDGE_LIMIT)
        print(edge_count)
        check_and_upgrade(edge_count, edge_current_instance_count, asg_edge_group_names)
    if origin_instance_type == "c5.9xlarge":
        origin_count = -(-publisher_count // C5_9XLARGE_ORIGIN_LIMIT)
        print(origin_count)
        check_and_upgrade(origin_count, origin_current_instance_count, asg_origin_group_names)


def check_and_upgrade(count, current_instance_count, asg_name):
    autoscaling_client = boto3.client('autoscaling')
    if count > current_instance_count:
        response = autoscaling_client.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            DesiredCapacity=count,
            MinSize=count
        )
