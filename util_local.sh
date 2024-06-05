#!/bin/bash

# part one - get a consolidated local copy of sigmalog and factorbase
cat log/*.err | grep sigma | cut -d\  -f5- | grep -v 100000000000000000000000000000000000000000000000151 >> sigmalog.txt
sort -nu sigmalog.txt -o sigmalog.txt
cat factorbase.* | sort -nu > .factorbase.txt
mv .factorbase.txt factorbase.txt

sort -nu complete.txt -o complete.txt
