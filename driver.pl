#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use List::Util qw(shuffle);
use List::MoreUtils qw(uniq);
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

sub write_number_file {
    my ($filename, @numbers) = @_;

    progress("writing numbers to $filename");
    open(my $fh, '>', $filename) or die "Could not open $filename: $!";
    for my $num (@numbers) {
        say $fh $num;
    }
    close $fh;
    progress("Wrote " . scalar @numbers . " numbers to $filename");
}

my $g_thorough; # global for Getopt, defaults to off
sub prime_check {
    my ($num) = @_;

    if (Math::Prime::Util::is_prob_prime($num)) {
        if ($g_thorough) {
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
        } else {
            # less thorough
            if (Math::Prime::Util::is_prime($num)) {
                return 1;
            }
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
    @arr = sort {$a <=> $b} uniq @arr;
    return @arr;
}

# divide candidate by all (known prime) #s in factor base
# returns a remainder if not completely divisible, plus a hash of factors
# hash keys are factors, values are exponent (2^3 becomes { 2 => 3})
sub match_factor_base {
    my ($candidate, @tests) = @_;

    progress(scalar @tests . " factors in factor base");
    
    my $factors;
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
    return;
}

sub run_single_ecm {
    my ($num, $limit, $count) = @_;

    progress("Running \`echo $num | ecm -one -c $count $limit\`");
    my $output = `echo $num | ecm -one -c $count $limit`;
    my $factor = ($output =~ m/\*\*\*\*\*\*\*\*\*\* Factor found in step .: (\d+)/)[0];
    #progress("Output was '$output'");

    if ($factor) {
        $factor = Math::BigInt->new($factor);
    }
    if ($factor && $factor ne $num) {
        my ($b1, $b2, $sigma) = $output =~ m/Using B1=(\d+), B2=(\d+), polynomial [^,]+, sigma=(\d+)/;
        if ($sigma) {
            progress("Found ECM factor: $factor B1=$b1, B2=$b2, sigma=$sigma");
        } else {
            progress("Trouble with regex for ECM factor $factor (probably too small?)");
        }
        my @splits = ( $factor );
        return @splits;
    }
    return;
}

sub run_ecm {
    my ($num, $params) = @_;

    progress("Attempting ECM factorization for large number");
    for my $limit (sort { $a <=> $b } keys %$params) {
        my $count = $params->{$limit};
        my @factors = run_single_ecm($num, $limit, $count);
        return @factors if scalar @factors;
    }
    return;

}

sub setup_curves {
    my ($count) = @_;
    my $retval;
    # suggested limits and curve counts for different factor sizes.
    # Fields are:
    #   B1 limit
    #   number of curves to run at that B1
    #   number of digits in factors (approximate)
    #   amount of time to run (approximate)
    # values from:
    # http://www.mersennewiki.org/index.php/Elliptic_curve_method#Choosing_the_best_parameters_for_ECM
    my $known_good_curves = {
             2_000 => 25,     # 15 digits, 1 second
            11_000 => 90,     # 20 digits, 30 seconds
            50_000 => 300,    # 25 digits, 5 minutes
           250_000 => 700,    # 30 digits, 15 minutes
         1_000_000 => 1_800,  # 35 digits, 3 hours
         3_000_000 => 5_100,  # 40 digits, 1 day
        11_000_000 => 10_600, # 45 digits, 1 week
        43_000_000 => 19_300, # 50 digits, 1 month
    };


    # normalize curve count
    $count //= 5; # default value is all curve stuff 3 hours or less
    if ($count < 1) { $count = 1; }
    if ($count > scalar keys %$known_good_curves) { $count = scalar keys %$known_good_curves; }

    progress("Setting up for $count ECM curves");
    $count--; # adjust for 0-index
    # sort keys (B1 limits) of known_good_curves and limit
    for my $k ((sort { $a <=> $b } keys %$known_good_curves)[ 0 .. $count ]) {
        $retval->{$k} = $known_good_curves->{$k};
    }
    return $retval;
}

##### MAIN

$| = 1; # char flushing so that "..." progress works as intended

my ($curve_count, $curves, $fb_filename, @factor_base, @work_todo, $shuffle);

GetOptions(
    "curves=i" => \$curve_count,
    "factorbase=s" => \$fb_filename,
    "shuffle"  => \$shuffle,
    "thorough" => \$g_thorough,
);

# default filename
$fb_filename //= 'factorbase.txt';

$curves = setup_curves($curve_count);

progress("Running precalc for primes");
# takes ~1.5 seconds and allocates ~32MB RAM
Math::Prime::Util::prime_precalc( 1_000_000_000 );

@factor_base = read_number_file($fb_filename);
@factor_base = prune_factor_base(@factor_base);

@work_todo = read_number_file('worktodo.txt');
# sort by default
@work_todo = sort { $a <=> $b } @work_todo;

# optional random ordering so we get middle factors after chugging on large ones
if ($shuffle) {
    @work_todo = shuffle @work_todo;
}

while (my $current = shift @work_todo) {
    progress(scalar @work_todo . " items left in work queue");
    my $current_size = length($current);
    progress("Factoring $current ($current_size digits)");

    my ($remainder, $factors) = match_factor_base($current, @factor_base);

    # if we end up factoring completely
    if ($remainder == 1) {
        success("Complete factorization for $current ($current_size digits)");
        success(factor_string($factors));
    } else {
        # we got a remainder > 1 that wasn't factored
        my $remainder_size = length($remainder);
        if ($factors) {
            progress("Partial factorization for $current ($current_size digits):");
            progress(factor_string($factors) . " * $remainder*");
        } else {
            progress("No cached factors for $current ($current_size digits)");
        }
        if (prime_check($remainder)) {
            progress("Discovered new prime factor $remainder ($remainder_size digits)");
            push @factor_base, $remainder;
            @factor_base = sort {$a <=> $b} uniq @factor_base;
            unshift @work_todo, $current;
        } else {
            progress("Decided $remainder ($remainder_size digits) wasn't prime");
            my @new_factors;
            if ($remainder < 1_000_000_000_000_000) {
                progress("Attempting built-in factorization for small number");
                @new_factors = Math::Prime::Util::factor($remainder);
            } else {
                @new_factors = run_ecm($remainder, $curves);
            }
            if (scalar @new_factors) {
                # don't push this back onto the work queue until we can run enough ECM to get them done
                # unshift @work_todo, $current;
                unshift @work_todo, @new_factors;
            } else {
                progress("Dropping $remainder ($remainder_size digits) on the floor, too hard for now");
            }
        }
    }
    # write after every loop - better to get combined factors for parallel runs
    write_number_file($fb_filename, @factor_base);
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

