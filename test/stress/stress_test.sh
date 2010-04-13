#!/bin/bash
GENTLE=1
export GENTLE
for((i=0;i<500;i++))
do
  j=`expr $i + 1`
  perl replay.pl $j > /dev/null 2>&1 &
done
read
PIDS=`ps aux | grep "replay\.pl" | awk '{print $2}'`
for pid in $PIDS
do
  kill $pid
done
