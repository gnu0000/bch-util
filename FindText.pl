#!perl
#
# FindText.pl
# Utility to find and dump Trivox Text Fields
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

MAIN:
   $| = 1;
   ArgBuild("*^uifields *^questions *^responses *^text *^host= *^username= *^password= *^database= ^help ^debug");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs();

   my $all = !(ArgIs("uifields") || ArgIs("questions") || ArgIs("responses"));
   my $match = ArgGet();

   FindLangui($match)       if ArgIs("uifields" ) || $all;
   FindQuestionText($match) if ArgIs("questions") || $all;
   FindResponseText($match) if ArgIs("responses") || $all;
   exit(0);


sub FindLangui
   {
   my ($match) = @_;

   Connection("onlineadvocate", ArgsGet("host", "username", "password"));
   my $rows = FetchArray("select * from langui where value like '%$match%'");
   foreach my $row (@{$rows})
      {
      print "LANGUI: id=$row->{id}, uiId=$row->{uiId}, langId=$row->{langId}\n";
      print "value=$row->{value}\n\n" if ArgIs("text");
      }
   print "(" . scalar @{$rows} . " langui rows)\n";
   }

sub FindQuestionText
   {
   my ($match) = @_;

   Connection("questionnaires", ArgsGet("host", "username", "password"));
   my $rows = FetchArray("select * from questiontext where text like '%$match%'");
   foreach my $row (@{$rows})
      {
      print "QUESTIONTEXT: id=$row->{id}, questionId=$row->{questionId}, languageId=$row->{languageId}\n";
      print "text=$row->{text}\n\n" if ArgIs("text");
      }
   print "(" . scalar @{$rows} . " questiontext rows)\n";
   }

sub FindResponseText
   {
   my ($match) = @_;

   Connection("questionnaires", ArgsGet("host", "username", "password"));
   my $rows = FetchArray("select * from responsetext where text like '%$match%'");
   foreach my $row (@{$rows})
      {
      print "RESPONSETEXT: id=$row->{id}, responseId=$row->{responseId}, languageId=$row->{languageId}\n";
      print "text=$row->{text}\n\n" if ArgIs("text");
      }
   print "(" . scalar @{$rows} . " responsetext rows)\n";
   }


#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]
FindText.pl  - Utility to find and dump Trivox Text Fields

USAGE: FindText.pl [options] "text"

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
   
