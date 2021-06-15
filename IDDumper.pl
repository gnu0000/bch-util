#!perl
#
# IDDumper.pl
#
# This utility is for examining id's for a survey
#

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
   ArgBuild("*^setid= *^moduleid= *^questionid= *^host= *^username= *^password= *^database= *^noresponses *^skipcalcs ^help ^debug ^debug2");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !scalar @ARGV;

   DumpSetIDs   (ArgGet("setid"   )) if ArgIs("setid"   );
   DumpModuleIDs(ArgGet("moduleid")) if ArgIs("moduleid");
   exit(0);


sub DumpSetIDs
   {
   my ($setid) = @_;

   my $dbname = ArgGet("database") || "questionnaires";
   Connection($dbname, ArgsGet("host", "username", "password"));
   my $set = FetchRow("select * from sets where id=$setid");

   print "Dumping ID's associated with set $set->{name} from db $dbname\n";
   print "setid: $setid\n";

   DumpModuleChain($setid, $set->{firstModuleId});
   }


sub DumpModuleIDs
   {
   my ($moduleid) = @_;

   my $dbname = ArgGet("database") || "questionnaires";
   Connection($dbname, ArgsGet("host", "username", "password"));
   my $module = FetchRow("select * from modules where id=$moduleid");

   print "Dumping ID's associated with module $module->{name} from db $dbname\n";
   print "moduleid: $moduleid\n";

   DumpQuestionChain(-1, $moduleid, $module->{firstQuestionId});
   }


sub DumpModuleChain
   {
   my ($setid, $moduleid) = @_;

   my $module = FetchRow("select * from modules where id=$moduleid");
   return unless $module;

   print "   moduleid: $moduleid\n";
   DumpQuestionChain($setid, $moduleid, $module->{firstQuestionId});

   my $sfdt = FetchRow("select * from setflowdefaulttargets where setid=$setid and moduleid=$moduleid");
   DumpModuleChain($setid, $sfdt->{targetModuleId}) if $sfdt;
   
   my $sfe = FetchRow("select * from setflowevaluations where setid=$setid and moduleid=$moduleid");
   DumpModuleChain($setid, $sfe->{targetModuleId}) if $sfe;
   }


sub DumpQuestionChain
   {
   my ($setid, $moduleid, $questionid) = @_;

   return unless defined $questionid;
   my $question = FetchRow("select * from questions where id=$questionid");

   return unless $question;

   return if $VISITED->{$questionid};
   $VISITED->{$questionid} = 1;

   my $iscalc = $question->{qtype} =~ /(logic)|(calculation)|(evaluation)/i;

   my $qtrms = FetchArray("select * from questiontoresponsemap where questionid=$questionid order by responseNumber");

   if (!$iscalc || !ArgIs("skipcalcs"))
      {
      print "      questionid: $questionid";
      print " [$question->{qtype}]"  if ArgIs("debug");
      print "\n";

      foreach my $qtrm (@{$qtrms})
         {
         next unless defined $qtrm->{responseId};
         my $response = FetchRow("select * from responses where id=$qtrm->{responseId}");
         print "         responseid: $response->{id}\n" unless ArgIs("noresponses");
         }
      }

   # first, we'll follow questions from the responses
   #
   my %nextQuestionIds = ();
   foreach my $qtrm (@{$qtrms})
      {
      my $flow = FetchRow("select * from flow where questionToResponseMapId=$qtrm->{id} and moduleId=$moduleid order by id");
      $nextQuestionIds{$flow->{targetQuestionId}} = 1 if $flow;
      }

   foreach my $tqid (sort keys %nextQuestionIds)
      {
      print "Dumping questions from flow...\n" if ArgIs("debug");
      DumpQuestionChain($setid, $moduleid, $tqid);
      }

   # then we'll follow questions from any logic evals
   #
   my $logicevaluations = FetchArray("select * from logicevaluations where questionId=$questionid and moduleId=$moduleid order by id");
   foreach my $logicevaluation (@{$logicevaluations})
      {
      print "Dumping questions from logicevaluations for questionid $questionid...\n" if ArgIs("debug");
      DumpQuestionChain($setid, $moduleid, $logicevaluation->{targetQuestionId});
      }

   # then we'll follow questions from any logic defaults
   #
   my $logicdefaulttargets = FetchArray("select * from logicdefaulttargets where questionId=$questionid and moduleId=$moduleid order by id");
   foreach my $logicdefaulttargets (@{$logicdefaulttargets})
      {
      print "Dumping questions from logicdefaulttargets for questionid $questionid...\n" if ArgIs("debug");
      DumpQuestionChain($setid, $moduleid, $logicdefaulttargets->{targetQuestionId});
      }

   # finally, we follow child questions
   #
   my $kids = FetchArray ("select * from questionchildren where parentQuestionId=$questionid order by id");
   foreach my $kid (@{$kids})
      {
      print "Dumping questions from childquestion (parentid is $questionid...\n" if ArgIs("debug");
      DumpQuestionChain($setid, $moduleid, $kid->{childQuestionId});
      }
   }

#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]
IDDumper.pl  - Utility to dump Trivox Set or Module IDs

USAGE: IDDumper.pl [options]

WHERE: [options] are one or more of:
   -setid=## .......... Dump this set
   -moduleid=## ....... Dump this module
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -database=name ..... optionally provide the db name (questionnaires)
   -noresponses ....... dont print response records
   -skipcalcs ......... dont print questions that are calcs

EXAMPLES:
   IDDumper.pl -set=1
   IDDumper.pl -mod=34
