#!/usr/bin/env perl
use strict;

use Math::Prime::Util qw(is_prob_prime prime_certificate);
use bigint;
#use Math::BigFloat;
#use Math::BigInt upgrade => 'Math::BigFloat';

use feature 'say';

sub gcd {
    my ($a, $b) = @_;
    if ($a > $b) {
        ($a, $b) = ($b, $a);
    }
    my $i = 1;
    while ($a) {
        ($a, $b) = ($b % $a, $a);
        warn "loop $i";
        $i ++;
    }
    return $b;
}

my $huge_thing = 268096620753598537265152880052986931161;

say $huge_thing;

say prime_certificate($huge_thing);

say gcd($huge_thing, 27254281351928);
say gcd($huge_thing, 8675310);
say gcd($huge_thing, 8675309);
die "w00t";

for my $loop (4..9001) {
    my $i = Math::BigInt->new($loop);
    $i = $i->bpow(50);
    $i = $i + 7;
    if (is_prob_prime($i)) {
        say "Certificate for $i";
        say prime_certificate($i);
#    } else {
#        say "$i seems nonprime";
    }
}

=pod 
foreach line of prime factors
  confirm primality
    run mr test
    run prime test
    generate certificate
    alert if non-prime and add to work base
  add to prime base

foreach line of work
  divide against prime base for known factors
  if fully factored
    output full factorization
  quick primality check on remainder (few bases)
  else add remainder to work base
=cut

