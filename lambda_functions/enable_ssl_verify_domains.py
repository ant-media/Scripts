import boto3, re, requests, json

HOSTED_ZONE_ID = 'Z3BEXQLL4B8OB1'
DOMAIN = 'antmedia.cloud'
ec2 = boto3.resource('ec2')
route53 = boto3.client('route53')
URL = ":5080/WebRTCAppEE/rest/v2/version"
s3_client = boto3.client('s3')
BUCKET_NAME = "antmedia-subdomain-check"
LAMBDA_LOCAL_TMP_FILE = '/tmp/invalid_domains-2.txt'

def lambda_handler(event, context):

    headers = {
        'Content-Type': 'application/json',
    }

    res = route53.list_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        StartRecordName='ams-*',
        StartRecordType='A',
        MaxItems='5000',
    )

    for resource in res['ResourceRecordSets']:
        name = re.findall('ams-([0-9]*)', resource['Name'])
        if name:
            subdomain_list = resource['Name'][:-1]
            try:
                response = requests.get("http://" + subdomain_list + URL, headers=headers, timeout=1)
                response.raise_for_status()
                if response.status_code == 200:
                    print("valid", subdomain_list)
            except requests.exceptions.RequestException as err:
                    print("invalid", subdomain_list)
                    with open(LAMBDA_LOCAL_TMP_FILE, 'a') as f:
                        f.write(subdomain_list + "\n")

    s3_client.upload_file(LAMBDA_LOCAL_TMP_FILE, 'antmedia-subdomain-check', 'invalid_domains-2.txt')
    return {
        'statusCode': 200,
        'body': json.dumps('success')
    }

