#!perl
#
# IDDumper.pl
# Compare module ID's between 2 databases
#
# Craig Fitzgerald


use warnings;
use strict;
use Gnu::SimpleDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

my $LOCAL_VISITED = {};
my $DEMO_VISITED  = {};

MAIN:
   ArgBuild("*^setid= *^moduleid= *^host= *^username= *^password= ^help ^debug ^debug2");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   #Usage() if ArgIs("help") || !scalar @ARGV;
   #DumpModuleIDs(ArgGet("moduleid")) if ArgIs("moduleid");
   #CompareModuleRecords();
#   CompareModulesQuestions();
#   CheckForUnusedQuestions();

   CompareModuleQuestions(ArgGet("moduleid")) if ArgIs("moduleid");

   exit(0);


sub CompareModuleRecords
   {
   my $db1 = Connect(     "questionnaires", ArgsGet("host", "username", "password"));
   my $db2 = Connect("demo_questionnaires", ArgsGet("host", "username", "password"));

   my $modules1 = FetchHash($db1, "id", "select * from modules");
   my $modules2 = FetchHash($db2, "id", "select * from modules");

   foreach my $key (sort {$a<=>$b} keys %{$modules1})
      {
      #print "looking at $key\n";

      my $module1 = $modules1->{$key};
      my $module2 = $modules2->{$key};

      print "moduleid $key does not exist on demo\n" unless $module2;
      next unless $module2;

      #print "module $key name has changed [$module1->{name}]->[$module2->{name}]\n" if $module1->{name} ne $module2->{name};

      $module1->{firstQuestionId} ||= 0;
      $module2->{firstQuestionId} ||= 0;
      print "module $key firstquestion has changed\n" if $module1->{firstQuestionId} != $module2->{firstQuestionId};
      }
   }


sub CompareModulesQuestions
   {
   my $db1 = Connect("questionnaires", ArgsGet("host", "username", "password"));
   my $modules1 = FetchHash($db1, "id", "select * from modules");

   foreach my $key (sort {$a<=>$b} keys %{$modules1})
      {
      CompareModuleQuestions($key);
      }
   }


sub CompareModuleQuestions
   {
   my ($moduleid) = @_;

   #print "comparing questions in module $moduleid\n";
   print ".";

   my $db1 = Connect(     "questionnaires", ArgsGet("host", "username", "password"));
   my $db2 = Connect("demo_questionnaires", ArgsGet("host", "username", "password"));

   my $module1 = FetchRow($db1, "select * from modules where id=$moduleid");
   my $module2 = FetchRow($db2, "select * from modules where id=$moduleid");

   return print "moduleid $moduleid does not exist on demo\n" unless $module2;
   
   BuildQuestionChain($db1, $module1, $module1->{firstQuestionId}, $LOCAL_VISITED);
   BuildQuestionChain($db2, $module2, $module2->{firstQuestionId}, $DEMO_VISITED );

   my $ct = scalar @{$module1->{question_chain}};
   for (my $i=0; $i<$ct; $i++)
      {
      my $a1 = $module1->{question_chain};
      my $q1 = $a1->[$i];

      my $a2 = $module2->{question_chain};
      my $q2 = $a2->[$i];

      if (!$q2)
         {
         print "module $moduleid, question# $i, $q1->{id} vs *missing* \n";
         }
      elsif ($q1->{id} != $q2->{id})
         {
         print "module $moduleid, question# $i, $q1->{id} vs $q2->{id} differs\n";
         }
      }
   }


sub BuildQuestionChain
   {
   my ($db, $module, $questionid, $visited) = @_;

   $module->{question_chain}   = [];
   $module->{question_visited} = {};

   _BuildQuestionChain($db, $module, $questionid, $visited);
   }


