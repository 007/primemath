#!/bin/bash
export LC_ALL=C
apt-get update
apt-get dist-upgrade

if [ "$(md5sum gmp-6.0.0a.tar.bz2)" == "b7ff2d88cae7f8085bd5006096eed470  gmp-6.0.0a.tar.bz2" ] ; then
    echo "Using cached gmp"
else
    curl https://gmplib.org/download/gmp/gmp-6.0.0a.tar.bz2 > gmp-6.0.0a.tar.bz2
fi

if [ "$(md5sum ecm-6.4.4.tar.gz)" == "927712d698ae9e5de71574fb6ee2316c  ecm-6.4.4.tar.gz" ] ; then
    echo "Using cached ecm"
else
    curl https://gforge.inria.fr/frs/download.php/file/32159/ecm-6.4.4.tar.gz > ecm-6.4.4.tar.gz
fi

rm -rf gmp-6.0.0/
tar xjf gmp-6.0.0a.tar.bz2
pushd gmp-6.0.0/
./configure && make && make check && make install
popd

rm -rf ecm-6.4.4/
tar xzf ecm-6.4.4.tar.gz
pushd ecm-6.4.4/
./configure --enable-asm-redc --enable-openmp --with-gmp-lib=/usr/local/lib && make && make check && make install
popd

curl -L http://cpanmin.us | perl - --self-upgrade
LD_LIBRARY_PATH=/usr/local/lib cpanm Data::Dumper Getopt::Long List::Util List::MoreUtils Math::BigInt::GMP Math::Prime::Util Math::Prime::Util::GMP

mkdir -p /var/primemath/log

# make these hard links so that local updates will propagate
cp driver.pl /var/primemath/
cp worktodo.txt factorbase.txt sigmalog.txt /var/primemath/
cp onboot.sh /var/primemath/
(crontab -l | grep -v 'onboot /var/primemath/onboot.sh';echo "onboot /var/primemath/onboot.sh") | crontab -
(crontab -l | grep -v '/var/primemath/util.sh'; echo "0 * * * * /var/primemath/util.sh") | crontab -

