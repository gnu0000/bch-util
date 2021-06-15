#!perl
#
# CompareUIFields.pl
#
# This utility is for examining the uifields and langui from 2 different databases
#

use warnings;
use strict;
use Gnu::SimpleDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

MAIN:
   ArgBuild("*^doit *^host= *^username= *^password= ^help ^debug ^debug2");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   #Usage() if ArgIs("help") || !scalar @ARGV;
   CompareUIFields();
   exit(0);

sub CompareUIFields
   {
   my $db1 = Connect(    "onlineadvocate", ArgsGet("host", "username", "password")); # 
   my $db2 = Connect("dev_onlineadvocate", ArgsGet("host", "username", "password")); # 

   my $local_uis = FetchHash($db1, "id", "select * from uifields");
   my $iciss_uis = FetchHash($db2, "id", "select * from uifields");

   my $local_les = FetchHash($db1, "uiId", "select * from langui where langId=1804");
   my $local_lss = FetchHash($db1, "uiId", "select * from langui where langId=5912");
   my $iciss_les = FetchHash($db2, "uiId", "select * from langui where langId=1804");
   my $iciss_lss = FetchHash($db2, "uiId", "select * from langui where langId=5912");

   foreach my $id (sort {$a<=>$b} keys %{$local_uis})
      {
      my $local_ui = $local_uis->{$id};
      my $iciss_ui = $iciss_uis->{$id};

      if (!$iciss_ui)
         {
         print "UIField $id does not exist on iciss ($local_ui->{itemName})\n";
         next;
         }
      if ($local_ui->{itemName} ne $iciss_ui->{itemName})
         {                        
         print "UIField $id differs:\n";
         print "local: $local_ui->{itemName}\n";
         print "iciss: $iciss_ui->{itemName}\n";
         next;
         }

      my $local_le = $local_les->{$id};
      my $local_ls = $local_lss->{$id};
      my $iciss_le = $iciss_les->{$id};
      my $iciss_ls = $iciss_lss->{$id};

      # if no english text, skip it
      next unless exists $local_le->{value};

      if ($local_le->{value} ne $iciss_le->{value})
         {
         print "=" x 80 . "\n";
         print "English langui changed for uifield $id:\n";
         print "iciss: $iciss_le->{value}\n";
         print "-" x 80 . "\n";
         print "local: $local_le->{value}\n";
         print "=" x 80 . "\n";
         }

      next unless exists $local_ls->{value};

      if (exists $local_ls->{value} && !exists $iciss_ls->{value})
         {
         print "Spanish langui only exists locally for uifield $id:\n";
         next;
         }

      if ($local_ls->{value} ne $iciss_ls->{value})
         {
         print "=" x 80 . "\n";
         print "Spanish langui changed for uifield $id:\n";
         print "iciss: $iciss_ls->{value}\n";
         print "-" x 80 . "\n";
         print "local: $local_ls->{value}\n";
         print "=" x 80 . "\n";
         }
      }
   }


__DATA__

[usage]

todo ..............

