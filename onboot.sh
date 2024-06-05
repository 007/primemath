#!/bin/bash
set -x

# count of physical CPUs on either Linux or OSX
# kind of ridiculous
function ncpu {
    echo $(lscpu -p > /dev/null 2>&1 && echo $(( $(lscpu -p 2>/dev/null | grep -v ^# | cut -d\, -f1 | sort -rn | head -1) + 1)))$(sysctl -n hw.physicalcpu >/dev/null 2>&1 && echo $(sysctl -n hw.physicalcpu))
}

PATH=/usr/sbin:/bin:/usr/bin:/usr/local/bin

if [ -z "$1" ] ; then
    for i in `seq -f%03.0f $(ncpu)`; do
        # run self with parameter
        echo "screen -dmS prime_$i -t \"prime math worker $i\" $0 $i"
        screen -dmS prime_$i -t "prime math worker $i" $0 $i
        # wait a few seconds between starting runs
        sleep 600
    done
else
    WINDOW=$1
    CURVES=10-13
    TMPFACTORBASE="/tmp/tmp_factorbase.${WINDOW}.${RANDOM}"
    mkdir -p /var/primemath/log
    cd /var/primemath
    cp /var/primemath/factorbase.txt /var/primemath/factorbase.$WINDOW
    touch /var/primemath/factorbase.$WINDOW
    while [ true ] ; do
        echo "Starting process for window.$WINDOW" >> /var/primemath/log/factorlog.log
        /var/primemath/driver.pl --factorbase=/var/primemath/factorbase.$WINDOW --curves=$CURVES --shuffle --prefilter --constant >> /var/primemath/log/factorlog.log 2>>/var/primemath/log/factorlog.err
        cat /var/primemath/factorbase.* | sort | uniq | sort -n > "$TMPFACTORBASE" && \
        mv "$TMPFACTORBASE" /var/primemath/factorbase.$WINDOW
        sleep 3
    done
fi

