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

sub num_format {
    my ($num) = @_;

    # do this the regex way because Number::Format doesn't work on bigint
    my $alt = $num;
    $alt =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
    return $alt;
}

sub read_number_file {
    my ($filename) = @_;

    my @arr;

    open(my $fh, '<', $filename) or die "Could not open $filename: $!";
    while ( my $line = <$fh> ) {
        chomp $line;
        push @arr, Math::BigInt->new($line);
    }
    close $fh;

    return @arr;
}

sub write_number_file {
    my ($filename, @numbers) = @_;

    my $temp_filename = ".$filename.$$";
    progress("writing numbers to $temp_filename");
    open(my $fh, '>', $temp_filename) or die "Could not open $temp_filename: $!";
    for my $num (@numbers) {
        say $fh $num;
    }
    close $fh;
    rename $temp_filename, $filename;
    progress("Wrote " . scalar @numbers . " numbers to $filename");

    # force full sync after every file write
    # not good for short runs, but probably a good idea for long ones
    `sync`;
}

sub combine_factor_bases {
    my $glob_pattern = "factorbase.*";
    my @files = glob 'factorbase.*';
    my @base;

    for my $f (@files) {
        push @base, read_number_file($f);
    }
    @base = sort { $a <=> $b } uniq @base;
    progress("Loaded " . scalar @base . " numbers from factor bases");
    return @base;
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

    if ($factor) {
        $factor = Math::BigInt->new($factor);
    }
    if ($factor && $factor ne $num) {
        # get the last 3 matches out of the multiline match
        my ($b1, $b2, $sigma) = ($output =~ m/Using B1=(\d+), B2=(\d+), polynomial [^,]+, sigma=(\d+)/g)[-3..-1];
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

sub all_curves {
    my ($constant_time) = @_;

    # suggested limits and curve counts for different factor sizes.
    # Fields are:
    #   B1 limit
    #   number of curves to run at that B1
    #   # number of digits in factors (approximate)
    #   # amount of time to run (approximate)
    # default to suggested curves from Mersenne Wiki
    # but let us override to use constant-time if desired
    if ($constant_time) {
        # alternate curves - constant-time curves
        # each test loop will run in about 10 minutes
        # difficulty vs # of curves are scaled to match the timing
        # (first two curves are limited to 10x expected so they don't waste time)
        return {
                 2_000 => 250,    # 15 digits, 47.88 seconds / 1000 curves
                11_000 => 900,    # 20 digits, 21.69 seconds / 100 curves
                50_000 => 650,    # 25 digits, 92.18 seconds / 100 curves
               250_000 => 150,    # 30 digits, 420.63 seconds / 100 curves
             1_000_000 => 35,     # 35 digits, 176.87 seconds / 10 curves
             3_000_000 => 12,     # 40 digits, 493.00 seconds / 10 curves
            11_000_000 => 3,      # 45 digits, 884.48 seconds / 5 curves
            43_000_000 => 1,      # 50 digits, 677.13 seconds / 1 curve
        };
    } else {
        # values from:
        # http://www.mersennewiki.org/index.php/Elliptic_curve_method#Choosing_the_best_parameters_for_ECM
        return {
                 2_000 => 25,     # 15 digits, 1 second
                11_000 => 90,     # 20 digits, 30 seconds
                50_000 => 300,    # 25 digits, 5 minutes
               250_000 => 700,    # 30 digits, 15 minutes
             1_000_000 => 1_800,  # 35 digits, 3 hours
             3_000_000 => 5_100,  # 40 digits, 1 day
            11_000_000 => 10_600, # 45 digits, 1 week
            43_000_000 => 19_300, # 50 digits, 1 month
        };
    }
}

sub print_curve_list {
    my ($constant) = @_;

    my $curves = all_curves($constant);
    my $curve_set;
    if ($constant) {
        $curve_set = "constant-time";
    } else {
        $curve_set = "MersenneWiki recommended";
    }
    say "Listing for $curve_set curves:";
    my $count = 1;
    for my $key (sort { $a <=> $b } keys %$curves) {
        my $key_fmt = num_format($key);
        my $count_fmt = num_format($curves->{$key});
        say "  $count. B1 limit $key_fmt for $count_fmt curves";
        $count++;
    }
    say '';
}

sub setup_curves {
    my ($curve_str, $use_constant) = @_;
    my $retval;

    my $curves_to_use = all_curves($use_constant);

    my @curves;
    my @parts = split(',', $curve_str);
    for my $part (@parts) {
        if (my ($start, $end) = $part =~ m/^(\d)-(\d)$/) {
            # say "got range from $start to $end";
            push @curves, ($start .. $end);
        } else {
            # say "got 1 curve: $part";
            push @curves, $part;
        }
    }

    @curves = sort { $a <=> $b } uniq @curves;

    progress("Setting up for " . scalar @curves . " ECM curves");

    for my $curve (@curves) {
        # normalize curve count
        next if $curve < 1;
        next if $curve > scalar keys %$curves_to_use;

        # sort keys (B1 limits) of curves_to_use and limit
        # this isn't very efficient, sorting the keys every go-round
        # pick $curve - 1 to adjust for 0-index
        my $key = (sort { $a <=> $b } keys %$curves_to_use)[$curve - 1];
        my $b1 = num_format($key);
        progress("Picked curve $curve B1 $b1 for $curves_to_use->{$key} rounds");
        $retval->{$key} = $curves_to_use->{$key};
    }
    return $retval;
}

sub pre_filter {
    my $factor_base = shift;

    my @work_not_done;

    progress("Running pre-filter on " . scalar @_ . " numbers");
    while (my $work = shift) {
        my ($remainder, $factors) = match_factor_base($work, @$factor_base);
        if ($remainder != 1) {
            push @work_not_done, $work;
        }
    }
    progress("Filtered down to " . scalar @work_not_done . "numbers");

    return @work_not_done;
}

##### MAIN

$| = 1; # char flushing so that "..." progress works as intended

my (
    $curve_set,
    $curve_spec,
    $curves,
    @factor_base,
    $fb_filename,
    $help,
    $prefilter,
    $repeat,
    @work_todo,
    $shuffle,
);

GetOptions(
    "constant" => \$curve_set,
    "curves=s" => \$curve_spec,
    "factorbase=s" => \$fb_filename,
    "help"     => \$help,
    "prefilter" => \$prefilter,
    "repeat=i"  => \$repeat,
    "shuffle"  => \$shuffle,
    "thorough" => \$g_thorough,
);

# default filename
$fb_filename //= 'factorbase.txt';
$curve_spec //= '1-5';

$curves = setup_curves($curve_spec, $curve_set);

if ($repeat) {
    progress("Resetting curve counts to $repeat");
    for my $k (keys %$curves) {
        $curves->{$k} = $repeat;
    }
}

if ($help) {
    print_curve_list($curve_set);
    exit(0);
}

progress("Running precalc for primes");
# takes ~1.5 seconds and allocates ~32MB RAM
Math::Prime::Util::prime_precalc( 1_000_000_000 );

@factor_base = read_number_file($fb_filename);
@factor_base = prune_factor_base(@factor_base);

# write after pruning
write_number_file($fb_filename, @factor_base);

@work_todo = read_number_file('worktodo.txt');
# sort by default
@work_todo = sort { $a <=> $b } @work_todo;

# optional random ordering so we get middle factors after chugging on large ones
if ($shuffle) {
    @work_todo = shuffle @work_todo;
}

# remove completed numbers for more accurate work-remaining estimate
if ($prefilter) {
    @work_todo = pre_filter(\@factor_base, @work_todo);
}

while (my $current = shift @work_todo) {
    @factor_base = combine_factor_bases();
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

