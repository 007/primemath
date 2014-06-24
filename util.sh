#!/bin/bash

cat /var/primemath/log/factorlog.log | grep sigma | cut -d\  -f5- >> /var/primemath/sigmalog.txt
sort -nu -o /var/primemath/sigmalog.txt /var/primemath/sigmalog.txt
cat /var/primemath/factorbase.* | sort -nu > /var/primemath/factorbase.txt
