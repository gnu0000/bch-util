#!perl
#
# CleanPhoneNumbers.pl
# This utility cleans up crappy phone #'s 
# 
# Craig Fitzgerald


use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::ArgParse;

MAIN:
   $| = 1;
   TestSplitNumber();

   ArgBuild("*^host= *^username= *^password= *^database= ^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help");
   CleanupPhoneNumbers();
   exit(0);

sub CleanupPhoneNumbers
   {
   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   my $data = FetchHash("id", "select id, homePhone, workPhone, mobilePhone from users");

   foreach my $id (sort {$a<=>$b} keys %{$data})
      {
      my $homePhone   = ReformatNumber($data->{$id}->{homePhone}  , 1);
      my $workPhone   = ReformatNumber($data->{$id}->{workPhone}  , 1);
      my $mobilePhone = ReformatNumber($data->{$id}->{mobilePhone}, 0);

      ExecSQL("update users set homePhone=?, workPhone=?, mobilePhone=? where id=?", $homePhone, $workPhone, $mobilePhone, $id);
      print ".";
      }
   print "\nDone.\n";
   }

sub ReformatNumber
   {
   my ($original, $isMobile) = @_;

   return undef if !$original;

   my ($num, $ext) = SplitNumber($original);
   return undef if $ext && !$isMobile;

   $num =~ s/\D//g;
   return undef if (length $num != 10);

   my ($area, $prefix, $line) = $num =~ /(\d\d\d)(\d\d\d)(\d\d\d\d)/;
   my $result = "$area-$prefix-$line";

   $result .= " x$ext" if ($ext);
   $result = "+1" . $result if ($isMobile);
   return $result;
   }


sub SplitNumber
   {
   my ($original) = @_;

   my ($a, $b) = $original =~ /^\s*(\d{3}-\d{3}-\d{4})-(\d+)\s*$/;
   return ($a, $b) if ($a && $b);

   ($a, undef, $b) = $original =~ /^\s*(\d{3}-?\d{3}-?\d{4})\s*,?(x|ex|ext)\s*[\.:]?\s*(\d+)\s*$/i;
   return ($a, $b) if ($a && $b);

   ($a, $b) = $original =~ /^\s*(\d{10})-?(\d+)\s*$/;
   return ($a, $b) if ($a && $b);

   ($a) = $original =~ /^\s*\+1(\d{3}-?\d{3}-?\d{4})\s*$/i;
   return ($a, undef) if ($a);

   return ($original, undef);
#   return ("", undef);
   }


########################

sub TestSplitNumber
   {
   my ($a, $b);

   _test("111-222-3333");
   _test("1112223333");
   _test("1112223333456");
   _test("111-222-3333-4444    ");
   _test("111-222-3333 x555    ");
   _test("111-222-3333 ext: 555");
   _test("111-222-3333 ex 555");
   _test("1112223333 x555");
   _test("+1111-222-3333");

   exit(0);
   }

sub _test
   {
   my ($num) = @_;

   my ($new) = ReformatNumber($num, 0);
   $new ||= "";
   print sprintf("normal: %-24s -> %s\n", $num, $new);

   ($new) = ReformatNumber($num, 1);
   $new ||= "";
   print sprintf("mobile: %-24s -> %s\n", $num, $new);
   }
