#!/bin/bash

m3u8_url=$1
viewers=$2

for (( i=1; i <= $viewers; ++i ))
do
    COMMAND="ffmpeg -i "$m3u8_url" -codec copy -f null /dev/null"
    $COMMAND &>>/dev/null &
    echo "running command $COMMAND"
    sleep 0.5
done
