#!perl
# 
# QuestionFixMiddle.pl
# 
# This utility is for cleaning up question/questiontext text
# 
# This utility is a middle step in cleaning up the questions when adding a 
#  new foreign language. 
#
# This utility essentially provides the same functionality as the editquestiontext
#  web page utility, with the important distinction that you are working
#  with the raw text.  So basically, you want to use the web page editor to
#  verify and edit questions generally, but there are still some fixups that
#  require this utility.  In particular, The web editors will translate the < > 
#  and & chars to html entities. While theis is what we want 99% of the time,
#  some strings contain ftl code snippets or tags imbedded in strings 
#  intentionally, and you will need this utility to fix them.  Also this util
#  allows you to do search/replace in your editor which can save time.
#
# Specifically, this utility:
#  - Dumps Questions in an editable file. Each question contains the 
#    english, the foreign, and newtext (which is a copy of foreign).
# 
#  - The developer (meaning you), can then edit the file and change
#    whichever newtext entries need editing
# 
#  - The utility can then load the file, and will change the foreign 
#    entries to newtext whenever it finds that you made a change.
# 
#  - There are many filtering options, so you can subset your edit files
#    to certain classes of problems that need certain edit approaches.
# 
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);


MAIN:
   $| = 1;
   ArgBuild("*^language= *^gen *^load *^test " .
            "^e ^ne ^f ^nf ^v ^nv ^ve ^vs ^vne ^vnf *^etext= *^ftext= ^id= ^eid= ^fid= " .
            "*^host= *^username= *^password= *^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();

   my $filename = ArgGet();
   Usage() if ArgIs("help") || !$filename;

   GenPatch ($filename) if ArgIs("gen");

   LoadPatch($filename) if ArgIs("load") || ArgIs("test");

   exit(0);




sub GenPatch
   {
   my ($filename) = @_;

   my ($questions, $questiontexts) = QuestionData(); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   open(my $file, ">", $filename) or die "cant open '$filename'";

   my $count = 0;
   foreach my $id (sort {$a<=>$b} keys %{$questions})
      {
      my $question = $questions->{$id};

      next unless $question->{"has_" . $english_lang_id} && 
                  $question->{"has_" . $foreign_lang_id};

      my $questiontext = $questiontexts->{$id} || {};
      my $qte    = $questiontext->{$english_lang_id};
      my $qts    = $questiontext->{$foreign_lang_id};
      my $etext  = $qte->{text};
      my $stext  = $qts->{text};
      my @evars  = ($etext =~ /(\<var.*?\<\/var\>)/gis);
      my @svars  = ($stext =~ /(\<var.*?\<\/var\>)/gis);
      my @spars  = ($stext =~ /(\([^(]+\))/gi);

      next unless PassesFilters ($id, $questions, $questiontexts);

      print $file "[question:$id:$qte->{id}:$qts->{id}]\n";

      AddWarnings ($file, $stext);

      print $file "[english vars]\n";
      map {print $file "$_\n"} @evars;
      print $file "\n";

      print $file "[questiontext:$id:$qte->{languageId}]\n";
      print $file "$etext\n\n";

      print $file "[foreign vars/pars]\n";
      map {print $file "$_\n"} @svars;
      map {print $file "$_\n"} @spars;
      print $file "\n";

      print $file "[questiontext:$id:$qts->{languageId}]\n";
      print $file "$stext\n\n";

      print $file "[questiontext:$id:newtext]\n";
      print $file "$stext\n\n";

      print $file "[" . "=" x 80 . "]\n";
      $count++;
      }
   print $file "($count questions)\n";
   print "$count questions generated.\n";
   close $file;
   }

sub LoadPatch
   {
   my ($filename) = @_;

   my $language = GetLanguageId();

   my $sections = LoadPatchData($filename);

   my ($record_ct, $change_ct) = (0,0);

   foreach my $key (sort keys %{$sections})
      {
      my ($id,$eid,$sid) = $key =~ /question:(\d+):(\d+):(\d+)/;

      next unless $id && $eid && $sid;

      my $etext = Trim($sections->{"questiontext:$id:1804"});
      my $stext = Trim($sections->{"questiontext:$id:$language"});
      my $ntext = Trim($sections->{"questiontext:$id:newtext"});

      my $changed = $stext ne $ntext;

      print $changed ? "*" : ".";
      UpdateQuestionText($sid, $ntext) if $changed;

      $record_ct++;
      $change_ct++ if $changed;
      }
   print "\n";
   print "$record_ct foreign questiontext records examined.\n";
   print "$change_ct foreign questiontext records modified.\n";
   }


sub LoadPatchData
   {
   my ($filename) = @_;
   open (my $file, "<", $filename) or die "cant open '$filename'";

   my $sections = {};
   my $key = "nada";
   while (my $line = <$file>)
      {
      my ($section) = $line =~ /^\[(\S+)\]/;
      $key = $section || $key;
      $sections->{$key} = ""      if $section;
      $sections->{$key} .= $line  if !$section;
      }
   return $sections;
   }


sub PassesFilters
   {
   my ($id, $questions, $questiontexts) = @_;

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   my $question = $questions->{$id};
   my $questiontext = $questiontexts->{$id} || {};
   my $qte   = $questiontext->{$english_lang_id};
   my $qts   = $questiontext->{$foreign_lang_id};
   my $etext = $qte->{text};
   my $stext = $qts->{text};

   return PassesQuestionFilters ($question)  &&
          PassesTextFilters ($qte->{text}, $qts->{text}) &&
          PassesIdFilters ($id, $qte->{id}, $qts->{id});
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
   return 1 unless ArgIs($pname);
   for (my $i=0; my $match = ArgGet($pname, $i); $i++) 
      {
      return 1 if $id == $match;
      }
   return 0;
   }


sub AddWarnings
   {
   my ($file, $text) = @_;

   my $obraces = () = $text =~ /\</g;
   my $cbraces = () = $text =~ /\>/g;
   my $sparens = () = $text =~ /\'/g;  #'
   my $dparens = () = $text =~ /\"/g;  #"

   print $file "$obraces open braces and $cbraces closebraces!\n" if ($obraces != $cbraces);
   print $file "odd number ($sparens) of single parens!\n" if $sparens % 2;
   print $file "odd number ($dparens) of double parens!\n" if $dparens % 2;
   }


#############################################################################
#                                                                           #
#############################################################################

sub QuestionData
   {
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   my $questions     = FetchHash("id"                        , "select * from questions"   );
   my $questiontexts = FetchHash(["questionId", "languageId"], "select * from questiontext where current=1");
   my $ok            = PrepQuestionData ($questions, $questiontexts);

   return ($questions, $questiontexts);
   }


sub UpdateQuestionText
   {
   my ($id, $text) = @_;

   my $sql = "update questionnaires.questiontext set text=? where id=$id";
   ExecSQL ($sql, $text) unless ArgIs("test");
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


__DATA__

[usage]
QuestionFixMiddle.pl - Utility for cleaning up the foreign QuestionText

USAGE: QuestionFixMiddle.pl [options] patchfile

WHERE: [options] is one or more of:
    -gen ............. Generate a patch file.
    -load ............ Load a patch file, updating the db.
    -test ............ Load a patch file, but dont update the db.
    -language=5912 ... Specify language to gen or load (5912 is default).

Additional options for -gen:
    -e ............... Exclude all but questions that have english text
    -ne .............. Exclude all but questions that dont have english text
    -s ............... Exclude all but questions that have spanish text
    -ns .............. Exclude all but questions that dont have spanish text
    -v ............... Exclude all but questions that have vars
    -nv .............. Exclude all but questions that dont have vars
    -ve .............. Exclude all but questions that have english text vars
    -vne ............. Exclude all but questions that dont have english text vars
    -vs .............. Exclude all but questions that have spanish text vars
    -vns ............. Exclude all but questions that dont have spanish text vars
    -etext=str ....... Exclude all but questions that have this english text
    -stext=str ....... Exclude all but questions that have this spanish text
    -id .............. Exclude all but questions with this question id
    -eid ............. Exclude all but questions with this questiontext id
    -sid ............. Exclude all but questions with this questiontext id

    patchfile is the name of the input/output file.

NOTES:
   1> Generate a patchfile
   
      QuestionFixMiddle.pl -gen patch.txt

      This generates a file containing all questions that have 
      questiontext in both english and spanish (or whichever you 
      specified using -language)

   2> Edit the file, change the newtext entries as needed

   3> load the patchfile

      QuestionFixMiddle.pl -load patch.txt

   Each newtext that was modified in the file will be modified in 
   the database
