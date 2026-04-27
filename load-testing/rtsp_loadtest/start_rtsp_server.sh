#!/bin/bash

BASEDIR=$(dirname "$0")
cd "$BASEDIR"

# Take MP4 file as argument
MP4_FILE="$1"

if [ -z "$MP4_FILE" ]; then
    echo "Usage: $0 <mp4-file-path>"
    exit 1
fi

# Convert to absolute path (important for uri=file://)
MP4_FILE_ABS=$(realpath "$MP4_FILE")

echo "Using MP4 file: $MP4_FILE_ABS"

./test-launch "( 
uridecodebin uri=file://$MP4_FILE_ABS name=dec 

dec. ! queue ! videoconvert ! videoscale ! videorate ! 
video/x-raw,width=1920,height=1080,framerate=30/1 ! 
x264enc bitrate=2000 key-int-max=60 tune=zerolatency speed-preset=veryfast ! 
rtph264pay name=pay0 pt=96 

dec. ! queue ! audioconvert ! audioresample ! 
audio/x-raw,rate=48000,channels=2 ! 
avenc_aac ! rtpmp4apay name=pay1 pt=97 
)"
