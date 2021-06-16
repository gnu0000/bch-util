#!perl
#
# DumperDuplicates.pl
# This utility is for examining id's for a survey
#
# Craig Fitzgerald


use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::ArgParse;
use Gnu::Template qw(Template Usage);

my $COUNT     = 0;
my $DUP_COUNT = 0;
my $DIFF_CT   = 0;

MAIN:
   ArgBuild("*^all *^uifields *^questions *^responses *^records *^changedrecords *^host= *^username= *^password= ^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !scalar @ARGV;

   DumpDuplicateLangui       () if ArgIs("all") || ArgIs("uifields" );
   DumpDuplicateQuestionTexts() if ArgIs("all") || ArgIs("questions");
   DumpDuplicateResponseTexts() if ArgIs("all") || ArgIs("responses");
   exit(0);

##############################################################################

sub DumpDuplicateLangui
   {
   my $stats = {count=>0, dups=>0, diffs=>0};
   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   print "Scanning for duplicate langui records ...\n";
   my $languis = FetchArray("select * from langui");
   my %hold;
   foreach my $langui (@{$languis})
      {
      my $key = $langui->{uiId} . "_" . $langui->{langId};
      PrintDuplicateLangui ($hold{$key}, $langui, $stats) if exists $hold{$key};
      $hold{$key} = $langui unless exists $hold{$key};
      $stats->{count}++;
      }
   print "$stats->{count} Langui with $stats->{dups} duplicates (and $stats->{diffs} changed!)\n\n";
   }

sub PrintDuplicateLangui
   {
   my ($r1, $r2, $stats) = @_;

   my $changed = $r1->{value} ne $r2->{value};

   $stats->{dups}++;
   $stats->{diffs}++ if $changed;

   if (ArgIs("records") || ($changed && ArgIs("changedrecords")))
      {
      print "langui.id:$r1->{id} uiId:$r1->{uiId} langId:$r1->{langId} : value:$r1->{value}\n";
      print "langui.id:$r2->{id} uiId:$r2->{uiId} langId:$r2->{langId} : value:$r2->{value}\n";
      print "-" x 80 . "\n";
      }
   else
      {
      print "Duplicate langui entry for uifield $r1->{uiId} ($r1->{id} [$r1->{langId}] vs $r2->{id})\n";
      }
   }

##############################################################################

sub DumpDuplicateQuestionTexts
   {
   my $stats = {count=>0, dups=>0, diffs=>0};
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   print "Scanning for duplicate questiontext records ...\n";
   my $qts = FetchArray("select * from questiontext where current=1 order by id");
   my %hold;
   foreach my $qt (@{$qts})
      {
      my $key = $qt->{questionId} . "_" . $qt->{languageId};
      PrintDuplicateQuestionText($hold{$key}, $qt, $stats) if exists $hold{$key};
      $hold{$key} = $qt;
      $stats->{count}++;
      }
   print "$stats->{count} questiontexts with $stats->{dups} duplicates (and $stats->{diffs} changed!)\n\n";
   }

sub PrintDuplicateQuestionText
   {
   my ($r1, $r2, $stats) = @_;

   if (ArgIs("records"))
      {
      print "id:$r1->{id} questionId:$r1->{questionId} languageId:$r1->{languageId} text:$r1->{text}\n";
      print "id:$r2->{id} questionId:$r2->{questionId} languageId:$r2->{languageId} text:$r2->{text}\n";
      print "-" x 80 . "\n";
      }
   else
      {
      print "Duplicate questiontext entry for question $r1->{questionId} [$r1->{languageId}] ($r1->{id} vs $r2->{id})\n";
      }
   $stats->{dups}++;
   $stats->{diffs}++ unless $r1->{text} eq $r2->{text};
   }

##############################################################################

sub DumpDuplicateResponseTexts
   {
   my $stats = {count=>0, dups=>0, diffs=>0};
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   print "Scanning for duplicate responsetext records ...\n";
   my $qts = FetchArray("select * from responsetext where current=1 order by id");
   my %hold;
   foreach my $qt (@{$qts})
      {
      my $key = $qt->{responseId} . "_" . $qt->{languageId};
      PrintDuplicateResponseText($hold{$key}, $qt, $stats) if exists $hold{$key};
      $hold{$key} = $qt;
      $stats->{count}++;
      }
   print "$stats->{count} responsetexts with $stats->{dups} duplicates (and $stats->{diffs} changed!)\n\n";
   }

sub PrintDuplicateResponseText
   {
   my ($r1, $r2, $stats) = @_;

   if (ArgIs("records"))
      {
      print "id:$r1->{id} responseId:$r1->{responseId} languageId:$r1->{languageId} text:$r1->{text}\n";
      print "id:$r2->{id} responseId:$r2->{responseId} languageId:$r2->{languageId} text:$r2->{text}\n";
      print "-" x 80 . "\n";
      }
   else
      {
      }
   print "Duplicate responsetext entry for response $r1->{responseId} [$r1->{languageId}] ($r1->{id} vs $r2->{id})\n";
   #print "$r1->{id} : $r1->{responseId} : $r1->{languageId} : $r1->{text}\n";
   #print "$r2->{id} : $r2->{responseId} : $r2->{languageId} : $r2->{text}\n";
   $stats->{dups}++;
   $stats->{diffs}++ unless $r1->{text} eq $r2->{text};
   }

##############################################################################

__DATA__
[usage]
DumpDuplicates.pl  - Displays Duplicate uifield/question/response Text 

Usage: DumpDuplicates.pl  [options]

WHERE: [options] are one or more of:
   -all ............ Check all tables
   -uifields ....... Check for duplicate uifield/langui
   -questions ...... Check for duplicate questiontexts
   -responses ...... Check for duplicate responsetexts
   -records ........ Print out the matching records
   -host=foo ....... Set the mysqlhost (localhost)
   -username=foo ... Set the mysqlusername (avocate)
   -password=foo ... Set the mysqlpassword (****************)

EXAMPLES:
   DumpDuplicates.pl -all
   DumpDuplicates.pl -uifields
   DumpDuplicates.pl -all -username=bubba -pass=foo
