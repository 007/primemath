#!/bin/bash

FACTORPATH="$(readlink -f $(dirname $0))"

cd ${FACTORPATH}
WINDOW=$1
CURVES=$2
COUNT=$3
PARALLEL=$4

echo 2 >> factorbase.$WINDOW
cat factorbase.* | sort | uniq | sort -n > tmp_factorbase.$WINDOW
mv tmp_factorbase.$WINDOW factorbase.$WINDOW

echo "$(date) Starting loop $i for $WINDOW @ $CURVES"
./driver.pl --factorbase=factorbase.$WINDOW --curves=$CURVES --repeat=$COUNT --shuffle --parallel=$PARALLEL --color >> $WINDOW.out 2>> $WINDOW.err
cat factorbase.* | sort | uniq | sort -n > tmp_factorbase.$WINDOW
mv tmp_factorbase.$WINDOW factorbase.$WINDOW
