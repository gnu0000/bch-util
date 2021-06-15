#!perl
#
# GenerateModuleIndicies.pl
#
# This utility is for examining id's for a survey
#
#
# This module set comes from the original translation doc:
#

use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

MAIN:
   ArgBuild("*^moduleid= *^root= *^host= *^username= *^password= ^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs("moduleid");

   GenerateIndicies();
   exit(0);


sub GenerateIndicies
   {
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   if (ArgGet("moduleid") =~ /all/i)
      {
      my $modules = FetchArray("select * from modules");
      map{GenerateModuleIndex($_)} @{$modules};
      }
   else
      {
      my $moduleid = ArgGet("moduleid");
      my $module = FetchRow("select * from modules where id=$moduleid");
      GenerateModuleIndex($module);
      }
   }


sub GenerateModuleIndex
   {
   my ($module) = @_;

   return unless $module;

   $module->{_questionids}              = {};
   $module->{_questionids_missing_5912} = {};
   $module->{_questionids_missing_5265} = {};
   $module->{_responseids}              = {};
   $module->{_responseids_missing_5912} = {};
   $module->{_responseids_missing_5265} = {};
   $module->{_question_visited}         = {};

   FollowQuestionChain ($module, $module->{firstQuestionId});

   Gen("question_" .$module->{id}. ".txt"             , $module->{_questionids}             );
   Gen("question_" .$module->{id}. "_missing_5912.txt", $module->{_questionids_missing_5912});
   Gen("question_" .$module->{id}. "_missing_5265.txt", $module->{_questionids_missing_5265});

   Gen("response_" .$module->{id}. ".txt"             , $module->{_responseids}             );
   Gen("response_" .$module->{id}. "_missing_5912.txt", $module->{_responseids_missing_5912});
   Gen("response_" .$module->{id}. "_missing_5265.txt", $module->{_responseids_missing_5265});
   }

sub Gen
   {
   my ($filename, $hashref) = @_;

   return unless scalar keys %{$hashref};
   
   $filename = ArgGet("root") . "\\" . $filename if (ArgIs("root"));

   print "Generating $filename\n";
   open (my $file, ">", $filename);
   map {print $file "$_\n"} sort {$a<=>$b} keys %{$hashref};
   close $file;
   }


sub FollowQuestionChain
   {
   my ($module, $questionid) = @_;

   return unless $module;
   return unless $questionid;

   return if $module->{_question_visited}->{$questionid};
   $module->{_question_visited}->{$questionid} = 1;

   my $moduleid = $module->{id};

   my $question = FetchRow("select * from questions where id=$questionid");
   return unless $question;
   
   CheckQuestionText($module, $question);

   my $qtrms = FetchArray("select * from questiontoresponsemap where questionid=$questionid order by responseNumber");

   foreach my $qtrm (@{$qtrms})
      {
      next unless defined $qtrm->{responseId};

      my $response = FetchRow("select * from responses where id=$qtrm->{responseId}");
      CheckResponseText($module, $question, $response);
      }

   # first, we'll follow questions from the responses
   my %nextQuestionIds = ();
   foreach my $qtrm (@{$qtrms})
      {
      my $flow = FetchRow("select * from flow where questionToResponseMapId=$qtrm->{id} and moduleId=$moduleid");
      $nextQuestionIds{$flow->{targetQuestionId}} = 1 if $flow;
      }
   foreach my $tqid (sort keys %nextQuestionIds)
      {
      FollowQuestionChain($module, $tqid);
      }

   # then we'll follow questions from any logic
   my $logicevaluation = FetchRow("select * from logicevaluations where questionId=$questionid and moduleId=$moduleid");
   FollowQuestionChain($module, $logicevaluation->{targetQuestionId}) if $logicevaluation;

   # then we'll follow questions from any logic defaults
   #
   my $logicdefaulttargets = FetchRow("select * from logicdefaulttargets where questionId=$questionid and moduleId=$moduleid");
   FollowQuestionChain($module, $logicdefaulttargets->{targetQuestionId}) if $logicdefaulttargets;

   # finally, we follow child questions
   my $kids = FetchArray ("select * from questionchildren where parentQuestionId=$questionid");
   foreach my $kid (@{$kids})
      {
      FollowQuestionChain($module, $kid->{childQuestionId});
      }
   }


sub CheckQuestionText
   {
   my ($module, $question) = @_;

   return unless $question;
   return if $question->{qtype} =~ /(logic)|(calculation)|(evaluation)/i;

   my $qid  = $question->{id};
   my $qt_e = FetchRow("select * from questiontext where questionId=$qid and languageId=1804 and current=1");
   my $qt_s = FetchRow("select * from questiontext where questionId=$qid and languageId=5912 and current=1");
   my $qt_p = FetchRow("select * from questiontext where questionId=$qid and languageId=5265 and current=1");

   # check: if no english text, its probably not supposed to
   return unless $qt_e;

   $module->{_questionids}->{$qid} = 1;
   $module->{_questionids_missing_5912}->{$qid} = 1 unless $qt_s && Trim($qt_s->{text});
   $module->{_questionids_missing_5265}->{$qid} = 1 unless $qt_p && Trim($qt_p->{text});
   }

sub CheckResponseText
   {
   my ($module, $question, $response) = @_;

   return unless $response;

   my $rid    = $response->{id};
   my $rt_e = FetchRow("select * from responsetext where responseId=$rid and languageId=1804 and current=1");
   my $rt_s = FetchRow("select * from responsetext where responseId=$rid and languageId=5912 and current=1");
   my $rt_p = FetchRow("select * from responsetext where responseId=$rid and languageId=5265 and current=1");

   $module->{_responseids}->{$rid} = 1;
   $module->{_responseids_missing_5912}->{$rid} = 1 unless $rt_s && Trim($rt_s->{text});
   $module->{_responseids_missing_5265}->{$rid} = 1 unless $rt_p && Trim($rt_p->{text});
   }

#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]
GenerateTrivoxTextIndicies.pl  - Generate item indexes for the web based editor

Usage: GenerateTrivoxTextIndicies.pl  [options]

WHERE: [options] are one or more of:
   -moduleid=(##|all) . Choose module to scan (or all)
   -root=name ......... Set root for outfiles
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)

EXAMPLES:
   GenerateTrivoxTextIndicies.pl -mod=34
   GenerateTrivoxTextIndicies.pl -mod=all
   GenerateTrivoxTextIndicies.pl -root=files -mod=all