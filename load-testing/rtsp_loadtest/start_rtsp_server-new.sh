#!/bin/bash 
BASEDIR=$(dirname "$0")
cd $BASEDIR
  

#./test-launch "( videotestsrc pattern=snow ! video/x-raw,width=640,height=360,format=I420 ! videoconvert ! x264enc ! rtph264pay name=pay0 pt=96 audiotestsrc ! audio/x-raw,channels=2,rate=48000 !  audioconvert ! avenc_aac ! rtpmp4apay name=pay1 pt=97 )"


./test-launch "( filesrc location=/home/yash/bigbunny.mp4 ! qtdemux name=demux demux.video_0 ! decodebin ! videoconvert ! videoscale ! video/x-raw,width=1920,height=1080,framerate=25/1 ! x264enc tune=zerolatency ! rtph264pay name=pay0 pt=96 demux.audio_0 ! decodebin ! audioconvert ! audioresample ! audio/x-raw,rate=48000,channels=2 ! avenc_aac ! rtpmp4apay name=pay1 pt=97 )"

