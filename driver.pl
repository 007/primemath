#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Digest::MD5;
use File::Slurp;
use File::Spec;
use Getopt::Long;
use List::Util qw(shuffle);
use List::MoreUtils qw(uniq);
use Math::Prime::Util;
use POSIX qw(ceil);

use bigint;
use feature 'say';

# color table
my (
    $FG_BLACK,     $BG_BLACK,     $FG_DARKGREY,      $BG_DARKGREY,
    $FG_RED,       $BG_RED,       $FG_BRIGHTRED,     $BG_BRIGHTRED,
    $FG_GREEN,     $BG_GREEN,     $FG_BRIGHTGREEN,   $BG_BRIGHTGREEN,
    $FG_YELLOW,    $BG_YELLOW,    $FG_BRIGHTYELLOW,  $BG_BRIGHTYELLOW,
    $FG_BLUE,      $BG_BLUE,      $FG_BRIGHTBLUE,    $BG_BRIGHTBLUE,
    $FG_MAGENTA,   $BG_MAGENTA,   $FG_BRIGHTMAGENTA, $BG_BRIGHTMAGENTA,
    $FG_CYAN,      $BG_CYAN,      $FG_BRIGHTCYAN,    $BG_BRIGHTCYAN,
    $FG_LIGHTGREY, $BG_LIGHTGREY, $FG_WHITE,         $BG_WHITE,

    $COLOR_RESET,
) = ('') x 33; # 33 empty string arrays, aka 33 empty strings in a single list


