#!/bin/bash

# Please make sure you installed FFmpeg before running the script.
# apt-get install -y ffmpeg

# TARGET : The location of the transcoded file.
# BITRATE: Bitrate 

INPUT="$1"
TARGET="/usr/local/antmedia/custom"
BITRATE="4000k"

# If you want to upload to S3, fill in the below lines.
AWS_ACCESS_KEY=""
AWS_SECRET_KEY=""
AWS_DEFAULT_REGION=""
S3_BUCKET_NAME=""
S3_UPLOAD="NO"

mkdir -p $TARGET
chown -R antmedia:antmedia $TARGET

upload(){

	if [ -z `which aws` ]; then
	rm -r aws* > /dev/null 2>&1
	echo "Please wait. AWS Client is installing..."
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" > /dev/null 2>&1
	unzip awscliv2.zip > /dev/null 2>&1 
	sudo ./aws/install &
	wait $!
	rm -r aws*
	fi

	# Set credentials 
	aws configure set aws_access_key_id $AWS_ACCESS_KEY
	aws configure set aws_secret_access_key $AWS_SECRET_KEY
	aws configure set default.region $AWS_DEFAULT_REGION
	aws s3 sync $TARGET s3://$S3_BUCKET_NAME/
}

FILE=`echo $INPUT |egrep "[0-9]+p"`
FILE_NAME=`echo $FILE |egrep "[0-9]+p"  | awk -F "/" '{print $(NF-0)}'`

echo $FILE | xargs -I {} ffmpeg -v quiet -i {} -c:v libx264 -b:v $BITRATE -bufsize 1835k $TARGET/$FILE_NAME

if [ "$S3_UPLOAD" == "YES" ]; then
	upload
fi