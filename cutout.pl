#!perl
my ($start, $end) = ($ARGV[0], $ARGV[1]);
for (my $i=1; my $line = <STDIN>; $i++) {
   print $line if $i >= $start && $i <= $end;;
}
