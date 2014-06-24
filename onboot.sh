#!/bin/bash

# count of physical CPUs on either Linux or OSX
# kind of ridiculous
function ncpu {
    echo $(lscpu -p > /dev/null 2>&1 && echo $(( $(lscpu -p 2>/dev/null | grep -v ^# | cut -d\, -f2 | sort -rn | head -1) + 1)))$(sysctl -n hw.physicalcpu >/dev/null 2>&1 && echo $(sysctl -n hw.physicalcpu))
}

PATH=/usr/sbin:/bin:/usr/bin

if [ -z "$1" ] ; then
    mkdir -p /var/log/primemath 2>/dev/null
    mkdir -p /var/primemath 2>/dev/null
    mkdir /usr/local/bin/primemath 2>/dev/null

    for i in `seq -f%03.0f $(ncpu)`; do
        # run self with parameter
        $0 $i
        # wait a few seconds between starting runs
        sleep 2
    done
    wait
else
    WINDOW=$1
    CURVES=4-8
    while [ true ] ; do
        echo "Starting process for window.$WINDOW"
        touch /var/primemath/factorbase.$WINDOW
        /usr/local/bin/primemath/driver.pl --factorbase=/var/primemath/factorbase.$WINDOW --curves=$CURVES --shuffle --prefilter --constant >> /var/log/primemath.log 2>>/var/log/primemath.err
        cat /var/primemath/factorbase.* | sort | uniq | sort -n > /tmp/tmp_factorbase.$WINDOW
        mv /var/primemath/.tmp_factorbase.$WINDOW /var/primemath/factorbase.$WINDOW
        sleep 3
    done
    echo "finished with $WINDOW"
    #while [ true ] ; do
    #    echo "$(date) Starting loop $i for $WINDOW" >> /var/log/primemath.log
    #    /usr/local/bin/primemath/driver.pl --factorbase=/var/log/factorbase.$WINDOW --curves=$CURVES --shuffle --prefilter --constant >> /var/log/primemath.out 2>>/var/log/primemath.log
    #    cat /var/primemath/factorbase.* | sort | uniq | sort -n > tmp_factorbase.$WINDOW
    #    mv tmp_factorbase.$WINDOW factorbase.$WINDOW
    #    sleep 60
    #done


fi

