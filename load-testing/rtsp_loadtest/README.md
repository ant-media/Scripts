

This is the compiled version of gstreamer/subprojects/gst-rtsp-server/examples/test-launch.c in ubuntu 22.04 for gstreamer 1.20.0

RTSP Server can run with

./test-launch "( videotestsrc pattern=snow ! video/x-raw,width=1280,height=720,format=I420 ! videoconvert ! x264enc ! rtph264pay name=pay0 pt=96 audiotestsrc ! audio/x-raw,channels=2,rate=48000 !  audioconvert ! avenc_aac ! rtpmp4apay name=pay1 pt=97 )"

Then stream can be playable with rtsp://SERVER_ADDRESS:8554/test