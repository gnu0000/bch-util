#!perl
#
# FixRebel.pl
# Change the drive letters in rebel.xml files to work with the current environment
#
use warnings;
use strict;

my @FILES = (
   '\Projects\TV\helpsteps-build\rebel.xml'                     ,
   '\Projects\TV\iciss-core\src\main\resources\rebel.xml'       ,
   '\Projects\TV\iciss-web\src\main\resources\rebel.xml'        ,
   '\Projects\TV\smart-oauth2\src\main\resources\rebel.xml'     ,
   '\Projects\TV\toa-core\src\main\resources\rebel.xml'         ,
   '\Projects\TV\toa-db-criteria\src\main\resources\rebel.xml'  ,
   '\Projects\TV\toa-test-artifact\src\main\resources\rebel.xml',
   '\Projects\TV\toa-web\src\main\resources\rebel.xml');

MAIN:
   map {Fix($_)} @FILES;
   exit(0);

sub Fix
   {
   my ($inspec) = @_;
   my $outspec = $inspec . ".out";
   my ($drive) = $0 =~ /^(\w)\:/;

   open (my $infile,  "<", $inspec ) or die "cant open '$inspec'";
   open (my $outfile, ">", $outspec) or die "cant open '$outspec'";
   while (my $line = <$infile>)
      {
      $line =~ s/([c|d])(:[\/|\\]projects)/$drive$2/i;
      print $outfile $line;
      }
   close $infile;
   close $outfile;
   unlink($inspec) or die "cant delete '$inspec'";
   rename($outspec, $inspec) or die "cant rename '$outspec' to '$inspec'";
   print "Updated '$inspec'\n";
   }