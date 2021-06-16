#!perl
#
# CompareQuestions.pl
# This utility is for examining the questions in a module from 2 different databases
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
   ArgBuild("*^moduleid= *^insert *^host= *^username= *^password= ^help ^debug ^debug2");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs("moduleid");
   CompareModuleQuestions(ArgGet("moduleid"));
   exit(0);


sub CompareModuleQuestions
   {
   my ($moduleid) = @_;

   my $db1 = Connect(     "questionnaires", ArgsGet("host", "username", "password")); # from iciss dev
   my $db2 = Connect("demo_questionnaires", ArgsGet("host", "username", "password")); # from demo

   my $module1 = FetchRow($db1, "select * from modules where id=$moduleid");
   my $module2 = FetchRow($db2, "select * from modules where id=$moduleid");

   return print "moduleid $moduleid does not exist on demo\n" unless $module2;

   print "building prod data for module $moduleid\n";
   BuildQuestionData($db1, $module1, $module1->{firstQuestionId}, $LOCAL_VISITED);

   print "building demo data for module $moduleid\n";
   BuildQuestionData($db2, $module2, $module2->{firstQuestionId}, $DEMO_VISITED );

   my $ct = scalar @{$module1->{question_chain}};
   print "\nprod questions: $ct\n";

   # buildup a hash of demo questions keyed by the english text
   my $demohash = BuildQuestionTextMap($module2->{question_chain}, "demo.question");
   PopulatefromTextMap ($db1, $module1->{question_chain}, $demohash, "demo.question");

   # buildup a hash of demo questions keyed by the english text
   my $prodhash = BuildQuestionTextMap($module1->{question_chain}, "question");
   PopulatefromTextMap ($db1, $module1->{question_chain}, $prodhash, "question");
   }

# loop through the live questions looking for ones that dont have
# a spanish translation yet, and see if textmap has one for the same english text
sub PopulatefromTextMap
   {
   my ($db, $prod_questions, $textmap, $sourcelabel) = @_;

   my $ct = scalar @{$prod_questions};

   my ($addcount, $alreadypresent) = (0, 0);
   for (my $i=0; $i<$ct; $i++)
      {
      my $question = $prod_questions->[$i];

      next if $question->{qtype} =~ /(logic)|(calculation)|(evaluation)/i;

      $alreadypresent++ if $question->{t5912}; # we already have a translation
      next if $question->{t5912}; # we already have a translation

      my $match = $textmap->{$question->{t1804}};
      next unless $match;

      print "\nAdding spanish translation from $sourcelabel $match->{id} to question $question->{id}\n";

      if (ArgIs("debug"))
         {
         print "=" x 80 . "\n";
         print "$question->{qt1804}->{text}\n";
         print "-" x 80 . "\n";
         print "$match->{qt5912}->{text}\n";
         print "=" x 80 . "\n";
         }
      InsertTranslationText ($db, $question, $match->{qt5912}->{text}, 5912) if ArgIs("insert");

      $addcount++;
      }
   print "pre-existing translations: $alreadypresent\n";      
   print "translations added: $addcount\n";
   }



sub BuildQuestionTextMap
   {
   my ($chain, $sourcelabel) = @_;

   my $demohash = {};
   my $democt = scalar @{$chain};
   my $alternates = 0;
   my $spancount = 0;
   for (my $i=0; $i<$democt; $i++)
      {
      my $question = $chain->[$i];

      # skip if the question is the wrong type?
      next if $question->{qtype} =~ /(logic)|(calculation)|(evaluation)/i;

      # skip if there is no translation for this question
      next unless $question->{t1804} && $question->{t5912};

      $spancount++;

      my $match = $demohash->{$question->{t1804}};

      # if we already have a translation for this text
      if ($match)
         {
         # its the same translation
         next if $question->{qt5912}->{text} eq $match->{qt5912}->{text};

         print "Repeated $sourcelabel with alternate translation ($match->{id} and $question->{id}):\n";
         if (ArgIs("debug"))
            {
            print "=" x 80 . "\n";
            print "$match->{qt5912}->{text}\n";
            print "-" x 80 . "\n";
            print "$question->{qt5912}->{text}\n";
            print "=" x 80 . "\n";
            }
         $alternates++;

         my $qlen = length $question->{qt5912}->{text};
         my $mlen = length $match->{qt5912}->{text};

         # keep the longer translation
         next unless $qlen > $mlen;
         }
      $demohash->{$question->{t1804}} = $question;
      }
   print "$sourcelabel count: $democt\n";
   print "$sourcelabel count with spanish: $spancount\n";
   print "unique $sourcelabel count with spanish: " . scalar (keys %{$demohash}) . "\n";
   print "$sourcelabel count with alternate translations: $alternates\n";

   return $demohash;
   }


