#!perl
use warnings;
use strict;
use Gnu::FileUtil qw(SlurpFile);

MAIN:
   run("c:/util/mariadb/logs/old/pn.log");
   exit(0);

sub run
   {
   my ($filespec) = @_;

   open (my $filehandle, "<", $filespec) or die "cant open $filespec";

   my $ct = 0;
   while (my $line = <$filehandle>)
      {
      chomp($line);
      next unless $line;
      my $id = substr($line, 68);
      print "$id\n";
      $ct++;
      }
   #print "$ct lines";
   }
