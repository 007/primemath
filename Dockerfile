# factoring script docker file
# run a factorizer in a container!
FROM ubuntu:16.04
MAINTAINER Ryan Moore <ryan@geekportfolio.com>
# basic setup
RUN apt-get update && apt-get dist-upgrade -y
RUN apt-get install -y --no-install-recommends gmp-ecm libgmp-dev perl
# install build-essential, will remove later
RUN apt-get install -y --no-install-recommends curl gcc make libc-dev-bin libc6-dev
RUN curl -L http://cpanmin.us | perl - --self-upgrade
RUN cpanm \
  Data::Dumper \
  File::Slurp \
  Getopt::Long \
  List::Util \
  List::MoreUtils \
  Math::BigInt::GMP \
  Math::Prime::Util \
  Math::Prime::Util::GMP
RUN apt-get purge --autoremove -y curl gcc make libc-dev-bin libc6-dev
COPY * /var/primemath/
WORKDIR /var/primemath/
CMD [ "./driver.pl", "--curve=0"]
