#!perl
#
# QuestionView.pl
# This utility is for examining question/questiontext text
#
# Craig Fitzgerald

# This utility is usefull for determining what problems exist, what 
#  foreign fields are missing, what <var> names are present, etc...
#
# This utility can generate html as well as text.  This can be usefull for
#  detecting broken tags, as all following html will likely be screwed up.
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Some examples:
#
#   Generate a html page of all the questions:
#
#     QuestionView.pl -e -html > foo.html
#
#   Generate a html page of all the questions and the protugeuse translations:
#
#     QuestionView.pl -language=portuguese -e -f -html > foo.html
#
#   Display all questions (and associated questiontext) that have both english
#   and spanish text:
#
#     QuestionView.pl -language=spanish -e -f
#
#   Display all questions (and associated questiontext) that have both english
#   and spanish text, and that have the "<" char encoded as an html entity
#   in ther spanish text:
#
#     QuestionView.pl -language=spanish -e -f -ftext="&lt;"
#
#   Create a web page containing all questions (and associated questiontext) that 
#    have <var>'s in the english text, but dont have <var>'s in the spanish text
#
#     QuestionView.pl -language=spanish -e -f -ve -vnf -html > foo.html
#
#   Generate question index files for the web page editor:
#
#     QuestionView.pl -language=spanish -e -f -idsonly > 5912
#     QuestionView.pl -language=portuguese -e -f -idsonly > 5265


use warnings;
use strict;
use feature 'state';
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);


MAIN:
   $| = 1;
   ArgBuild("*^all ^e ^ne ^f ^nf ^v ^nv ^ve ^vf ^vne ^vnf ^vars " .
            "^varsonly *^varnameonly *^idsonly *^orphans "        .
            "*^etext= *^ftext= ^id= ^eid= ^fid= *^language= "     .
            "*^html *^host= *^username= *^password= *^help");

   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !scalar @ARGV;

   Connection("questionnaires", ArgsGet("host", "username", "password"));

   PrintQuestionVars       () if ArgIs("varsonly");
   PrintQuestionsIDs       () if ArgIs("idsonly");
   PrintQuestionTextOrphans() if ArgIs("orphans");
   PrintQuestions          ();
   exit(0);


# Return an array containing the two languages we're working with
# The first is always english, the second depends on the -language= param
# and defaults to spanish
#
sub GetLanguageIds
   {
   my $language = ArgIs("language") ? ArgGet("language") : 5912;
   $language = 5912 if $language =~ /spanish/i;
   $language = 5265 if $language =~ /portug/i;

   return (1804, $language);
   }


sub PrintQuestions          
   { 
   my ($questions, $questiontexts) = QuestionData(); 

   my $title = "showing questions";
   $title .= " with english text"    if ArgIs("e" );
   $title .= " without english text" if ArgIs("ne"); 
   $title .= " with foreign text"    if ArgIs("f" ); 
   $title .= " without foreign text" if ArgIs("nf"); 
   $title .= " with var tags"        if ArgIs("v" ); 

   PrintStart($title);

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$questions})
      {
      my $question = $questions->{$id};

      next unless PassesQuestionFilters($question);

      my $questiontext = $questiontexts->{$id} || {};
      my $etext = $questiontext->{$english_lang_id};
      my $ftext = $questiontext->{$foreign_lang_id};

      next unless PassesTextFilters($etext->{text}, $ftext->{text});
      next unless PassesIdFilters($id, $etext->{id}, $ftext->{id});
                                   
      PrintQuestionStart($question);
      PrintQVar  ("English"        , $question, $etext);
      PrintQText ("English"        , $question, $etext);
      PrintQVar  ("Foreign"        , $question, $ftext);
      PrintQPar  ("Foreign"        , $question, $ftext);
      PrintQText ("Foreign"        , $question, $ftext);
      PrintQText ("English_Encoded", $question, $etext);
      PrintQText ("Foreign_Encoded", $question, $ftext);

      PrintQuestionEnd($question);
      $count++;
      }
   PrintEnd ($count++)
   }

# special case #1
sub PrintQuestionTextOrphans
   { 
   my ($questions, $questiontexts) = QuestionData();  

   print "\nquestiontext orphans (iq,questionid,langid,text):\n";
   print "=" x 100 . "\n";
   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$questiontexts})
      {
      my $questiontext = $questiontexts->{$id};
      foreach my $record (values %{$questiontext})
         {
         next if $record->{used};
         print "$record->{id} : $record->{questionId} : $record->{languageId} : $record->{text}\n";
         $count++;
         }
      }
   print "($count questiontexts)\n";
   }


