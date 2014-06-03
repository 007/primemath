#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Math::Prime::Util;
use bigint;
use feature 'say';

sub log_ts {
    my @t = localtime(time);
    return sprintf('[%04d-%02d-%02d:%02d:%02d:%02d] ', $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
}

sub progress {
    say STDERR log_ts(), @_;
}

sub success {
    say log_ts(), @_;
}

sub read_number_file {
    my ($filename) = @_;

    my @arr;

    progress("Reading numbers from $filename");
    open(my $fh, '<', $filename) or die "Could not open $filename: $!";
    while ( my $line = <$fh> ) {
        chomp $line;
        push @arr, Math::BigInt->new($line);
    }
    close $fh;
    progress("Loaded " . scalar @arr . " numbers from $filename");

    return @arr;
}

sub prune_factor_base {
    my @arr;
    progress("Pruning factor base");

    my $count = 0;
    while ( my $huge_thing = shift ) {
        # quick test
        if (Math::Prime::Util::is_prob_prime($huge_thing)) {
            # comprehensive test
            # easy to output certificate this way if desired
            my ($provable, $certificate) = Math::Prime::Util::is_provable_prime_with_cert($huge_thing);
            if ($provable == 2) {
                # say "$huge_thing is prime";
                # progress($certificate);
                push @arr, $huge_thing;
            } else {
                warn "*** PROB VS PROVABLE for $huge_thing";
            }
        } else {
            # TODO: add to work array?
            warn "$huge_thing is composite, dropping from factor base";
        }
        $count = $count + 1;
        if ($count % 100 == 0) {
            progress("Processed $count");
        }
    }

    progress("Pruned $count down to " . scalar @arr . " certified primes as current factor base");

    return @arr;
}


##### MAIN

$| = 1; # char flushing so that "..." progress works as intended

progress("Running precalc for primes");
# takes ~1.5 seconds and allocates ~32MB RAM
Math::Prime::Util::prime_precalc( 1_000_000_000 );

my @factor_base = read_number_file('factorbase.txt');
@factor_base = prune_factor_base(@factor_base);

my @work_todo = read_number_file('worktodo.txt');

while (my $current = shift @work_todo) {
    progress("Factoring $current (" . length($current) . " digits)");
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

