#!/bin/bash
#
#  This bash script converts your VoD files to HLS format. (720p, 480p, 240p)
#
#  Installation Instructions
#  sudo apt-get update && sudo apt-get install ffmpeg -y
#  switch to application advance properties and set the property,
#  "vodUploadFinishScript": "/path/to/vod_transcode.sh ",
#  sudo service antmedia restart

# Don't forget to change the Ant Media Server App Name in which you want to save the files
AMS_APP_NAME="WebRTCAppEE"

file=$1
file_name=$(basename $file .mp4)

# Bitrates and resolutions
resolutions=("1280x720" "640x480" "320x240")
bitrates=("2500k" "1500k" "800k")
names=("720p" "480p" "240p")

cd /usr/local/antmedia/webapps/$AMS_APP_NAME/streams/

# Create directories for each resolution
for name in "${names[@]}"; do
    mkdir -p ${file_name}_${name}
done

$(command -v ffmpeg) -i $file \
    -map 0:v -map 0:a -s:v:0 ${resolutions[0]} -c:v:0 libx264 -b:v:0 ${bitrates[0]} \
    -map 0:v -map 0:a -s:v:1 ${resolutions[1]} -c:v:1 libx264 -b:v:1 ${bitrates[1]} \
    -map 0:v -map 0:a -s:v:2 ${resolutions[2]} -c:v:2 libx264 -b:v:2 ${bitrates[2]} \
    -c:a aac -f hls -hls_playlist_type vod \
    -master_pl_name ${file_name}.m3u8 \
    -hls_segment_filename ${file_name}_%v/${file_name}%04d.ts \
    -var_stream_map "v:0,a:0,name:720p v:1,a:1,name:480p v:2,a:2,name:240p" \
    ${file_name}_%v/${file_name}.m3u8
