#!/bin/bash
export LC_ALL=C
apt-get update
apt-get dist-upgrade

#apt-get install liblist-moreutils-perl
apt-get install libmath-bigint-gmp-perl

curl -L http://cpanmin.us | perl - --self-upgrade
cpanm Data::Dumper Getopt::Long List::Util List::MoreUtils Math::BigInt::GMP Math::Prime::Util Math::Prime::Util::GMP