# special case #2
sub PrintQuestionVars
   { 
   my ($questions, $questiontexts) = QuestionData(); 

   my $title = "showing vars";
   $title .= " with english text"    if ArgIs("e" );
   $title .= " without english text" if ArgIs("ne"); 
   $title .= " with foreign text"    if ArgIs("f" ); 
   $title .= " without foreign text" if ArgIs("nf"); 
   $title .= " with var tags"        if ArgIs("v" ); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   foreach my $id (sort {$a<=>$b} keys %{$questions})
      {
      my $question = $questions->{$id};

      next unless PassesQuestionFilters ($question);

      my $questiontext = $questiontexts->{$id} || {};
      PrintVars($questiontexts, $id, $english_lang_id);
      PrintVars($questiontexts, $id, $foreign_lang_id);
      }
   exit(0);
   }


# special case 3
sub PrintQuestionsIDs
   { 
   my ($questions, $questiontexts) = QuestionData(); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();
   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$questions})
      {
      my $question = $questions->{$id};

      next unless PassesQuestionFilters($question);

      my $questiontext = $questiontexts->{$id} || {};
      my $etext = $questiontext->{$english_lang_id};
      my $ftext = $questiontext->{$foreign_lang_id};

      next unless PassesTextFilters($etext->{text}, $ftext->{text});
      next unless PassesIdFilters($id, $etext->{id}, $ftext->{id});
                                   
      print "$id\n";
      }
   exit(0);
   }




sub PrintVars
   {
   my ($questiontexts, $questionid, $language) = @_;

   my $questiontext = $questiontexts->{$questionid} || return;
   my $record = $questiontext->{$language} || return;
   my $id   = $record->{id};
   my $text = $record->{text};
   my @vars = ($text =~ /(\<var.*?\<\/var\>)/gis);

   foreach my $var (@vars)
      {
      my ($varname) = $var =~ />(.*)<\/var>/i;

      #print "### $var ###\n" unless $varname;

      my $str = ArgIs("varnameonly") ? $varname : $var;

      print sprintf ("%5.5d %5.5d %5.5d %s\n", $language, $questionid, $id, $str);
      }
   }

sub PassesQuestionFilters
   {
   my ($question) = @_;

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   return 0 if ArgIs("e"  ) && !$question->{"has_"      . $english_lang_id};
   return 0 if ArgIs("ne" ) &&  $question->{"has_"      . $english_lang_id};
   return 0 if ArgIs("f"  ) && !$question->{"has_"      . $foreign_lang_id};
   return 0 if ArgIs("nf" ) &&  $question->{"has_"      . $foreign_lang_id};
   return 0 if ArgIs("v"  ) && !$question->{"has_var"                     };
   return 0 if ArgIs("nv" ) &&  $question->{"has_var"                     };
   return 0 if ArgIs("ve" ) && !$question->{"has_var_"  . $english_lang_id};
   return 0 if ArgIs("vne") &&  $question->{"has_var__" . $english_lang_id};
   return 0 if ArgIs("vf" ) && !$question->{"has_var__" . $foreign_lang_id};
   return 0 if ArgIs("vnf") &&  $question->{"has_var__" . $foreign_lang_id};
   return 1;
   }

sub PassesTextFilters
   {
   my ($etext, $ftext) = @_;

   if (ArgIs("etext"))
      {
      my $match = ArgGet("etext");

      return 0 unless $etext =~ /$match/i;
      }
   if (ArgIs("ftext"))
      {
      my $match = ArgGet("ftext");
      return 0 unless $ftext =~ /$match/i;
      }
   return 1;
   }

sub PassesIdFilters
   {
   my ($id, $eid, $sid) = @_;

   return PassesIdFilter($id,  "id" ) &&
          PassesIdFilter($eid, "eid") &&
          PassesIdFilter($sid, "fid") ;
   }

sub PassesIdFilter
   {
   my ($id, $pname) = @_;
   return 1 unless $id;
   return 1 unless ArgIs($pname);
   for (my $i=0; my $match = ArgGet($pname, $i); $i++) 
      {
      return 1 if $id == $match;
      }
   return 0;
   }



#############################################################################
#                                                                           #
#############################################################################

sub PrintStart 
   { 
   my ($title) = @_;

   my $tname = AppendType("Start");
   print Template($tname, title=>$title);
   }

sub PrintQuestionStart
   { 
   my ($question) = @_;

   my $tname = AppendType("QuestionStart");
   print Template($tname, %{$question});
   }

