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

sub prime_check {
    my ($num) = @_;

    if (Math::Prime::Util::is_prob_prime($num)) {
        # comprehensive test
        # easy to output certificate this way if desired
        my ($provable, $certificate) = Math::Prime::Util::is_provable_prime_with_cert($num);
        if ($provable == 2) {
            # say "$num is prime";
            # progress($certificate);
            return 1;
        } else {
            warn "*** PROB VS PROVABLE for $num";
        }
    }
    return 0;
}

sub prune_factor_base {
    my @arr;
    progress("Pruning factor base");

    my $count = 0;
    while ( my $huge_thing = shift ) {
        # quick test
        if (prime_check($huge_thing)) {
            push @arr, $huge_thing;
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

    # sort output ascending
    @arr = sort {$a <=> $b} @arr;
    return @arr;
}

# divide candidate by all (known prime) #s in factor base
# returns a remainder if not completely divisible, plus a hash of factors
# hash keys are factors, values are exponent (2^3 becomes { 2 => 3})
sub match_factor_base {
    my ($candidate, @tests) = @_;

    my $factors = {};
    for my $k (@tests) {
        if ($candidate % $k == 0) {
            $factors->{$k} = 0;
            while ($candidate % $k == 0) {
                $factors->{$k} ++;
                $candidate = $candidate / $k;
                last if $candidate == 1;
            }
        }
        last if $candidate == 1;
    }
    return ($candidate, $factors);
}

sub factor_string {
    my ($factors) = @_;

    if ($factors) {
        my @strings;
        for my $k (sort { $a <=> $b } keys %$factors) {
            if ($factors->{$k} == 1) {
                push @strings, "$k";
            } else {
                push @strings, "$k ^ $factors->{$k}";
            }
        }
        return join(' * ', @strings);
    }
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
    my $current_size = length($current);
    progress("Factoring $current ($current_size digits)");

    my ($remainder, $factors) = match_factor_base($current, @factor_base);

    # if we end up factoring completely
    if ($remainder == 1) {
        success("Complete factorization for $current ($current_size digits)");
        success(factor_string($factors));
    } else {
        # we got a remainder > 1 that wasn't factored
        if ($factors) {
            progress("Partial factorization for $current ($current_size digits):");
            progress(factor_string($factors) . " * $remainder*");
        } else {
            progress("No cached factors for $current ($current_size digits)");
        }
        if (prime_check($remainder)) {
            progress("Discovered new prime factor $remainder");
            push @factor_base, $remainder;
            @factor_base = sort {$a <=> $b} @factor_base;
            # push original back onto work list to be run again
            unshift @work_todo, $current;
        }
    }
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

