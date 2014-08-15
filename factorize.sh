#!/bin/bash

WINDOW=$1
CURVES=$2
COUNT=$3

echo 2 >> factorbase.$WINDOW
cat factorbase.* | sort | uniq | sort -n > tmp_factorbase.$WINDOW
mv tmp_factorbase.$WINDOW factorbase.$WINDOW

for i in $(seq 1 $COUNT) ; do
    echo "$(date) Starting loop $i for $WINDOW @ $CURVES"
    ./driver.pl --factorbase=factorbase.$WINDOW --curves=$CURVES --shuffle --prefilter --constant >> $WINDOW.out 2>> $WINDOW.err
    cat factorbase.* | sort | uniq | sort -n > tmp_factorbase.$WINDOW
    mv tmp_factorbase.$WINDOW factorbase.$WINDOW
done
