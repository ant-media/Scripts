#!/bin/bash

AUTH_URL="https://auth.cloud.ovh.net/v3/"
API_VERSION="3"
USER_DOMAIN_NAME="default"
PROJECT_DOMAIN_NAME="default"
TENANT_ID=""
TENANT_NAME=""
USERNAME=""
PASSWORD=""

os="openstack --os-auth-url $AUTH_URL --os-identity-api-version $API_VERSION --os-user-domain-name $USER_DOMAIN_NAME \
			  --os-project-domain-name $PROJECT_DOMAIN_NAME --os-tenant-id $TENANT_ID --os-tenant-name $TENANT_NAME  \
			  --os-username $USERNAME  --os-password $PASSWORD "

instance_type="b2-7"
stream_name="stream99"
viewers="100"

#Download Ant Media Server
gdrive1_access_token=""
gdrive1_access=""

#Upload CPU and Memory Usage
gdrive2_access_token=""
gdrive2_access=""
gdrive2_secret=""
gdrive2_clientid=""

delete_instances() {

	$os --os-region-name DE1 server delete antmedia_test_vps
	$os --os-region-name DE1 server delete antmedia_load_vps
}

api_settings () {

	curl -s -H "Content-Type: application/json" -X POST -d '{"email":"test@antmedia.io","password":"'test123'","fullName":"Antmedia"}' http://$1:5080/rest/addInitialUser
	curl -c cookie.txt 'http://'$1':5080/rest/authenticateUser' -H 'Content-Type: application/json' --data-binary '{"email":"test@antmedia.io","password":"test123"}'
	curl -b cookie.txt 'http://'$1':5080/rest/changeSettings/WebRTCAppEE' -H 'Content-Type: application/json' --data-binary $'{"remoteAllowedCIDR":"127.0.0.1, 0.0.0.0/0","mp4MuxingEnabled":false,"addDateTimeToMp4FileName":false,"hlsMuxingEnabled":true,"encoderSettingsString":"","hlsListSize":"5","hlsTime":"2","webRTCEnabled":true,"useOriginalWebRTCEnabled":false,"deleteHLSFilesOnEnded":true,"tokenHashSecret":"","hashControlPublishEnabled":false,"hashControlPlayEnabled":false,"listenerHookURL":"","acceptOnlyStreamsInDataStore":false,"acceptOnlyRoomsInDataStore":false,"tokenControlEnabled":false,"hlsPlayListType":"","facebookClientId":"1898164600457124","facebookClientSecret":"6c02b406d3e94426c5553c3c9bc17345","periscopeClientId":"Q90cMeG2gUzC6fImXcp2SvyVqwVSvGDlsFsRF4Uia9NR1M-Zru","periscopeClientSecret":"dBCjxFbawo436VSWMvuD5SDSZoSdhew_-Fvrh5QhrBXuKoelVM","youtubeClientId":"183604002006-3ojdgvmqp7rcc6d66atkkhk7p0btie9j.apps.googleusercontent.com","youtubeClientSecret":"HDwoClZhJzPshtmnWjSJSHjx","vodFolder":"","previewOverwrite":false,"stalkerDBServer":"","stalkerDBUsername":"","stalkerDBPassword":"","objectDetectionEnabled":false,"createPreviewPeriod":5000,"restartStreamFetcherPeriod":0,"streamFetcherBufferTime":0,"mySqlClientPath":"/usr/local/antmedia/mysql","muxerFinishScript":"","webRTCFrameRate":20,"webRTCPortRangeMin":0,"webRTCPortRangeMax":0,"stunServerURI":"stun:stun.l.google.com:19302","webRTCTcpCandidatesEnabled":true,"portAllocatorFlags":0,"collectSocialMediaActivity":false,"encoderName":null,"encoderPreset":null,"encoderProfile":null,"encoderLevel":null,"encoderRc":null,"encoderSpecific":null,"encoderThreadCount":0,"encoderThreadType":0,"previewHeight":480,"generatePreview":true,"writeStatsToDatastore":true,"encoderSelectionPreference":"'gpu_and_cpu'","allowedPublisherCIDR":null,"excessiveBandwidthValue":300000,"excessiveBandwidthCallThreshold":3,"excessiveBandwithTryCountBeforeSwitchback":4,"excessiveBandwidthAlgorithmEnabled":false,"packetLossDiffThresholdForSwitchback":10,"rttMeasurementDiffThresholdForSwitchback":20,"replaceCandidateAddrWithServerAddr":false,"appName":"WebRTCAppEE","encodingTimeout":5000,"webRTCClientStartTimeoutMs":5000,"defaultDecodersEnabled":false,"updateTime":0,"encoderSettings":[],"httpForwardingExtension":"''","httpForwardingBaseURL":"''","maxAnalyzeDurationMS":500,"disableIPv6Candidates":true,"rtspPullTransportType":"tcp","maxFpsAccept":0,"maxResolutionAccept":0,"maxBitrateAccept":0,"h264Enabled":true,"vp8Enabled":false,"dataChannelEnabled":false,"dataChannelPlayerDistribution":"all","rtmpIngestBufferTimeMs":0,"hlsFlags":null,"dataChannelWebHook":null}'
}

api_stream_exist() {

	if [ `curl -s 'http://'$1':5080/WebRTCAppEE/rest/v2/broadcasts/count' | jq '.number'` -eq "0" ]; then
		return 1
	else
		return 0
	fi
}

