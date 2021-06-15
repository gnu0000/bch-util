#!perl
#
# UifieldMissing.pl 
#
# This utility is for examining Uifield/langui text
#
# This utility is usefull for determining what foreign fields are missing
#
# This utility can generate html as well as text.  This can be usefull for
#  detecting broken tags, as all following html will likely be screwed up.
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
use warnings;
use strict;
use feature 'state';
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil qw(DumpHash);

my $STATS = {};

MAIN:
   $| = 1;
   ArgBuild("*^idsonly *^html *^language= *^host= *^username= *^password= *^help *^debug");

   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs("language");

   Language(ArgGet("language"));

   PrintUIFieldsIDs() if ArgIs("idsonly");
   PrintUIFields   ();
   exit(0);


sub PrintUIFields
   {
   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   my $lang     = Language();
   my $uifields = FetchHash("id"              , "select * from uifields");
   my $languis  = FetchHash(["uiId", "langId"], "select * from langui");

   print DataTemplate("start");

   foreach my $uiid (sort{$a<=>$b} keys %{$uifields})
      {
      my $uifield = $uifields->{$uiid};
      my $langui  = $languis->{$uiid} || {};

      IncStat("count");
      next if NoEnglish ($langui);
      next if HasForeign($langui, $lang);
      IncStat("missing");

      print DataTemplate("entry", %{$langui->{1804}});
      }
   print DataTemplate("end");
   print DataTemplate("stats", %{$STATS});
   }


sub NoEnglish
   {
   my ($rec) = @_;

   return 0 if $rec->{1804};
   IncStat("noenglish");
   return 1;
   }

sub HasForeign
   {
   my ($rec, $langid) = @_;

   #DumpHash("rec", $rec);
   return 0 unless $rec->{$langid};
   IncStat("hasforeign");
   return 1;
   }

sub Language
   {
   my ($id) = @_;

   state $lang = undef;
   return $lang unless $id;
   $lang = $id;
   return $lang;
   }

sub IncStat
   {
   my ($name) = @_;
   $STATS->{$name} = 0 unless exists $STATS->{$name};
   $STATS->{$name}++;
   }

sub GetStat
   {
   my ($name) = @_;
   return $STATS->{$name} || 0 ;
   }

sub DataTemplate
   {
   my ($name, %params) = @_;

   my $suffix = ArgIs("idsonly") ? "idsonly":
                ArgIs("html")    ? "html"   :
                                   "text"   ;
   my $tname = $name . "_" . $suffix;
   return Template ($tname, %params);
   }

#############################################################################
#                                                                           #
#############################################################################

__DATA__
[start_idsonly]
[entry_idsonly]
$uiId
[stats_idsonly]
[end_idsonly]

[start_text]
Missing fields
[entry_text]
(uiId:$uiId, id:$id)
$value
-----------------------------------------------------------------
[stats_text]
Stats:
   count     : $count
   missing   : $missing
   noenglish : $noenglish
   hasforeign: $hasforeign
[end_text]

[start_html]
<!DOCTYPE html>
<html>
   <head>
      <style>
      .uifield {
         position: relative;
         border: 2px solid #888; 
         margin: 4px; 
         padding: 5px;
         border-radius: 5px;
      }
      </style>
   </head>
   <body>
   <h3>Missing fields</h3>
[entry_html]
         <div class="uifield">$value</div>
[stats_html]
[end_html]
      <div>($count records)</div>
   </body>
</html>
[usage]
UifieldMissing.pl - Utility for displaying TriVox uifield info

USAGE: UifieldMissing.pl [options]

WHERE: [options] is one or more of:
    -language=9999 . Specify language id to scan for
    -idsonly ....... Only print uifield ids
    -html .......... Generate html (default is text)
    -host=foo ...... Set the mysqlhost (localhost)
    -username=foo .. Set the mysqlusername (avocate)
    -password=foo .. Set the mysqlpassword (****************)
EXAMPLES: 
    UifieldView.pl -lang=portuguese
    UifieldView.pl -lang=portuguese -html
    UifieldView.pl -host=trivox-db.cymcwhoejtz8.us-east-1.rds.amazonaws.com -all
    UifieldView.pl -language=spanish -idsonly

NOTES:
    -language can be set to:
       spanish or 5912 for Spanish
       portuguese or 5265 for Portuguese
[fini]
