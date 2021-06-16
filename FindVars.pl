#!perl
#
# FindVars.pl
# Find <variables> in questiontext and responsetext fields
#
# Craig Fitzgerald


use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

my $VISITED = {};

my $VAR_COUNT = 0;

MAIN:
   $| = 1;
   ArgBuild("*^uifields *^questions *^responses *^text *^host= *^username= *^password= *^database= ^help ^debug");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   #Usage() if ArgIs("help") || !ArgIs();

   my $all = !(ArgIs("uifields") || ArgIs("questions") || ArgIs("responses"));
   my $match = ArgGet();

   FindLangui($match)       if ArgIs("uifields" ) || $all;
   FindQuestionText($match) if ArgIs("questions") || $all;
   FindResponseText($match) if ArgIs("responses") || $all;

   print "\n($VAR_COUNT total vars found)\n";
   exit(0);


sub FindLangui
   {
   my ($match) = @_;

   Connection("onlineadvocate", ArgsGet("host", "username", "password"));
   my $rows = FetchArray("select * from langui");
   foreach my $row (@{$rows})
      {
      my $vars = VarStrings($row->{value});
      next unless $vars;
      print "LANGUI: id=$row->{id}, uiId=$row->{uiId}, langId=$row->{langId}\n$vars\n\n";
      }
   print "(" . scalar @{$rows} . " langui rows)\n";
   }

sub FindQuestionText
   {
   my ($match) = @_;

   Connection("questionnaires", ArgsGet("host", "username", "password"));
   my $rows = FetchArray("select * from questiontext");
   foreach my $row (@{$rows})
      {
      my $vars = VarStrings($row->{text});
      next unless $vars;
      print "QUESTIONTEXT: id=$row->{id}, questionId=$row->{questionId}, languageId=$row->{languageId}\n$vars\n\n";
      }
   print "(" . scalar @{$rows} . " questiontext rows)\n";
   }

sub FindResponseText
   {
   my ($match) = @_;

   Connection("questionnaires", ArgsGet("host", "username", "password"));
   my $rows = FetchArray("select * from responsetext");
   foreach my $row (@{$rows})
      {
      my $vars = VarStrings($row->{text});
      next unless $vars;
      print "RESPONSETEXT: id=$row->{id}, responseId=$row->{responseId}, languageId=$row->{languageId}\n$vars\n\n";
      }
   print "(" . scalar @{$rows} . " responsetext rows)\n";
   }



sub VarStrings
   {
   my ($text) = @_;

   my @vars = ($text =~ /(\<var.*?\<\/var\>)/gis);

   $VAR_COUNT += scalar @vars;

   return join ("\n", @vars);
   }


#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]
FindVars.pl  - Find <variables> in questiontext and responsetext fields

USAGE: FindVars.pl [options] "text"

WHERE: [options] are one or more of:
   -uifields .......... Only look at uifeld text
   -questions ......... Only look at question text
   -responses ......... Only look at response text
   -text .............. Print out the text
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)

EXAMPLES:
   FindText.pl "first grade"
   FindText.pl -uifields "email"
   FindText.pl -questions -responses "swimming"
   
