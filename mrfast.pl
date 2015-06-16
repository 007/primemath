#!/usr/bin/env perl
use strict;
use bigint;
use feature 'say';

use Math::BigInt try => 'GMP';
use Math::Prime::Util;
use Data::Dumper;

my $base = $ARGV[0] // 3;
while (my $line = <STDIN> ) {
    $line =~ s/(\r|\n)//g;
    if (Math::Prime::Util::is_strong_pseudoprime($line, $base)) {
        say "$line,$base";
    }
}

