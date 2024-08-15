#!/bin/bash
file=$1
server=$2
noofclients=$3

for (( i=1; i <= $noofclients; ++i ))
do
  COMMAND="ffmpeg -re -stream_loop -1 -i ${file} -codec copy -f flv ${server}_${i}"
  $COMMAND >/dev/null 2>&1 &
  echo "running command $COMMAND"
  sleep 1
done
