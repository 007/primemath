# factoring script docker file
# run a factorizer in a container!
FROM ubuntu:16.04
MAINTAINER Ryan Moore <ryan@geekportfolio.com>
# basic setup
RUN apt-get update && apt-get dist-upgrade -y
RUN apt-get install -y curl awscli git gmp-ecm libgmp-dev screen
RUN apt-get autoremove -y && apt-get clean
# install build-essential, will remove later
RUN apt-get install -y build-essential
RUN curl -L http://cpanmin.us | perl - --self-upgrade && cpanm Data::Dumper File::Slurp Getopt::Long List::Util List::MoreUtils Math::BigInt::GMP Math::Prime::Util Math::Prime::Util::GMP
RUN apt-get purge -y build-essential
RUN apt-get autoremove -y && apt-get clean
RUN git clone https://github.com/007/primemath /var/primemath/
