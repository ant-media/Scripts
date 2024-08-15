#!/bin/bash
Server=$1
NoOfClients=$2

for (( i=1; i <= $NoOfClients; ++i ))
do
  COMMAND="ffmpeg -re -stream_loop -1 -i /Users/yashtandon/Downloads/Video/test.mp4 -codec copy -f flv ${Server}_${i}"
  $COMMAND >/dev/null 2>&1 &
  echo "running command $COMMAND"
  sleep 1
done
