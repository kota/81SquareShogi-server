#!/bin/sh
PIDS=`ps aux | grep "replay\.pl" | awk '{print $2}'`
for pid in $PIDS
do
  kill $pid
done
