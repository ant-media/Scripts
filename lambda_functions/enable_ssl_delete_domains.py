import boto3


def lambda_handler(event, context):
    # Update the bucket name with your S3 bucket name
    bucket_name = 'antmedia-subdomain-check'
    
    file1_key = 'invalid_domains-1.txt'
    file2_key = 'invalid_domains-2.txt'
    output_key = 'invalid_domains.txt'

    # Get the file name from the event
    file_name = 'invalid_domains.txt'

    # Create an S3 client
    s3_client = boto3.client('s3')
    
    compare_files(bucket_name, file1_key, file2_key, output_key)

    try:
        # Download the file from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=file_name)
        contents = response['Body'].read().decode('utf-8')

        # Extract invalid subdomains from the file contents
        invalid_subdomains = contents.split('\n')

        # Create a Route 53 client
        route53_client = boto3.client('route53')

        # Delete the Route 53 resource record sets for each invalid subdomain
        for subdomain in invalid_subdomains:
            domain_name = subdomain.strip() + '.'
            print (domain_name)

            # List the resource record sets in the hosted zone
            response = route53_client.list_resource_record_sets(
                HostedZoneId='Z3BEXQLL4B8OB1',
                StartRecordName=domain_name,
                StartRecordType='A',  # Change to the appropriate record type
                MaxItems='1'
            )

            record_sets = response['ResourceRecordSets']

            # Verify that the subdomain exists in the hosted zone
            if len(record_sets) > 0 and record_sets[0]['Name'] == domain_name:
                # Delete the resource record set
                response = route53_client.change_resource_record_sets(
                    HostedZoneId='Z3BEXQLL4B8OB1',
                    ChangeBatch={
                        'Changes': [
                            {
                                'Action': 'DELETE',
                                'ResourceRecordSet': record_sets[0]
                            }
                        ]
                    }
                )
            s3_client.delete_object(Bucket=bucket_name, Key=file_name)

        return {
            'statusCode': 200,
            'body': 'Subdomains removed successfully'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }


def compare_files(bucket, file1_key, file2_key, output_key):
    s3 = boto3.client('s3')
    
    # Download file 1
    file1_obj = s3.get_object(Bucket=bucket, Key=file1_key)
    file1_content = file1_obj['Body'].read().decode('utf-8')
    
    # Download file 2
    file2_obj = s3.get_object(Bucket=bucket, Key=file2_key)
    file2_content = file2_obj['Body'].read().decode('utf-8')
    
    # Compare the contents
    same_lines = []
    for line in file1_content.splitlines():
        if line in file2_content:
            same_lines.append(line)
    
    # Write same lines to the output file
    output_content = "\n".join(same_lines)
    s3.put_object(Body=output_content.encode('utf-8'), Bucket=bucket, Key=output_key)
