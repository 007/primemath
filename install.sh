#!/bin/bash
# Install primemath factoring driver from scratch
# instructions:
#   apt-get update && apt-get install -y git
#   git clone git@github.com:007/primemath.git
#   cd primemath
#   sudo ./install.sh

export LC_ALL=C

if [[ $EUID -ne 0 ]]; then
   echo "Must run as root" 1>&2
   exit 100
fi

apt-get update
apt-get dist-upgrade
apt-get install -y build-essential m4

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
cp driver.pl /var/primemath/
cp worktodo.txt factorbase.txt sigmalog.txt /var/primemath/
cp onboot.sh util.sh /var/primemath/

# update crontab, making sure we have a crontab entry to begin with and filtering out $self
(crontab -l >/dev/null 2>&1 && (crontab -l | grep -v 'reboot /var/primemath/onboot.sh';echo "@reboot /var/primemath/onboot.sh") || echo "@reboot /var/primemath/onboot.sh") | crontab -
(crontab -l | grep -v '/var/primemath/util.sh'; echo "0 * * * * /var/primemath/util.sh") | crontab -

