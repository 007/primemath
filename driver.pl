#!/usr/bin/env perl
use strict;
use warnings;

use Math::Prime::Util;
use bigint;
use feature 'say';

sub read_number_file {
    my ($filename) = @_;

    my @arr;

    print STDERR "Reading numbers from $filename\n";
    open(my $fh, '<', $filename) or die "Could not open $filename: $!";
    while ( my $line = <$fh> ) {
        chomp $line;
        push @arr, Math::BigInt->new($line);
    }
    close $fh;
    print STDERR "Loaded " . scalar @arr . " numbers from $filename\n";

    return @arr;
}

sub prune_factor_base {
    my @arr;
    print STDERR "Pruning factor base";

    while ( my $huge_thing = shift ) {
        print STDERR '.'; # progress
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

    print STDERR "Pruned down to " . scalar @arr . " certified primes as current factor base\n";

    return @arr;
}


##### MAIN

$| = 1; # char flushing so that "..." progress works as intended

print STDERR "Running precalc for primes... ";
# takes ~1.5 seconds and allocates ~32MB RAM
Math::Prime::Util::prime_precalc( 1_000_000_000 );
print STDERR " done\n";

my @factor_base = read_number_file('factorbase.txt');
@factor_base = prune_factor_base(@factor_base);

my @work_todo = read_number_file('worktodo.txt');

while (my $current = shift @work_todo) {
    print STDERR "Factoring $current (" . length($current) . " digits)\n";
}


Math::Prime::Util::prime_memfree();

=pod 

foreach line of work
  divide against prime base for known factors
  if fully factored
    output full factorization
  quick primality check on remainder (few bases)
  else add remainder to work base
=cut

