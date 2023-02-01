#!/bin/bash
#
#  This bash script converts your VoD files to HLS format. (720p,480p,240p)
#
#  Installation Instructions
#  sudo apt-get update && sudo apt-get install ffmpeg -y
#  vim [AMS-DIR]/webapps/applications(LiveApp or etc.)/WEB-INF/red5-web.properties
#  settings.vodUploadFinishScript=/Script-DIR/vod_transcode.sh
#  sudo service antmedia restart
#

# Just convert to HLS 
HLS="1"

file=$1
file_name=$(basename $file .mp4)

# Bitrates
# 720p
a=("1280x720" "2500k")
# 480p
b=("640x480" "1500k")
# 240p
c=("320x240" "800k")

cd ${file%/*}/

if [ $HLS == "1" ]; then
	$(command -v ffmpeg) -i $file -codec copy -hls_segment_filename ${file_name}_%v/${file_name}%03d.ts -use_localtime_mkdir 1 ${file_name}.m3u8
else
	$(command -v ffmpeg) -i $file -crf 27 -preset veryfast -map 0:v:0 -map 0:a:0 -map 0:v:0 -map 0:a:0 -map 0:v:0 -map 0:a:0 -s:v:0 ${a[0]} -c:v:0 libx264 -b:v:0 ${a[1]} -s:v:1 ${b[0]} -c:v:1 libx264 -b:v:1 ${b[1]} -s:v:2 ${c[0]} -c:v:2 libx264 -b:v:2 ${c[1]} -c:a aac -f hls -hls_playlist_type vod -master_pl_name ${file_name}.m3u8 -hls_segment_filename ${file_name}_%v/${file_name}%03d.ts -use_localtime_mkdir 1 -var_stream_map "v:0,a:0,name:720p v:1,a:1,name:480p v:2,a:2,name:240p" ${file_name}_%v.m3u
fi