sub log_ts {
    my @t = localtime(time);
    return sprintf('[%04d-%02d-%02d:%02d:%02d:%02d] ', $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
}

sub progress {
    say STDERR $FG_DARKGREY, log_ts(), $COLOR_RESET, $FG_LIGHTGREY, @_, $COLOR_RESET;
}

sub success {
    say $FG_DARKGREY, log_ts(), $COLOR_RESET, $FG_WHITE, @_, $COLOR_RESET;
}

sub complete {
    my $fn = 'complete.txt';
    open(my $fh, '>>', $fn) or die "Could not open $fn for append: $!";
    say $fh @_;
    close $fh;
    success(@_);
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

    my $temp_filename = "$filename.$$";
    progress("writing numbers to $temp_filename");
    open(my $fh, '>', $temp_filename) or die "Could not open $temp_filename: $!";
    for my $num (@numbers) {
        say $fh $num;
    }
    close $fh;
    rename $temp_filename, $filename;
    progress("Wrote $FG_BRIGHTYELLOW" . scalar @numbers . "$FG_LIGHTGREY numbers to $filename");

    # force full sync after every file write
    # not good for short runs, but probably a good idea for long ones
    `sync`;
}

sub prime_to_certname {
    my ($prime) = @_;

    my $hash = Digest::MD5::md5_hex("$prime");
    my @d = (
        'certificates',
        substr($hash, 0, 1),
        substr($hash, 1, 1),
        $hash . '.primecert'
    );

    return File::Spec->catfile(@d);
}

sub read_prime_certificate {
    my ($prime) = @_;
    my $prime_fn = prime_to_certname($prime);
    if (-e $prime_fn) {
        progress("Reading prime certificate for $prime");
        my $cert = File::Slurp::read_file($prime_fn);
        return $cert;
    }
    return;
}

sub write_prime_certificate {
    my ($prime, $cert) = @_;

    my $prime_fn = prime_to_certname($prime);
    if (! -e $prime_fn) {
        progress("Writing prime certificate for $prime");
        open(my $fh, '>', $prime_fn) or die "Could not open file '$prime_fn' $!";
        print $fh $cert;
        close $fh;
    }
}

sub combine_factor_bases {
    my $glob_pattern = "factorbase.*";
    my @files = glob 'factorbase.*';
    my @base;

    for my $f (@files) {
        push @base, read_number_file($f);
    }
    @base = sort { $a <=> $b } uniq @base;
    progress("Loaded $FG_BRIGHTYELLOW" . scalar @base . "$FG_LIGHTGREY numbers from factor bases");
    return @base;
}

my $g_thorough; # global for Getopt, defaults to off
sub prime_check {
    my ($num) = @_;

    if (Math::Prime::Util::is_prob_prime($num)) {
        if ($g_thorough) {
            # comprehensive test
            my ($provable, $certificate);
            $certificate = read_prime_certificate($num);
            if ($certificate) {
                if (Math::Prime::Util::verify_prime($certificate)) {
                    return 1;
                } else {
                    progress("Error with prime cert, deleting to recalculate");
                    # TODO: unlink after testing
                }
            }
            # easy to output certificate this way if desired
            ($provable, $certificate) = Math::Prime::Util::is_provable_prime_with_cert($num);
            if ($provable == 2) {
                # say "$num is prime";
                write_prime_certificate($num, $certificate);
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
    my ($factors, $factoree) = @_;

    if ($factors) {
        my @strings;
        for my $k (sort { $a <=> $b } keys %$factors) {
            if ($factors->{$k} == 1) {
                push @strings, "$k";
            } else {
                push @strings, "$k ^ $factors->{$k}";
            }
        }
        return "${factoree} = " . join(' * ', @strings);
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
        # everything breaks down when single-curve runtime goes > 10 minutes
        # (first few curves are limited to 2x expected so they don't waste time)

        return {
                 2_000 => 50,      # 01 - 15 digits, ~0.02 seconds / curve
                11_000 => 180,     # 02 - 20 digits, ~0.10 seconds / curve
                50_000 => 600,     # 03 - 25 digits, ~0.50 seconds / curve
               250_000 => 290,     # 04 - 30 digits, ~2 seconds / curve
             1_000_000 => 70,      # 05 - 35 digits, ~8 seconds / curve
             3_000_000 => 25,      # 06 - 40 digits, ~24 seconds / curve
            11_000_000 => 7,       # 07 - 45 digits, ~80 seconds / curve
            43_000_000 => 1,       # 08 - 50 digits, ~5 minutes / curve
           110_000_000 => 1,       # 09 - 55 digits, ~15 minutes / curve
           260_000_000 => 1,       # 10 - 60 digits, ~30 minutes / curve
           850_000_000 => 1,       # 11 - 65 digits, ~90 minutes / curve
         2_900_000_000 => 1,       # 12 - 70 digits, ~5 hours / curve
         7_600_000_000 => 1,       # 13 - 75 digits, ~14 hours / curve
        25_000_000_000 => 1,       # 14 - 80 digits, ~35 hours / curve
        };
    } else {
        # values from:
        # https://web.archive.org/web/20180824215902/https://www.mersennewiki.org/index.php/Elliptic_curve_method#Choosing_the_best_parameters_for_ECM
        return {
                 2_000 => 25,      # 01 - 15 digits, 1 second
                11_000 => 90,      # 02 - 20 digits, 30 seconds
                50_000 => 300,     # 03 - 25 digits, 5 minutes
               250_000 => 700,     # 04 - 30 digits, 15 minutes
             1_000_000 => 1_800,   # 05 - 35 digits, 3 hours
             3_000_000 => 5_100,   # 06 - 40 digits, 1 day
            11_000_000 => 10_600,  # 07 - 45 digits, 1 week
            43_000_000 => 19_300,  # 08 - 50 digits, 1 month
           110_000_000 => 49_000,  # 09 - 55 digits, 5 months
           260_000_000 => 124_000, # 10 - 60 digits, 2 years
           850_000_000 => 210_000, # 11 - 65 digits, 10 years
         2_900_000_000 => 340_000, # 12 - 70 digits, 50 years
         7_600_000_000 => 565_000, # 13 - 75 digits, 300 years
        25_000_000_000 => 800_000, # 14 - 80 digits, 2000 years
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
    my $curve_digits = 15;
    for my $key (sort { $a <=> $b } keys %$curves) {
        my $key_fmt = num_format($key);
        my $count_fmt = num_format($curves->{$key});
        say "  $count. B1 limit $key_fmt for $count_fmt curves ($curve_digits digits)";
        $count++;
        $curve_digits += 5;
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
        if (my ($start, $end) = $part =~ m/^(\d+)-(\d+)$/) {
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
            print STDERR $FG_RED, '+';
            push @work_not_done, $work;
        } else {
            print STDERR $FG_GREEN, '-';
        }
    }
    say '';
    progress("Filtered down to " . scalar @work_not_done . " numbers");

    @work_not_done = sort { $a <=> $b } @work_not_done;
    write_number_file('worktodo.txt', @work_not_done);
    exit(0);
}

##### MAIN

$| = 1; # char flushing so that "..." progress works as intended

my (
    $check_only,
    $curve_set,
    $curve_spec,
    $curves,
    @factor_base,
    $fb_filename,
    $help,
    $parallel,
    $prefilter,
    $repeat,
    @work_todo,
    $shuffle,
    $use_color,
);

GetOptions(
    "check"    => \$check_only,
    "color"    => \$use_color,
    "constant" => \$curve_set,
    "curves=s" => \$curve_spec,
    "factorbase=s" => \$fb_filename,
    "help"     => \$help,
    "parallel=i"  => \$parallel,
    "prefilter" => \$prefilter,
    "repeat=i"  => \$repeat,
    "shuffle"  => \$shuffle,
    "thorough" => \$g_thorough,
);

if ($use_color) {
    $FG_BLACK = "\x1b[38;5;0m";            $BG_BLACK = "\x1b[48;5;0m";
    $FG_RED = "\x1b[38;5;1m";              $BG_RED = "\x1b[48;5;1m";
    $FG_GREEN = "\x1b[38;5;2m";            $BG_GREEN = "\x1b[48;5;2m";
    $FG_YELLOW = "\x1b[38;5;3m";           $BG_YELLOW = "\x1b[48;5;3m";
    $FG_BLUE = "\x1b[38;5;4m";             $BG_BLUE = "\x1b[48;5;4m";
    $FG_MAGENTA = "\x1b[38;5;5m";          $BG_MAGENTA = "\x1b[48;5;5m";
    $FG_CYAN = "\x1b[38;5;6m";             $BG_CYAN = "\x1b[48;5;6m";
    $FG_LIGHTGREY = "\x1b[38;5;7m";        $BG_LIGHTGREY = "\x1b[48;5;7m";
    $FG_DARKGREY = "\x1b[1;38;5;8m";       $BG_DARKGREY = "\x1b[1;48;5;8m";
    $FG_BRIGHTRED = "\x1b[1;38;5;9m";      $BG_BRIGHTRED = "\x1b[1;48;5;9m";
    $FG_BRIGHTGREEN = "\x1b[1;38;5;10m";   $BG_BRIGHTGREEN = "\x1b[1;48;5;10m";
    $FG_BRIGHTYELLOW = "\x1b[1;38;5;11m";  $BG_BRIGHTYELLOW = "\x1b[1;48;5;11m";
    $FG_BRIGHTBLUE = "\x1b[1;38;5;12m";    $BG_BRIGHTBLUE = "\x1b[1;48;5;12m";
    $FG_BRIGHTMAGENTA = "\x1b[1;38;5;13m"; $BG_BRIGHTMAGENTA = "\x1b[1;48;5;13m";
    $FG_BRIGHTCYAN = "\x1b[1;38;5;14m";    $BG_BRIGHTCYAN = "\x1b[1;48;5;14m";
    $FG_WHITE = "\x1b[1;38;5;15m";         $BG_WHITE = "\x1b[1;48;5;15m";

    $COLOR_RESET = "\x1b[0m";
}

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

if ($parallel) {
    progress("Resetting curve counts to 1 / $parallel");
    for my $k (keys %$curves) {
        my $orig = $curves->{$k};
        $curves->{$k} = ceil($orig / $parallel);
        progress("Set curve B1=$k B1 from $orig to $curves->{$k} rounds");
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

if ($check_only) {
    @work_todo = ()
} else {
    @work_todo = read_number_file('worktodo.txt');
}

# remove completed numbers for more accurate work-remaining estimate
if ($prefilter) {
    pre_filter(\@factor_base, @work_todo);
}

# optional random ordering so we get middle factors after chugging on large ones
if ($shuffle) {
    @work_todo = shuffle @work_todo;
} else {
    # reverse sort (biggest num to smallest) if not shuffled
    @work_todo = sort { $b <=> $a } @work_todo;
}

while (my $current = shift @work_todo) {
    @factor_base = combine_factor_bases();
    progress($FG_BRIGHTBLUE, scalar @work_todo . " items left in work queue");
    my $current_size = length($current);
    progress("Factoring $current (${FG_BRIGHTGREEN}$current_size${FG_LIGHTGREY} digits)");

    my ($remainder, $factors) = match_factor_base($current, @factor_base);

    # if we end up factoring completely
    if ($remainder == 1) {
        success("Complete factorization for $current ($current_size digits)");
        complete(factor_string($factors, $current));
    } else {
        # we got a remainder > 1 that wasn't factored
        my $remainder_size = length($remainder);
        if ($factors) {
            progress("Partial factorization for $current ($current_size digits):");
            progress(factor_string($factors, $current) . " * $remainder*");
        } else {
            progress("No cached factors for $current ($current_size digits)");
        }
        if (prime_check($remainder)) {
            progress("${FG_WHITE}${BG_GREEN}Discovered new prime factor $remainder ($remainder_size digits)");
            push @factor_base, $remainder;
            @factor_base = sort {$a <=> $b} uniq @factor_base;
            write_number_file($fb_filename, @factor_base);
            unshift @work_todo, $current;
        } else {
            progress("Decided $remainder (${FG_BRIGHTGREEN}$remainder_size${FG_LIGHTGREY} digits) wasn't prime");
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
                progress("${FG_RED}Dropping $remainder ($remainder_size digits) on the floor, too hard for now");
            }
        }
    }
}

# write out combined base at the end, even if we didn't find any new factors
write_number_file($fb_filename, @factor_base);

Math::Prime::Util::prime_memfree();

