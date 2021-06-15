#!perl
#
#
# this variant does not affect phone#s !!!!!
#
#
#
#
use warnings;
use strict;
use feature 'state';
use Gnu::TinyDB;
use Gnu::FileUtil qw(SlurpFile);

MAIN:
   AnonymizeUsers();
   exit(0);

sub AnonymizeUsers
   {
   Connection("onlineadvocate");
   my $data = FetchHash("id", "select id, email from users");
   foreach my $id (sort {$a<=>$b} keys %{$data})
      {
      next if $id == 24379 || $id == 1879; # skip me and pete

      my $first = GenFirstName($id);
      my $last  = GenLastName($id);
      my $email = "e" . $id . '@onlineadvocate.org';
      ExecSQL("update users set firstName=?, lastName=?, email=? where id=?", $first, $last, $email, $id);
      print ".";
      }
   }

sub GenFirstName
   {
   my ($idx) = @_;

   state $names = LoadNames("firstnames.dat");
   state $ct    = scalar @{$names};

   return "f" . $idx if !$ct;
   return Camelize($names->[int(rand($ct))]);
   }

sub GenLastName
   {
   my ($idx) = @_;

   state $names = LoadNames("lastnames.dat");
   state $ct    = scalar @{$names};

   return "l" . $idx if !$ct;
   return Camelize($names->[int(rand($ct))]);
   }

sub LoadNames
   {
   my ($filespec) = @_;

   my $data = SlurpFile($filespec);
   return [split(/\n/, $data)];
   }

sub Camelize 
   {
   my ($s) = @_;

   $s =~ s{(\w+)}{($a=lc $1)=~ s<(^[a-z]|_[a-z])><($b=uc $1)=~ s/^_//;$b;>eg;$a;}eg;
   $s;
   }
