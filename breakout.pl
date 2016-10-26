use File::Slurp;
use feature 'say';
$| = 1; # char flushing so that "..." progress works as intended

# set file limit - using the full million will generate a 465GB file!
my $limit = $ARGV[0] // 1000;
my $offset = $ARGV[1] // 1;

my $pi = File::Slurp::read_file('million_pi.txt');

$offset = $offset - 1;
$limit = $limit + $offset;

if ($limit > length($pi)) {
  $limit = length($pi);
}

$pi = substr($pi, 0, $limit);

for (my $index = length($pi); $index > $offset; $index--) {
  print STDERR $index, "\r";
  say $pi;
  chop($pi);
}
