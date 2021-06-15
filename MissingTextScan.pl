#!perl
#
# MissingTextScan.pl
#
# This utility is for examining id's for a survey
#
#
# This module set comes from the original translation doc:
#
#my @MODULE_IDS =
#   (6,43,46,48,50,50,51,61,62,69,70,71,72,74,75,86,87,89,90,95,96,102,104,106,
#    108,110,114,115,116,117,118,124,125,126,127,129,132,133,135,136,137,138,
#    139,140,142,143,145,146,150,151,152,153,154,155,155,156,158,159,160,161,
#    162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,181,182,
#    183,184,185,192,193,195,196,197,198,199,200,201,202,204,205,206,213,216,
#    217,218,219,220,221,222,223,224,225,227,228,229,230,231,232,234,235,236,237);
#
# This module set has teacher modules removed
#
my @MODULE_IDS =
   (6,43,46,48,50,50,51,61,62,69,70,71,72,74,75,86,87,89,90,95,96,102,104,
    108,114,115,116,117,118,124,125,126,127,129,132,133,135,136,137,138,
    139,140,145,146,150,151,152,153,154,155,155,156,158,160,161,
    162,163,164,165,166,167,168,169,176,177,181,182,
    183,184,185,192,193,195,196,197,198,199,200,201,202,204,205,206,213,216,
    217,218,219,220,221,222,223,224,225,227,228,230,231,232,234,237);

#my @MODULE_IDS = (124);

use warnings;
use strict;
use feature 'state';
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

my $STATS = 
   {
   mod_q_ok      =>{}, # map of moduleid=>question ok count
   mod_q_err     =>{}, # map of moduleid=>question error count
   question_ok   =>{}, # map of questionid=>infohash thats ok
   question_err  =>{}, # map of questionid=>infohash thats is in error
   mod_r_ok      =>{}, # map of moduleid=>response ok count
   mod_r_err     =>{}, # map of moduleid=>response error count
   response_ok   =>{}, # map of responseid=>infohash thats ok
   response_err  =>{}, # map of responseid=>infohash thats is in error
   mod_q_err_list=>{}, # map of moduleid=>problem itemarray
   mod_r_err_list=>{}, # map of moduleid=>problem itemarray
   logs          =>{}, # map of module logs
   visited_q     =>{}, # working visited question map
   q_ids         =>{},
   r_ids         =>{},
   q_count       =>0,  # count of questions
   r_count       =>0,  # count of responses
   q_word_count  =>0,  # word count of questions
   r_word_count  =>0,  # word count of responses
   q_char_count  =>0,  # total chars of questions
   r_char_count  =>0,  # total chars of responses
   global_q      =>{}, # all visited question map keyed by id
   };