sub PrintQText 
   { 
   my ($template_base, $question, $record) = @_;

   return unless $record;

   #if (ArgIs("vars"))
   #   {
   #   my @vars  = ($etext =~ /(\<var.*?\<\/var\>)/gis);
   #   my @pars  = ($ftext =~ /(\([^(]+\))/gi);
   #   my $tname = AppendType("QuestionVarText_" . $template_base);
   #   map {print Template($tname, label=>"var", var=>$_)} @vars;
   #   map {print Template($tname, label=>"par", var=>$_)} @pars;
   #   }

   my $tname = AppendType("QuestionText_" . $template_base);
   my $enctext = HtmlEncode($record->{text} || "");
   print Template($tname, %{$question}, %{$record}, enctext=>$enctext);
   }


sub PrintQVar
   { 
   my ($template_base, $question, $record) = @_;

   return unless $record;
   return unless ArgIs("vars");

   my @vars  = ($record->{text} =~ /(\<var.*?\<\/var\>)/gis);
   my $tname = AppendType("QuestionVarText_" . $template_base);
   map {print Template($tname, var=>$_)} @vars;
   }


sub PrintQPar
   { 
   my ($template_base, $question, $record) = @_;

   return unless $record;
   return unless ArgIs("vars");

   #my @pars  = ($record->{text} =~ /(\([^(]+\))/gi);
   my @pars  = map {AggressivelyCleanString($_)} ($record->{text} =~ /(\([^(]+\))/gi);


   my $tname = AppendType("QuestionParText_" . $template_base);
   map {print Template($tname, var=>$_)} @pars;
   }


sub PrintQuestionEnd  
   { 
   my ($question) = @_;

   my $tname = AppendType("QuestionEnd");
   print Template($tname, %{$question});
   }

sub PrintEnd   
   { 
   my ($count) = @_;

   my $tname = AppendType("End");
   print Template($tname, count=>$count);
   }

sub AppendType
   {
   my ($tname) = @_;
   return $tname . (ArgIs("html") ? "_html" : "_txt");
   }

#############################################################################
#                                                                           #
#############################################################################

sub QuestionData
   {
   state $questions     = FetchHash("id"                        , "select * from questions"   );
   state $questiontexts = FetchHash(["questionId", "languageId"], "select * from questiontext where current=1");
   state $ok            = PrepQuestionData ($questions, $questiontexts);

   return ($questions, $questiontexts);
   }

sub PrepQuestionData               
   { 
   my ($questions, $questiontexts) = @_; 

   foreach my $question (values %{$questions})
      {
      my $questiontext = $questiontexts->{$question->{id}} || {};
      foreach my $record (values %{$questiontext})
         {
         $record->{used} = 1;
         $question->{"has_" . $record->{languageId}} = 1;

         $question->{has_var} = 1 if $record->{text} =~ /\<var/i;
         $question->{"has_var_" . $record->{languageId}} = 1 if $record->{text} =~ /\<var/i;
         }
      }
   return 1;
   }

sub AggressivelyCleanString
   {
   my ($string) = @_;

   $string =~ s/<\/?div[^>]*>//gi;                 # remove <div> tags
   $string =~ s/<\/?small[^>]*>//gi;               # remove <small> tags
   $string =~ s/<\/?span[^>]*>//gi;                # remove <span> tags
   $string =~ s/<\/?p[^>]*>//gi;                   # remove <p> tags
   $string =~ s/&nbsp;/ /gi;                       # remove &nbsp;
   $string =~ s/(<br\s*\/>){3,}/<br \/><br \/>/gi; # at most 2 consecutive <br />
   $string =~ s/<\/?b>//gi;                        # remove <b> tags

   return $string;
   }


__DATA__

[Start_txt]
$title
=======================================================================
[QuestionStart_txt]
question:$id
[QuestionText_English_txt]

questiontext:$id (english):
----------------------------------
$text

[QuestionText_Foreign_txt]

questiontext:$id (foreign):
----------------------------------
$text

questiontext:$id (new foreign):
----------------------------------
$text

[QuestionText_English_Encoded_txt]
[QuestionText_Foreign_Encoded_txt]
[QuestionVarText_English_txt]
var: $var
[QuestionVarText_Foreign_txt]
var: $var
[QuestionParText_English_txt]
[QuestionParText_Foreign_txt]
par: $var
[QuestionEnd_txt]
=======================================================================
[End_txt]
($count questions)
[Start_txt2]
$title
-----------------------------------------------------------------------
[QuestionStart_txt2]
question $id: $title
[QuestionText_English_txt2]
($languageId : $id) $text
[QuestionText_Foreign_txt2]
($languageId : $id) $text
[QuestionText_English_Encoded_txt2]
[QuestionText_Foreign_Encoded_txt2]
[QuestionVarText_English_txt2]
var: $var
[QuestionVarText_Foreign_txt2]
var: $var
[QuestionParText_English_txt2]
par: $var
[QuestionParText_Foreign_txt2]
par: $var
[QuestionEnd_txt2]
-----------------------------------------------------------------------
[End_txt2]
($count questions)
[Start_html]
<!DOCTYPE html>
<html>
   <head>
      <style>
      .question {
         position: relative;
         border: 2px solid #888; 
         margin: 4px; 
         padding: 5px;
         border-radius: 5px;
      }
      .qlabel {
         background-color: #eee;
      }
      .qtitle {
         font-size: 1.3em;
      }
      .qtext-e  {background-color: #ddf; padding-bottom: 0.5em}
      .qtext-s  {background-color: #fdd; padding-bottom: 0.5em}
      .qtext-ee {background-color: #eef; padding-bottom: 0.5em; font-size: 0.8em; border-top: 1px solid #888;}
      .qtext-se {background-color: #fee; padding-bottom: 0.5em; font-size: 0.8em}
      .qvar-e   {background-color: #ddf; padding-bottom: 0.2em}
      .qvar-s   {background-color: #fdd; padding-bottom: 0.2em}
      .enc {
      }
      .qtext-label {
         font-size: 0.75em;
         padding-top: 0.5em;
      }
      .qtext-text {
      }

      </style>
   </head>
   <body>
   <h3>$title</h3>
[QuestionStart_html]
      <div class="question">
         <div class="qlabel">question id:$id</div>
         <div class="qtitle">$title</div>
[QuestionVarText_English_html]
         <div class="qvar-e">var: $var</div>
[QuestionVarText_Foreign_html]
         <div class="qvar-s">var: $var</div>
[QuestionParText_English_html]
         <div class="qvar-e">par: $var</div>
[QuestionParText_Foreign_html]
         <div class="qvar-s">par: $var</div>
[QuestionText_English_html]
         <div class="qtext-e">
            <div class="qtext-label">questiontext id:$id  langid:$languageId</div>
            <div class="qtext-text">$text</div>
         </div>
[QuestionText_Foreign_html]
         <div class="qtext-s">
            <div class="qtext-label">questiontext id:$id  langid:$languageId</div>
            <div class="qtext-text">$text</div>
         </div>
[QuestionText_English_Encoded_html]
         <div class="qtext-ee enc">$enctext</div>
[QuestionText_Foreign_Encoded_html]
         <div class="qtext-se enc">$enctext</div>
[QuestionEnd_html]
      </div>
[End_html]
      <div>($count records)</div>
   </body>
</html>
[usage]
QuestionView.pl - Utility for dumping TriVox question string data

USAGE: QuestionView.pl [options]

WHERE: [options] is one or more of:
    -language=9999 . Specify language in addition to english (spanish)
    -all ........... Show all questions
    -e ............. Exclude all but questions that have english text
    -ne ............ Exclude all but questions that dont have english text
    -f ............. Exclude all but questions that have foreign text
    -nf ............ Exclude all but questions that dont have foreign text
    -v ............. Exclude all but questions that have vars
    -nv ............ Exclude all but questions that dont have vars
    -ve ............ Exclude all but questions that have english text vars
    -vf ............ Exclude all but questions that have foreign text vars
    -vne ........... Exclude all but questions that dont have english text vars
    -vnf ........... Exclude all but questions that dont have foreign text vars
    -vars .......... Include vars and parens
    -etext=str ..... Exclude all but questions that have this english text
    -ftext=str ..... Exclude all but questions that have this foreign text
    -id ............ Exclude all but questions with this question id
    -eid ........... Exclude all but questions with this questiontext id
    -fid ........... Exclude all but questions with this questiontext id
    -varsonly ...... Special case: only print <var>s
    -idsonly ....... Special case: only print questionids
    -orphans ....... Special case: print orphaned questiontexts
    -host=foo ...... Set the mysqlhost (localhost)
    -username=foo .. Set the mysqlusername (avocate)
    -password=foo .. Set the mysqlpassword (****************)
    -html .......... Generate html (default is text)

EXAMPLES: 
    QuestionView.pl -lang=portuguese -all
    QuestionView.pl -e -f -v -html
    QuestionView.pl -host=trivox-db.cymcwhoejtz8.us-east-1.rds.amazonaws.com -all
    QuestionView.pl -language=spanish -e -f -ftext="&lt;"

NOTES:
    -language can be set to:
       spanish or 5912 for Spanish
       portuguese or 5265 for Portuguese
[fini]
