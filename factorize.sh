#!/bin/bash

for i in `cat ~/pi_fact.txt | grep -v ' ='`; do
    echo "working on pi around `echo $i | wc -c` digits"
    echo $i > factorize.txt
    ecm -q -inp factorize.txt -c 25 2000 >> factorize.log
    ecm -q -inp factorize.txt -c 300 50000 >> factorize.log
    ecm -q -inp factorize.txt -c 1675 1000000 >> factorize.log
    ecm -q -inp factorize.txt -c 2000  1000000 >> factorize.log

    cat factorize.log | tr ' ' '\n' | sort -n | uniq
done

