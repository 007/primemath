#!/bin/bash

# part one - get a consolidated local copy of sigmalog and factorbase
cat /var/primemath/log/factorlog.err | grep sigma | cut -d\  -f5- >> /var/primemath/sigmalog.txt
sort -nu -o /var/primemath/sigmalog.txt /var/primemath/sigmalog.txt
cat /var/primemath/factorbase.* | sort -nu > /var/primemath/.factorbase.txt
mv /var/primemath/.factorbase.txt /var/primemath/factorbase.txt

# part two - store instance copy on S3
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws s3 cp --storage-class REDUCED_REDUNDANCY /var/primemath/sigmalog.txt s3://primemath/sigmalog_${INSTANCE_ID}.txt
aws s3 cp --storage-class REDUCED_REDUNDANCY /var/primemath/factorbase.txt s3://primemath/factorbase_${INSTANCE_ID}.txt

# part three - consolidate the S3 version
mkdir -p /tmp/primemath.combine
aws s3 cp s3://primemath/ /tmp/primemath.combine/ --recursive --exclude "*" --include "factorbase_*.txt" --include "sigmalog_*.txt"

cat /tmp/primemath.combine/factorbase_*.txt /var/primemath/factorbase.txt | sort -nu > /var/primemath/.factorbase.txt
mv /var/primemath/.factorbase.txt /var/primemath/factorbase.txt

cat /tmp/primemath.combine/sigmalog_*.txt /var/primemath/sigmalog.txt | sort -nu > /var/primemath/.sigmalog.txt
mv /var/primemath/.sigmalog.txt /var/primemath/sigmalog.txt

rm -rf /tmp/primemath.combine.old && mv /tmp/primemath.combine /tmp/primemath.combine.old