sub _BuildQuestionChain
   {
   my ($db, $module, $questionid, $visited) = @_;

   return unless defined $questionid;
   my $moduleid = $module->{id};

   $visited->{$questionid} = 1;

   return if ($module->{question_visited}->{$questionid});
   $module->{question_visited}->{$questionid} = 1;

   my $question = FetchRow($db, "select * from questions where id=$questionid");
   return unless $question;

   push @{$module->{question_chain}}, $question;

   # first, follow questions from the responses
   #
   my $qtrms = FetchArray($db, "select * from questiontoresponsemap where questionid=$questionid order by responseNumber");
   my %nextQuestionIds = ();
   foreach my $qtrm (@{$qtrms})
      {
      my $flow = FetchRow($db, "select * from flow where questionToResponseMapId=$qtrm->{id} and moduleId=$moduleid");
      $nextQuestionIds{$flow->{targetQuestionId}} = 1 if $flow;
      }
   foreach my $tqid (sort keys %nextQuestionIds)
      {
      _BuildQuestionChain($db, $module, $tqid, $visited);
      }

   # follow child questions
   #
   my $kids = FetchArray ($db, "select * from questionchildren where parentQuestionId=$questionid");
   foreach my $kid (@{$kids})
      {
      _BuildQuestionChain($db, $module, $kid->{childQuestionId}, $visited);
      }

   # then we'll follow questions from any logic
   #
   my $logicevaluation = FetchRow($db, "select * from logicevaluations where questionId=$questionid and moduleId=$moduleid");
   _BuildQuestionChain($db, $module, $logicevaluation->{targetQuestionId}, $visited) if $logicevaluation;

   # then we'll follow questions from any logic defaults
   #
   my $logicdefaulttargets = FetchRow($db, "select * from logicdefaulttargets where questionId=$questionid and moduleId=$moduleid");
   _BuildQuestionChain($db, $module, $logicdefaulttargets->{targetQuestionId}, $visited) if $logicdefaulttargets;
   }


sub CheckForUnusedQuestions
   {
   _CheckForUnusedQuestions   ("questionnaires"     , $LOCAL_VISITED);
   _CheckForUnusedQuestionText("questionnaires"     , $LOCAL_VISITED);
   _CheckForUnusedQuestions   ("demo_questionnaires", $DEMO_VISITED );
   _CheckForUnusedQuestionText("demo_questionnaires", $DEMO_VISITED );
   }

sub _CheckForUnusedQuestions
   {
   my ($dbname, $visited) = @_;

   print "\n\n";
   print "Checking for unused questions on db $dbname";

   my $db1       = Connect($dbname, ArgsGet("host", "username", "password"));
   my $questions = FetchArray($db1, "select * from questions");
   my ($used_ct, $unused_ct) = (0,0);

   foreach my $question (@{$questions})
      {
      my $used = $visited->{$question->{id}};
      $used_ct++    if $used;
      $unused_ct++  if !$used;
      }
   my $total_ct = $used_ct + $unused_ct;
   $questions = undef;

   print "$dbname: questions $total_ct, used: $used_ct, unused: $unused_ct\n";
   }


sub _CheckForUnusedQuestionText
   {
   my ($dbname, $visited) = @_;

   print "\n\n";
   print "Checking for unused (current) questiontext on db $dbname";

   my $db1    = Connect($dbname, ArgsGet("host", "username", "password"));
   my $qtexts = FetchArray($db1, "select * from questiontext where current=1");
   my ($used_ct, $unused_ct) = (0,0);

   foreach my $qtext (@{$qtexts})
      {
      my $used = $visited->{$qtext->{questionId}};
      $used_ct++    if $used;
      $unused_ct++  if !$used;
      }
   my $total_ct = $used_ct + $unused_ct;
   $qtexts = undef;

   print "$dbname: questiontexts $total_ct, used: $used_ct, unused: $unused_ct\n";
   }




#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]

CompareDBs.pl  - Compare module IDs between 2 databases

USAGE: CompareDBs.pl [options]

WHERE: [options] are zero or more of:
   -setid=## .......... Dump this set
   -moduleid=## ....... Dump this module
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -database=name ..... optionally provide the db name (questionnaires)

EXAMPLES:
   CompareDBs.pl -set=1
   CompareDBs.pl -mod=34
