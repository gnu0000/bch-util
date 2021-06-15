#!perl

use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);

MAIN:
   $|=1;
   ChangeEmails();
   exit(0);

sub ChangeEmails
   {
   Connection("onlineadvocate");

   my $data = FetchHash("id", "select id, email from users");

   foreach my $id (sort {$a<=>$b} keys %{$data})
      {
      #my $user = $data->{$id};
      #my $first = "f" . $id;
      #my $last  = "l" . $id;
      #my $email = "e" . $id . '@onlineadvocate.org';
      #ExecSQL("update users set firstName=?, lastName=?, email=?, okToEmail=0 where id=?", $first, $last, $email, $id);


      my $email = "e" . $id . '@mailinator.com';
      ExecSQL("update users set email=?, mobilePhone=null where id=?", $email, $id);
      print ".";
      }
   }

