#!perl
#
# GenModuleQuestions.pl
# This utility is for populating the questionnaires.modulequestions
# Not that this needs to be run before and IRT modukes are imported in the system
#
# Craig Fitzgerald


use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

MAIN:
   ArgBuild("*^moduleid= *^root= *^host= *^username= *^password= *^debug ^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs("moduleid");

   PopulateModuleQuestionsTable();
   exit(0);


sub PopulateModuleQuestionsTable
   {
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   if (ArgGet("moduleid") =~ /all/i)
      {
      print "truncate modulequestions;\n" if ArgIs("debug");
      ExecSQL("truncate modulequestions;" )  if !ArgIs("debug");
      my $modules = FetchArray("select * from modules order by id");
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
   $module->{_question_visited} = {};
   FollowQuestionChain ($module, $module->{firstQuestionId}, 0);
   }


sub FollowQuestionChain
   {
   my ($module, $questionid, $parentquestionid) = @_;

   return unless $module;
   return unless $questionid;

   return if $module->{_question_visited}->{$questionid};
   $module->{_question_visited}->{$questionid} = 1;

   my $moduleid = $module->{id};

   my $question = FetchRow("select * from questions where id=$questionid");
   return unless $question;

   print "Row: moduleId:$moduleid, questionId:$question->{id}, parentQuestionId:$parentquestionid\n" if ArgIs("debug");
   ExecSQL("insert into modulequestions (moduleid, questionid, parentQuestionId) values(?,?,?)", $moduleid, $questionid, $parentquestionid) if !ArgIs("debug");
   print "." if !ArgIs("debug");

   # first, we follow child questions
   my $kids = FetchArray ("select * from questionchildren where parentQuestionId=$questionid");
   map{FollowQuestionChain($module, $_->{childQuestionId}, $questionid)} @{$kids};

   # then, we'll follow questions from the responses
   my $qtrms = FetchArray("select * from questiontoresponsemap where questionid=$questionid order by responseNumber");
   my %nextQuestionIds = ();
   foreach my $qtrm (@{$qtrms})
      {
      my $flow = FetchRow("select * from flow where questionToResponseMapId=$qtrm->{id} and moduleId=$moduleid");
      $nextQuestionIds{$flow->{targetQuestionId}} = 1 if $flow;
      }
   map {FollowQuestionChain($module, $_, 0)} (sort keys %nextQuestionIds);
                                             
   # then we'll follow questions from any logic
   my $le = FetchRow("select * from logicevaluations where questionId=$questionid and moduleId=$moduleid");
   FollowQuestionChain($module, $le->{targetQuestionId}, 0) if $le;

   # then we'll follow questions from any logic defaults
   my $ldt = FetchRow("select * from logicdefaulttargets where questionId=$questionid and moduleId=$moduleid");
   FollowQuestionChain($module, $ldt->{targetQuestionId}, 0) if $ldt;
   }


__DATA__

[usage]
GenModuleQuestions.pl  - Generate questionnaires.moduleQuestions table from existing data.
This will not work for IRT Modules!

Usage: GenModuleQuestions.pl  [options]

WHERE: [options] are one or more of:
   -moduleid=(##|all) . Choose module to scan (or all)
   -root=name ......... Set root for outfiles
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug ............. Print out results, dont update the DB

EXAMPLES:
   GenModuleQuestions.pl -mod=34
   GenModuleQuestions.pl -mod=all
