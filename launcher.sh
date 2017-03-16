#!/bin/bash
cd /var/primemath

for i in 1 2 3 4 5 6; do
    screen -dmS prime_00$i -t "primemath worker $i" ./factorize.sh 00$i 5-8 1
    sleep 135 # time to complete 1 iteration / (number of workers plus 1)
    # if it takes 300 seconds for one iteration and you have 4 workers, 300 / (4 + 1) = 60s sleep
    # need the workers + 1 because first worker starts at time = 0
done
