#!perl
#
# QuestionLinker.pl  - Utility to build links to the old web translator.
# See the help at the bottom of this file
#
#
use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);

MAIN:
   ArgBuild("*^host= *^username= *^password= ^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs();

   MakeLinks();
   exit(0);


sub MakeLinks
   {
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   my $filename = ArgGet();
   open (my $file, "<", $filename) or die "Cannot open $filename";
   
   while (my $line = <$file>)
      {
      my ($id,$msg) = $line =~ /^\s*(\d+)\s*(.*)$/;
      MakeLink({id=>$id, msg=>$msg||""});
      }
   close $file;
   }


sub MakeLink
   {
   my ($question) = @_;

   $question->{moduleid} = ModuleIDFromQuestionID($question->{id});
#  print Template("link"   , %{$question}) if $question->{moduleid};
#  print Template("unknown", %{$question}) if !$question->{moduleid};
   print Template("link2"   , %{$question}) if $question->{moduleid};
   print Template("unknown2", %{$question}) if !$question->{moduleid};
   }


sub ModuleIDFromQuestionID
   {
   my ($questionid) = @_;

   my $rec = FetchRow("select * from flow where targetQuestionId=$questionid");
   return $rec->{moduleId} if $rec;

   $rec = FetchRow("select * from logicEvaluations where targetQuestionId=$questionid");
   return $rec->{moduleId} if $rec;
   
   $rec = FetchRow("select * from logicDefaultTargets where targetQuestionId=$questionid");
   return $rec->{moduleId} if $rec;
   
   $rec = FetchRow("select * from modules where firstQuestionId=$questionid");
   return $rec->{id} if $rec;

   return 0;
   }


__DATA__
[link]
<a href="https://translate.trivoxhealth.com/sysadmin/translate.html?type=QUESTION&mid=$moduleid&study=1&from=eng&to=spa">$id</a> $msg
[unknown]
$id $msg
[link2]
$id : $msg
https://translate.trivoxhealth.com/sysadmin/translate.html?type=QUESTION&mid=$moduleid&study=1&from=eng&to=spa

[unknown2]
$id : $msg

[usage]
QuestionLinker.pl  - Utility to build links to the old web translator.

USAGE: QuestionLinker.pl [options] QuestionFile

WHERE: [options] is zero or more of:
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)

   QuestionFile is a text file that must contain a questionid and
    an optional message on each line.

NOTES:
   When the RAs scan the questiontext and spot a potential problem, they add
   to a problem document the question id and a description of what went wrong.

   This program takes that data, determines which module the question belongs to,
   and constructs a link to the old translation editor for each question

EXAMPLE cmdline:
   QuestionLinker.pl ProblemQuestions.txt

EXAMPLE ProblemQuestions.txt:
   11    Incomplete/missing/suspected incorrect
   930   Incomplete/missing/suspected incorrect
   2486  Incomplete/missing/suspected incorrect
   1221  Incomplete
   5290  Translation
   5694  Need green ‘support email’ in spanish version