api_count() {

	count_api=`curl -s 'http://'$1':5080/WebRTCAppEE/rest/v2/broadcasts/list/0/10' | jq '.[0].webRTCViewerCount'`

	if [ "$count_api" != "null" ]; then
		if [ "$count_api" -ge "5" ]; then
			return 0
		else
			#echo "Load script is not working"
			#mail function
			return 1
		fi
	else
		#echo "Load script is not working."
		return 1
	fi
}

create_ams_instance() {

	$os --os-region-name "DE1" server create --flavor $instance_type --image "Ubuntu 18.04" --network Ext-Net --key-name ovh --security-group default antmedia_test_vps > /dev/null
	sleep 10
	while [ -z $($os --os-region-name "DE1" server list --name antmedia_test_vps -f value -c Networks | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}") ]; do
		sleep 1	
	done
	ip=`$os --os-region-name "DE1" server list --name antmedia_test_vps -f value -c Networks | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
	sleep 60
	ssh -i ovh.pem -oStrictHostKeyChecking=no ubuntu@$ip << EOF
	sudo curl https://rclone.org/install.sh | sudo bash &> /dev/null && mkdir -p ~/.config/rclone/
	echo -e """[gdrive]\ntype = drive\nscope = drive\nroot_folder_id = 1mBh0K1sNcyXS5isem8w6feVnfvppp2gx\ntoken = {\"access_token\":\"$gdrive1_access_token\",\"token_type\":\"Bearer\",\"refresh_token\":\"$gdrive1_access\",\"expiry\":\"2019-03-05T11:48:05.106364+03:00\"}""" > ~/.config/rclone/rclone.conf 
	rclone copy gdrive:ant-media-server-enterprise-canary-candidate.zip /tmp/
	wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh && bash install_ant-media-server.sh /tmp/ant-media-server-enterprise-canary-candidate.zip &> /dev/null
	sudo apt-get install sysstat -qq -y 
	sudo sed -i 's/false/true/g' /etc/default/sysstat &> /dev/null
	sudo systemctl restart sysstat

EOF
    echo -e "Ant Media Server Instance Created. \nIp address: $ip"

}


create_load_instance() {

	$os --os-region-name "DE1" server create --flavor $instance_type --image "Ubuntu 20.04" --network Ext-Net --key-name ovh --security-group default antmedia_load_vps > /dev/null
	sleep 10
	while [ -z $($os --os-region-name "DE1" server list --name antmedia_load_vps -f value -c Networks | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}") ]; do
		sleep 1	
	done
	ip2=`$os --os-region-name "DE1" server list --name antmedia_load_vps -f value -c Networks | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
	sleep 60
	ssh -i ovh.pem -oStrictHostKeyChecking=no ubuntu@$ip2 << EOF

	sudo apt-get update &> /dev/null && sudo apt-get install unzip openjdk-8-jre ffmpeg screen -y -qq &> /dev/null
	wget https://antmedia.io/webrtctest-release.zip &> /dev/null
	unzip webrtctest-release.zip &> /dev/null
EOF

    echo -e "Load Instance Created. \nIp address: $ip2"

}

create_ams_instance
create_load_instance
api_settings $ip


#Load
if [ `api_stream_exist $ip; echo $?` == "1" ]; then
	ssh -i ovh.pem -oStrictHostKeyChecking=no ubuntu@$ip2 "ffmpeg -stream_loop 50 -re -i ~/webrtctest/test.mp4 -codec copy -f flv rtmp://$ip/WebRTCAppEE/$stream_name > /dev/null 2>&1 < /dev/null &"
	echo "test dosyasi stream ediliyor."
	sleep 10
	if [ `api_stream_exist $ip; echo $?` == "0" ]; then
		ssh -i ovh.pem -oStrictHostKeyChecking=no ubuntu@$ip2 "cd ~/webrtctest && screen -d -m bash run.sh -m player -n $viewers -i $stream_name -s $ip -u false &> /dev/null"
		sleep 10
		if [ `api_count $ip;echo $?` == "0" ]; then
			echo "CPU and Memory datas are saving."
			ssh -i ovh.pem -oStrictHostKeyChecking=no ubuntu@$ip "sar -u 5  | tr -s ' ' ',' > /tmp/cpu-$(date +"%d-%m-%Y").csv & sar -r 5  | tr -s ' ' ',' > /tmp/memory-$(date +"%d-%m-%Y").csv & "
		fi

		while :
		do
			sleep 10
			if [ `api_count $ip;echo $?` == "1" ]; then
				ssh -i ovh.pem -oStrictHostKeyChecking=no ubuntu@$ip "pkill sar"
				echo "Uploading to gdrive"
				ssh -i ovh.pem -oStrictHostKeyChecking=no ubuntu@$ip << EOF 
				echo -e """[gdrive-archive]\ntype = drive\nclient_id = $gdrive2_clientid\nclient_secret = $gdrive2_secret\nscope = drive\nroot_folder_id= 1vIuoznubQArC1mwIxjgFg-Ca60YUXI1g\ntoken = {\"access_token\":\"$gdrive2_access_token\",\"token_type\":\"Bearer\",\"refresh_token\":\"$gdrive2_access\",\"expiry\":\"2020-06-29T15:03:49.491458963Z\"}""" >> ~/.config/rclone/rclone.conf				
				/usr/bin/rclone copy /tmp/memory-$(date +"%d-%m-%Y").csv gdrive-archive: &
				wait $!
				/usr/bin/rclone copy /tmp/cpu-$(date +"%d-%m-%Y").csv gdrive-archive: &
				wait $!
			
EOF
				break
			fi
		done
	fi
fi

echo "Deleting instances.."
delete_instances
