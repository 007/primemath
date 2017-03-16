#!/bin/bash
FACTORPATH="$(readlink -f $(dirname $0))"
MAXCOUNT=4
for i in $(seq ${MAXCOUNT}); do
    #./factorize.sh WiNDOW_PREFIX WHICH_CURVES REPEAT_COUNT PARALLELISM
    screen -dmS prime_00$i -t "primemath worker $i" ${FACTORPATH}/factorize.sh 00$i 6 8 ${MAXCOUNT}
    sleep 135 # time to complete 1 iteration / (number of workers plus 1)
    # if it takes 300 seconds for one iteration and you have 4 workers, 300 / (4 + 1) = 60s sleep
    # need the workers + 1 because first worker starts at time = 0
done
