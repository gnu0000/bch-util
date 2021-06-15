#!perl

use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::ArgParse;
use Gnu::StringUtil qw(Trim);

MAIN:
   $| = 1;

   ArgBuild("*^host= *^username= *^password= *^database= *^test *^livetest ^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Test() if ArgIs("test");;
   Usage() if ArgIs("help");
   ChangeEmails();
   exit(0);

sub ChangeEmails
   {
   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   my $data = FetchHash("id", "select id, mobilePhone from users");

   print "Live Tests:\n" if ArgIs("livetest");;

   foreach my $id (sort {$a<=>$b} keys %{$data})
      {
      my $oldNum = Trim($data->{$id}->{mobilePhone});
      my $newNum = ReformatNumber($oldNum);

      $oldNum ||= "[undef]" if ArgIs("livetest");
      $newNum ||= "[undef]" if ArgIs("livetest");

      next if $oldNum eq $newNum;
      print sprintf("  %-24s -> %s\n", $oldNum, $newNum) if ArgIs("livetest");
      ExecSQL("update users set mobilePhone=? where id=?", $newNum, $id) if !ArgIs("livetest"); 
      print "." if !ArgIs("livetest");
      }
   print "\nDone.\n";
   }

sub ReformatNumber
   {
   my ($oldNum) = @_;

   return $oldNum if !$oldNum;

   my ($cc, $num) = $oldNum =~ /^(\+\d)?(.*)$/;
   $cc ||= "+1";
   $num =~ s/\D//g;
   return undef if (length $num != 10);
   #my ($area, $prefix, $line) = $num =~ /(\d\d\d)(\d\d\d)(\d\d\d\d)/;
   #my $result = "$cc$area-$prefix-$line";
   my $result = "$cc$num";
   return $result;
   }

########################

sub Test
   {
   print "Static Tests:\n";

   _test("111-222-3333");
   _test("+1111-222-3333");
   _test("+8111-222-3333");
   _test("1112223333");
   _test("+11112223333");
   _test("(617) 232-1234");
   _test("+1 (617) 232-1234");
   _test("232-1234");
   _test("1112223333456");
   _test("+11112223333456");
   _test("111-222-3333-4444    ");
   _test("+1111-222-3333-4444    ");
   _test("111-222-3333 x555    ");
   _test("+1111-222-3333 x555    ");
   _test("111-222-3333 ext: 555");
   _test("+1111-222-3333 ext: 555");
   _test("111-222-3333 ex 555");
   _test("1112223333 x555");
   _test("+11112223333 x555");

   exit(0);
   }

sub _test
   {
   my ($oldNum) = @_;

   my $newNum  = ReformatNumber($oldNum);

   $oldNum ||= "[undef]";
   $newNum ||= "[undef]";

   my $changed = $oldNum eq $newNum ? "" : "(Changed!)";
   print sprintf("  %-24s -> %-24s %s\n", $oldNum, $newNum, $changed);
   }