sub BuildQuestionData
   {
   my ($db, $module, $questionid, $visited) = @_;

   $module->{question_chain}   = [];
   $module->{question_visited} = {};

   BuildQuestionChain($db, $module, $questionid, $visited);
   map {AddQuestionText($db, $_) } @{$module->{question_chain}};
   }


sub BuildQuestionChain
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

   my $qtrms = FetchArray($db, "select * from questiontoresponsemap where questionid=$questionid order by responseNumber");

   # first, we'll follow questions from the responses
   #
   my %nextQuestionIds = ();
   foreach my $qtrm (@{$qtrms})
      {
      my $flow = FetchRow($db, "select * from flow where questionToResponseMapId=$qtrm->{id} and moduleId=$moduleid");
      $nextQuestionIds{$flow->{targetQuestionId}} = 1 if $flow;
      }
   foreach my $tqid (sort keys %nextQuestionIds)
      {
      BuildQuestionChain($db, $module, $tqid, $visited);
      }

   # then we'll follow questions from any logic
   #
   my $logicevaluation = FetchRow($db, "select * from logicevaluations where questionId=$questionid and moduleId=$moduleid");
   BuildQuestionChain($db, $module, $logicevaluation->{targetQuestionId}, $visited) if $logicevaluation;

   # then we'll follow questions from any logic defaults
   #
   my $logicdefaulttargets = FetchRow($db, "select * from logicdefaulttargets where questionId=$questionid and moduleId=$moduleid");
   BuildQuestionChain($db, $module, $logicdefaulttargets->{targetQuestionId}, $visited) if $logicdefaulttargets;

   # finally, we follow child questions
   #
   my $kids = FetchArray ($db, "select * from questionchildren where parentQuestionId=$questionid");
   foreach my $kid (@{$kids})
      {
      BuildQuestionChain($db, $module, $kid->{childQuestionId}, $visited);
      }
   }


sub AddQuestionText
   {
   my ($db, $question) = @_;

   my $id  = $question->{id};
   $question->{qt1804} = FetchRow($db, "select * from questiontext where current=1 and languageId=1804 and questionId=$id");
   $question->{qt5912} = FetchRow($db, "select * from questiontext where current=1 and languageId=5912 and questionId=$id");

   #my $e = $question->{qt1804} ? "yup" : "nope";
   #my $s = $question->{qt5915} ? "yup" : "nope";
   #print "Question $id :  english? $e, spanish? $s\n";

   $question->{t1804} = NormalizeText ($question->{qt1804} ? $question->{qt1804}->{text} : "");
   $question->{t5912} = NormalizeText ($question->{qt5912} ? $question->{qt5912}->{text} : "");
   }

# cut out as much clutter as we can so that when we compare, there is a better chance of a match
#
sub NormalizeText
   {
   my ($string) = @_;

   $string =~ s/<\/?div[^>]*>//gi;     
   $string =~ s/<\/?span[^>]*>//gi;    
   $string =~ s/<\/?p[^>]*>//gi;       
   $string =~ s/<\/?br[^>]*>//gi;      
   $string =~ s/<\/?hr[^>]*>//gi;      
   $string =~ s/<\/?acronym[^>]*>//gi; 
   $string =~ s/<\/?em[^>]*>//gi;      
   $string =~ s/&nbsp;/ /gi;           
   $string =~ s/(<br\s*\/?>){3,}/<br \/><br \/>/gi;
   return Trim($string);
   }




sub InsertTranslationText
   {
   my ($db, $question, $text, $language) = @_;

   my $sql = "INSERT INTO questiontext (questionId, languageId, text , adminUserId, current) VALUES (?, ?, ?, 9999, 1)";

   ExecSQL ($db, $sql, $question->{id}, $language, $text);

   print "sql inserted id: $db->{mysql_insertid}\n" unless $db->errstr;
   die "sql error: $db->errstr\n" if $db->errstr;
   }


#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]
CompareQuestions - Compare the questions of a module from 2 databases
                      questionnaires and demo_questionnaires

USAGE: CompareQuestions.pl [options]

WHERE: [options] are one or more of:
   -moduleid=160 ...... Dump this module (required)
   -insert ............ (See NOTES Below)
   -debug ............. Print out lots of info
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)

EXAMPLES:
   CompareQuestions.pl -mod=160 
   CompareQuestions.pl -mod=160 -debug
   CompareQuestions.pl -mod=160 -insert

NOTES:
   The -insert option is to handle a special case:
     The pre conditions are as follows (for a specific module):
        1> demo_questionnaires has new spanish questiontext
        2> questionnaires has been updated so that none of the
           questionids for the module match between dbs
        3> Sometimes the exact same text is repeated, and the
           translator did not populate all copies.
     The insert option does the following:
        Where there are questionnaires.questions that do not have
        spanish questiontext, and demo_questionnaires.questions that
        have (essentially) the same english text, we copy the spanish
        questiontext from demo_questionnaires to questionnaires.

   In other words, you dont want to use the -insert option unless
     you have a module that needs major work.
