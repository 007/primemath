#!/bin/bash

# part one - get a consolidated local copy of sigmalog and factorbase
cat /Users/ryan/working/prime/*.err | grep sigma | cut -d\  -f5- | grep -v 100000000000000000000000000000000000000000000000151 >> /Users/ryan/working/prime/sigmalog.txt
sort -nu -o /Users/ryan/working/prime/sigmalog.txt /Users/ryan/working/prime/sigmalog.txt
cat /Users/ryan/working/prime/factorbase.* | sort -nu > /Users/ryan/working/prime/.factorbase.txt
mv /Users/ryan/working/prime/.factorbase.txt /Users/ryan/working/prime/factorbase.txt

# part two - store instance copy on S3
INSTANCE_ID="maclocal"
aws s3 cp --storage-class REDUCED_REDUNDANCY /Users/ryan/working/prime/sigmalog.txt s3://primemath/sigmalog_${INSTANCE_ID}.txt
aws s3 cp --storage-class REDUCED_REDUNDANCY /Users/ryan/working/prime/factorbase.txt s3://primemath/factorbase_${INSTANCE_ID}.txt

# part three - consolidate the S3 version
mkdir -p /tmp/primemath.combine
aws s3 cp s3://primemath/ /tmp/primemath.combine/ --recursive --exclude "*" --include "factorbase_*.txt" --include "sigmalog_*.txt"

cat /tmp/primemath.combine/factorbase_*.txt /Users/ryan/working/prime/factorbase.txt | sort -nu > /Users/ryan/working/prime/.factorbase.txt
mv /Users/ryan/working/prime/.factorbase.txt /Users/ryan/working/prime/factorbase.txt

cat /tmp/primemath.combine/sigmalog_*.txt /Users/ryan/working/prime/sigmalog.txt | grep -v 100000000000000000000000000000000000000000000000151 | sort -nu > /Users/ryan/working/prime/.sigmalog.txt
mv /Users/ryan/working/prime/.sigmalog.txt /Users/ryan/working/prime/sigmalog.txt

rm -rf /tmp/primemath.combine.old && mv /tmp/primemath.combine /tmp/primemath.combine.old

