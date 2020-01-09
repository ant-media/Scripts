#!/bin/bash

echo '''{
            "Comment": "CREATE/DELETE/UPSERT a record ",
            "Changes": [{
            "Action": "CREATE",
                        "ResourceRecordSet": {
                                    "Name":"test.antmedia.cloud",
                                    "Type": "A",
                                    "TTL": 300,
                                    "ResourceRecords": [{ "Value":"1.1.1.1"}]
}}]}''' > aws_a.json

aws_env=$(<.env)
AWS_ACCESS_KEY=`echo $aws_env | awk '{print $1}'`
AWS_SECRET_KEY=`echo $aws_env | awk '{print $2}'`
AWS_JSON="aws_a.json"

#aws
if [ -z `which aws2` ]; then
	rm -r aws* > /dev/null 2>&1
	echo "Please wait. AWS Client is installing..."
	curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" > /dev/null 2>&1
	unzip awscliv2.zip > /dev/null 2>&1 
	sudo ./aws/install &
	wait $!
	echo "AWS Client installed."
	rm -r aws*
fi

#Aws Configuration

aws2 configure set aws_access_key_id $AWS_ACCESS_KEY
aws2 configure set aws_secret_access_key $AWS_SECRET_KEY
aws2 configure set output json

usage() {

	echo ""
	echo "Usage: "
	echo "-k ssh key"
	echo "-u username"
	echo "-i ip addrress"
	echo "-d subdomain name (test01.antmedia.cloud)"

}

if [ "$#" -eq 0 ]; then
	usage
fi

while getopts k:u:i:d: option 
do 
 case "${option}" 
 in 
 k) k=${OPTARG};; 
 u) u=${OPTARG};; 
 i) i=${OPTARG};; 
 d) d=${OPTARG};; 
 esac 
done 



if [[ ! -z $k  &&  ! -z $u  &&  ! -z $i  &&  ! -z $d ]]; then
	if [ ! -f $k ]; then
		echo "SSH key doesn't exist."
		exit 1
	elif [ ! -f $AWS_JSON ]; then
		echo "AWS Json file doesn't exist."
	fi
	check=`aws2 route53 list-resource-record-sets --hosted-zone-id Z3BEXQLL4B8OB1 | grep "Name" | awk '{print $2}' | sed ''s/^.//';s/...$//'`
	for c in $check; do
		if [ "$c" == "$d" ]; then
			echo "Subdomain exists"
			exit 1
		fi
	done

	#json file
	sed -i 's^"Name".*^"Name":'\"$d\",'^' $AWS_JSON
	sed -i 's^"Value":.*^"Value":'\"$i\"}]'^' $AWS_JSON
	sleep 1

	#create dns record
	echo "Creating DNS Record"
	aws2 route53 change-resource-record-sets --hosted-zone-id Z3BEXQLL4B8OB1 --change-batch file://$AWS_JSON
	while [ -z $(dig +short $d @8.8.8.8) ]; do
		now=$(date +"%H:%M:%S")
		echo "$now > Please wait: dns failure"
		sleep 10
	done
	echo "Dns success"
	#ssl install script
	echo "Installing SSL Certificate"
	ssh -i $k $u@$i "sudo bash /usr/local/antmedia/enable_ssl.sh -d $d"

fi
