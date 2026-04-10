#!/bin/bash 
BASEDIR=$(dirname "$0")
cd $BASEDIR
  

#./test-launch "( videotestsrc pattern=snow ! video/x-raw,width=1920,height=1080,format=I420 ! videoconvert ! x264enc ! rtph264pay name=pay0 pt=96 audiotestsrc ! audio/x-raw,channels=2,rate=48000 !  audioconvert ! avenc_aac ! rtpmp4apay name=pay1 pt=97 )"


./test-launch "( videotestsrc pattern=snow ! video/x-raw,width=1920,height=1080,format=I420,framerate=25/1 ! videoconvert ! x264enc bitrate=2000 tune=zerolatency ! rtph264pay name=pay0 pt=96 audiotestsrc ! audio/x-raw,channels=2,rate=48000 ! audioconvert ! avenc_aac ! rtpmp4apay name=pay1 pt=97 )"