MAIN:
   $| = 1;
   ArgBuild("*^language= *^html= *^moduleid= *^records *^host= *^username= *^password= ^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs("language");

   CheckforMissingText();
   PrintResults();
   HtmlDump();
   exit(0);



sub CheckforMissingText
   {
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   my $langid = GetLanguageId();
   print "Scanning questiontext and response text for language $langid\n";

   if (ArgIs("moduleid"))
      {
      my $moduleid = ArgGet("moduleid");
      print "checking module $moduleid\n";
      CheckModule($moduleid);
      }
   else
      {
      print "checking all appropriate modules\n";
      map {CheckModule($_)} @MODULE_IDS;
      }
   }


sub CheckModule
   {
   my ($moduleid) = @_;

   $STATS->{visited_q} = {};
   $STATS->{mod_q_err_list}->{$moduleid} = [];
   $STATS->{mod_r_err_list}->{$moduleid} = [];

   my $module = FetchRow("select * from modules where id=$moduleid");
   print "Scanning $module->{name} [$moduleid]";
   Log($moduleid, "[module::id:$moduleid, firstQuestionId:$module->{firstQuestionId}, name:$module->{name}]");

   CheckQuestionChain($moduleid, $module->{firstQuestionId});

   print "\n";
   ShowRecords($moduleid) if ArgIs("records");
   }


sub CheckQuestionChain
   {
   my ($moduleid, $questionid) = @_;

   return if $STATS->{visited_q}->{$questionid};
   $STATS->{visited_q}->{$questionid} = 1;


   return unless defined $questionid;
   my $question = FetchRow("select * from questions where id=$questionid");
   return unless $question;

   $STATS->{global_q}->{$questionid} = 1; # keep a hash of every used question

   Log($moduleid, "[question::id:$questionid, qtype:$question->{qtype}, title:$question->{title}]");
   
   CheckQuestionText($moduleid, $question);

   my $qtrms = FetchArray("select * from questiontoresponsemap where questionid=$questionid order by responseNumber");

   foreach my $qtrm (@{$qtrms})
      {
      next unless defined $qtrm->{responseId};

      Log($moduleid, "  [qtrm::id:$qtrm->{id}, questionid:$qtrm->{questionId}, responseId:$qtrm->{responseId}");

      my $response = FetchRow("select * from responses where id=$qtrm->{responseId}");
      CheckResponseText($moduleid, $questionid, $response);
      }

   # first, we'll follow questions from the responses
   my %nextQuestionIds = ();
   foreach my $qtrm (@{$qtrms})
      {
      my $flow = FetchRow("select * from flow where questionToResponseMapId=$qtrm->{id} and moduleId=$moduleid");

      Log($moduleid, "  [flow::id:$flow->{id}, qtrmid:$flow->{questionToResponseMapId}, targetQuestionId:$flow->{targetQuestionId}") if $flow;

      $nextQuestionIds{$flow->{targetQuestionId}} = 1 if $flow;
      }
   foreach my $tqid (sort keys %nextQuestionIds)
      {
      CheckQuestionChain($moduleid, $tqid);
      }

   # then we'll follow questions from any logic
   my $logicevaluations = FetchArray("select * from logicevaluations where questionId=$questionid and moduleId=$moduleid order by id");
   map {CheckQuestionChain($moduleid, $_->{targetQuestionId})} @{$logicevaluations};

   # then we'll follow questions from any logic defaults
   my $logicdefaulttargets = FetchArray("select * from logicdefaulttargets where questionId=$questionid and moduleId=$moduleid order by id");
   map{CheckQuestionChain($moduleid, $_->{targetQuestionId})} @{$logicdefaulttargets};

   # finally, we follow child questions
   my $kids = FetchArray ("select * from questionchildren where parentQuestionId=$questionid");
   foreach my $kid (@{$kids})
      {
      Log($moduleid, "  [questionchildren::id:$kid->{id}, parentQuestionId:$kid->{parentQuestionId}, childQuestionId:$kid->{childQuestionId}]");
      CheckQuestionChain($moduleid, $kid->{childQuestionId});
      }
   }


sub CheckQuestionText
   {
   my ($moduleid, $question) = @_;

   return unless $question;
   return if $question->{qtype} =~ /(logic)|(calculation)|(evaluation)/i;

   my $langid = GetLanguageId();
   my $qid    = $question->{id};
   my $qt     = FetchRow("select * from questiontext where questionId=$qid and languageId=$langid and current=1");

   print "*";

   if ($qt)
      {
      my @words = split(" ", $qt->{text});
      $STATS->{q_count     }++;
      $STATS->{q_char_count} += length $qt->{text};
      $STATS->{q_word_count} += scalar @words;
      }

   my $ok = $qt && Trim($qt->{text});

   # check: if no english text, its probably ok not to have foreign text
   $ok = 1 if (!$qt && !FetchRow("select * from questiontext where questionId=$qid and languageId=1804 and current=1"));

   if ($ok)
      {
      $STATS->{mod_q_ok}->{$moduleid} = 0 unless exists $STATS->{mod_q_ok}->{$moduleid};
      $STATS->{mod_q_ok}->{$moduleid}++;
      $STATS->{question_ok}->{$qid} = {err=>0,moduleid=>$moduleid};
      }
   else
      {
      $STATS->{mod_q_err}->{$moduleid} = 0 unless exists $STATS->{mod_q_err}->{$moduleid};
      $STATS->{mod_q_err}->{$moduleid}++;
      $STATS->{question_err}->{$qid} = {err=>($qt ? 2:1),moduleid=>$moduleid};

      push @{$STATS->{mod_q_err_list}->{$moduleid}}, $qid;
      }
   }


sub CheckResponseText
   {
   my ($moduleid, $questionid, $response) = @_;

   return unless $response;

   my $langid = GetLanguageId();
   my $rid    = $response->{id};
   my $rt = FetchRow("select * from responsetext where responseId=$rid and languageId=$langid and current=1");

   print ".";

   if ($rt && !$STATS->{r_ids}->{$rt->{id}})
      {
      my @words = split(" ", $rt->{text});
      $STATS->{r_count     }++;
      $STATS->{r_char_count} += length $rt->{text};
      $STATS->{r_word_count} += scalar @words;

      $STATS->{r_ids}->{$rt->{id}} = 1;
      }

   my $ok = $rt && Trim($rt->{text});
   if ($ok)
      {
      $STATS->{mod_r_ok}->{$moduleid} = 0 unless exists $STATS->{mod_r_ok}->{$moduleid};
      $STATS->{mod_r_ok}->{$moduleid}++;
      $STATS->{response_ok}->{$rid} = {err=>0,moduleid=>$moduleid,questionid=>$questionid};
      }
   else
      {
      $STATS->{mod_r_err}->{$moduleid} = 0 unless exists $STATS->{mod_r_err}->{$moduleid};
      $STATS->{mod_r_err}->{$moduleid}++;
      $STATS->{response_err}->{$rid} = {err=>($rt ? 2:1),moduleid=>$moduleid,questionid=>$questionid} ;

      push @{$STATS->{mod_r_err_list}->{$moduleid}}, $rid;
      }
   }

sub Log
   {
   my ($moduleid, $string) = @_;

   return unless ArgIs("records");
   
   $STATS->{log}->{$moduleid} = "" unless exists $STATS->{log}->{$moduleid};
   $STATS->{log}->{$moduleid} .= "$string\n";
   }

sub PrintResults
   {
   PrintResults_MissingQuestionTextModules();
   PrintResults_MissingResponseTextModules();
   PrintResults_MissingQuestionTexts      ();
   PrintResults_MissingResponseTexts      ();
   PrintResults_Counts                    ();
   PrintResults_DuplicateQuestionText     ();
   }

sub PrintResults_MissingQuestionTextModules
   {
   print "\nList of modules with questions with missing questiontext:\n";
   foreach my $key (sort keys %{$STATS->{mod_q_err}})
      {
      my $mid    = $key;
      my $err_ct = $STATS->{mod_q_err}->{$key};
      my $all_ct = ($STATS->{mod_q_ok}->{$key}||0) + $err_ct;
      my $module = FetchRow("select * from modules where id=$mid");
      my $name   = $module->{name};

      print '<a href="https://demo.helpsteps.com/sysadmin/translate.html?type=QUESTION&mid=' . $mid . '&study=1&from=eng&to=spa">' . "$name ($err_ct of $all_ct missing) ". '</a>' . "\n";
      }
   }

sub PrintResults_MissingResponseTextModules
   {
   print "\nList of modules with questions with responses with missing responsetext:\n";
   foreach my $key (sort keys %{$STATS->{mod_r_err}})
      {
      my $mid    = $key;
      my $err_ct  = $STATS->{mod_r_err}->{$key};
      my $all_ct  = ($STATS->{mod_r_ok}->{$key}||0) + $err_ct;
      my $module = FetchRow("select * from modules where id=$mid");
      my $name   = $module->{name};

      print '<a href="https://demo.helpsteps.com/sysadmin/translate.html?type=RESPONSE&mid=' . $mid . '&study=1&from=eng&to=spa">' . "$name ($err_ct of $all_ct missing) ". '</a>' . "\n";
      }
   }

sub PrintResults_MissingQuestionTexts
   {
   print "\nList of missing questiontext:\n";
   foreach my $key (sort keys %{$STATS->{question_err}})
      {
      my $err = $STATS->{question_err}->{$key}->{err} == 1 ? "missing" : "blank";
      my $mid = $STATS->{question_err}->{$key}->{moduleid};
      print sprintf ("%5.5d : (moduleid=%3.3d) %s\n", $key, $mid, $err);
      }
   print scalar (keys %{$STATS->{question_err}}) . " missing questiontext records.\n\n";
   }

sub PrintResults_MissingResponseTexts
   {
   print "\nList of missing responsetext:\n";
   foreach my $key (sort keys %{$STATS->{response_err}})
      {
      my $err = $STATS->{response_err}->{$key}->{err} == 1 ? "missing" : "blank";
      my $mid = $STATS->{response_err}->{$key}->{moduleid};
      my $qid = $STATS->{response_err}->{$key}->{questionid};
      print sprintf ("%4.4d : (moduleid=%3.3d, questionid=%5.5d) %s\n", $key, $mid, $qid, $err);
      }
   print scalar (keys %{$STATS->{response_err}}) . " missing responsetext records.\n";
   }

sub PrintResults_Counts
   {
   #map{print "$_\n"} sort keys %{$STATS->{mod_r_err}};
   print "\n";

   print "Question Count      : $STATS->{q_count     }\n";
   print "Question Word Count : $STATS->{q_word_count}\n";
   print "Question Char Count : $STATS->{q_char_count}\n";

   print "Response Count      : $STATS->{r_count     }\n";
   print "Response Word Count : $STATS->{r_word_count}\n";
   print "Response Char Count : $STATS->{r_char_count}\n";
   }


sub PrintResults_DuplicateQuestionText_0
   {
   my $textmap = {};

   # 1st build a map baserd on english text
   foreach my $qid (sort keys %{$STATS->{global_q}})
      {
      my $qt = FetchRow("select * from questiontext where questionId=$qid and languageId=1804 and current=1");
      next unless $qt && $qt->{text};
      my $text = $qt->{text};

      $textmap->{$text} = {count=>0, qid=>[]} unless exists $textmap->{$qt->{text}};
      $textmap->{$text}->{count}++;
      push @{$textmap->{$text}->{qid}}, $qid;
      }

   print "\nList of questions with duplicate english questiontext:\n";
   print "[count,englishcount,spanishcount,portuguesecount] questionids...\n";

   foreach my $text (keys %{$textmap})
      {
      my $nfo = $textmap->{$text};

      next unless $nfo->{count} > 1;

      print "Duplicate qtext set: ";

      my ($t_ct, $e_ct, $s_ct, $p_ct) = (0, 0, 0, 0);
      foreach my $qid (@{$nfo->{qid}})
         {
         $t_ct++;
         $e_ct += QuestionHasTextOfLanguage($qid, 1804);
         $s_ct += QuestionHasTextOfLanguage($qid, 5912);
         $p_ct += QuestionHasTextOfLanguage($qid, 5265);
         }
      print "[t_ct:$t_ct, e_ct:$e_ct, s_ct:$s_ct, p_ct:$p_ct] ";

      print join(", ", @{$nfo->{qid}});
      print "\n";
      }
   }


sub PrintResults_DuplicateQuestionText
   {
   my $textmap = {};

   # 1st build a map baserd on english text
   foreach my $qid (sort keys %{$STATS->{global_q}})
      {
      my $qt = FetchRow("select * from questiontext where questionId=$qid and languageId=1804 and current=1");
      next unless $qt && $qt->{text};
      my $text = $qt->{text};

      $textmap->{$text} = {count=>0, qid=>[]} unless exists $textmap->{$qt->{text}};
      $textmap->{$text}->{count}++;
      push @{$textmap->{$text}->{qid}}, $qid;
      }

   print "\nList of duplicate questions that are not fully translated:\n";
   print "[count,englishcount,spanishcount,portuguesecount] questionids...\n";

   foreach my $text (keys %{$textmap})
      {
      my $nfo = $textmap->{$text};

      next unless $nfo->{count} > 1;


      my ($t_ct, $e_ct, $s_ct, $p_ct) = (0, 0, 0, 0);
      foreach my $qid (@{$nfo->{qid}})
         {
         $t_ct++;
         $e_ct += QuestionHasTextOfLanguage($qid, 1804);
         $s_ct += QuestionHasTextOfLanguage($qid, 5912);
         $p_ct += QuestionHasTextOfLanguage($qid, 5265);
         }

      # lets not print anything if all copies f=have spanish conversions
      #
      next if  ($e_ct == $t_ct) && ($s_ct == $e_ct);

      print "Duplicate qtext set: ";
      print "[t_ct:$t_ct, e_ct:$e_ct, s_ct:$s_ct, p_ct:$p_ct] ";
      print join(", ", @{$nfo->{qid}});
      print "\n";
      }
   }


sub QuestionHasTextOfLanguage
   {
   my ($qid, $langid) = @_;

   my $qt = FetchRow("select * from questiontext where questionId=$qid and languageId=$langid and current=1");
   return 0 unless $qt;
   return 0 unless $qt->{text};
   return 1;
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


sub HtmlDump
   {
   my $filename = ArgGet("html") || "missing.html";
   open (my $file, ">", $filename);

   print $file Template("html_start");

   print $file Template("html_q_start");
   foreach my $key (sort keys %{$STATS->{mod_q_err}})
      {
      my $err_ct = $STATS->{mod_q_err}->{$key};
      my $all_ct = ($STATS->{mod_q_ok}->{$key}||0) + $err_ct;
      my $module = FetchRow("select * from modules where id=$key");
      my $qids   = join(",", sort @{$STATS->{mod_q_err_list}->{$key}});

      print $file Template("html_q_module", %{$module},err_ct=>$err_ct,all_ct=>$all_ct,qids=>$qids);
      }

   print $file Template("html_r_start");
   foreach my $key (sort keys %{$STATS->{mod_r_err}})
      {
      my $err_ct = $STATS->{mod_r_err}->{$key};
      my $all_ct = ($STATS->{mod_r_ok}->{$key}||0) + $err_ct;
      my $module = FetchRow("select * from modules where id=$key");
      my $rids   = join(",", uniq($STATS->{mod_r_err_list}->{$key}));

      print $file Template("html_r_module", %{$module},err_ct=>$err_ct,all_ct=>$all_ct,rids=>$rids);
      }
   print $file Template("html_end");
   close $file;
   }

sub uniq
   {
   my ($arr) = @_;

   my %holder;
   map {$holder{$_}=1} @{$arr};
   return (sort keys %holder);
   }

sub ShowRecords
   {
   my ($moduleid) = @_;

   #foreach my $key (sort keys %{$STATS->{log}})
   #   {
   #   print $STATS->{log}->{$key} . "\n\n";
   #   }
   print "Item Records:\n";
   print "\n" . $STATS->{log}->{$moduleid} . "\n\n";
   }


sub GetLanguageId
   {
   my $language = ArgIs("language") ? ArgGet("language") : 1804;
   $language = 5912 if $language =~ /^span/i;
   $language = 5265 if $language =~ /^port/i;
   $language = 1804 if $language =~ /^eng/i;

   return $language;
   }


__DATA__

[usage]
MissingTextScan.pl  - Scan Trivox metadata for missing text data

USAGE: MissingTextScan.pl [options]

WHERE: [options] are one or more of:
   -language=#### ..... Pick language to scan (1804|5912|5265)
   -moduleid=## ....... Choose module to scan (all if no opt)
   -html=name ......... Name for html report
   -records ........... Show record log.
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)

EXAMPLES:
   MissingTextScan.pl -lang=1804
   MissingTextScan.pl -lang=5912
   MissingTextScan.pl -lang=5265
todo
[html_start]
   <html>
   <head></head>
   <body>
[html_q_start]
   <h2>List of modules with questions with missing questiontext:</h2>
[old_html_q_module]
   <h4><a href="https://translate.trivoxhealth.com/sysadmin/translate.html?type=QUESTION&mid=$id&study=1&from=eng&to=spa">[$id] $name ($err_ct of $all_ct missing)</a></h4>
   <p>Missing question ids: $qids</p>
[html_q_module]
   <h4>[$id] $name ($err_ct of $all_ct missing)</h4>
   <p>
      <a href="https://translate.trivoxhealth.com/sysadmin/translate.html?type=QUESTION&mid=$id&study=1&from=eng&to=spa">External Editor</a> | 
      <a href="http://craig.trivoxhealth.com/qt/trivoxtext.html?kind=question&module=$id">Internal Editor</a>
   </p>
   <p>Missing question ids: $qids</p>

[html_r_start]
   <h2>List of modules with questions with responses with missing responsetext:</h2>
[old_html_r_module]
   <h4><a href="https://translate.trivoxhealth.com/sysadmin/translate.html?type=RESPONSE&mid=$id&study=1&from=eng&to=spa">[$id] $name ($err_ct of $all_ct missing)</a></h4>
   <p>Missing response ids: $rids</p>
[html_r_module]
   <h4>[$id] $name ($err_ct of $all_ct missing)</h4>
   <p>
      <a href="https://translate.trivoxhealth.com/sysadmin/translate.html?type=RESPONSE&mid=$id&study=1&from=eng&to=spa">External Editor</a> | 
      <a href="http://craig.trivoxhealth.com/qt/trivoxtext.html?kind=response&module=$id">Internal Editor</a>
   </p>
   <p>Missing response ids: $rids</p>
[html_end]
   </body>
   </html>
