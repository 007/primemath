#!/usr/bin/env perl
use strict;
use warnings;

use Math::Prime::Util;
use bigint;
use feature 'say';

sub prune_factor_base {
    my ($filename) = @_;

    my @arr;

    print STDERR "Loading factor base $filename\n";
    open(my $fh, '<', $filename) or die "Could not open $filename: $!";

    while ( my $line = <$fh> ) {
        print STDERR '.'; # progress
        chomp $line;
        my $huge_thing = Math::BigInt->new($line);
        # quick test
        if (Math::Prime::Util::is_prob_prime($huge_thing)) {
            # comprehensive test
            # easy to output certificate this way if desired
            my ($provable, $certificate) = Math::Prime::Util::is_provable_prime_with_cert($huge_thing);
            if ($provable == 2) {
                # say "$huge_thing is prime";
                # print STDERR $certificate;
                push @arr, $huge_thing;
            } else {
                warn "*** PROB VS PROVABLE for $huge_thing";
            }
        } else {
            # TODO: add to work array?
            warn "$huge_thing is composite, dropping from factor base";
        }
    }
    print STDERR " done\n";
    close $fh;

    print STDERR "Loaded " . scalar @arr . " primes as current factor base\n";

    return @arr;
}


##### MAIN

$| = 1; # char flushing so that "..." progress works as intended

print STDERR "Running precalc for primes... ";
# takes ~1.5 seconds and allocates ~32MB RAM
Math::Prime::Util::prime_precalc( 1_000_000_000 );
print STDERR " done\n";

my @factor_base = prune_factor_base('factorbase.txt');

Math::Prime::Util::prime_memfree();

=pod 

foreach line of work
  divide against prime base for known factors
  if fully factored
    output full factorization
  quick primality check on remainder (few bases)
  else add remainder to work base
=cut

