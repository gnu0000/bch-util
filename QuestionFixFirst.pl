#!perl
#
# QuestionFixFirst.pl 
# This utility is for cleaning up question/questiontext text
#
# Craig Fitzgerald

# This utility is the first step in cleaning up the questiontext when adding a 
#  new foreign language. 
#
# Specifically, this utility strips various tags and replaces (varname) in 
#  the foreign text with the corresponding <var>varname</var> from the 
#  english text.
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.


use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);


MAIN:
   $| = 1;
   ArgBuild("*^test *^doit *^language= *^host= *^username= *^password= *^help *^debug");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !(ArgIs("test") || ArgIs("doit"));

   FixForeignText ();
   exit(0);


# Return an array containing the two languages we're working with
# The first is always english, the second depends on the -language= param
# and defaults to spanish
#
sub GetLanguageIds
   {
   my $language = ArgIs("language") ? ArgGet("language") : 5912;
   $language = 1804 if $language =~ /engl/i;
   $language = 5912 if $language =~ /span/i;
   $language = 5265 if $language =~ /port/i;

   return (1804, $language);
   }


sub FixForeignText
   {
   my ($questions, $questiontexts) = QuestionData(); 


   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();
   my ($record_ct, $change_ct) = (0,0);

   foreach my $id (sort {$a<=>$b} keys %{$questions})
      {
      my $question = $questions->{$id};
      next unless $question->{"has_". $english_lang_id} && 
                  $question->{"has_". $foreign_lang_id};

      my $questiontext = $questiontexts->{$id} || {};

      my $etext = $questiontext->{$english_lang_id}->{text};
      my $stext = $questiontext->{$foreign_lang_id}->{text};
      my $qtid  = $questiontext->{$foreign_lang_id}->{id};

      my $ntext = CleanupJunk($stext);

      my @vars  = ($etext =~ /(\<var.*?\<\/var\>)/gis);
      my @pars  = ($ntext =~ /(\([^(]+\))/gi);

      $ntext = FixVars($ntext, @vars);

      my $changed = $ntext ne $stext;

      print $changed ? "*" : "." unless ArgIs("debug");

      DumpChange ($qtid, $stext, $ntext) if $changed && ArgIs("debug");
      UpdateQuestionText($qtid, $ntext)  if $changed && ArgIs("doit");

      $record_ct++;
      $change_ct++ if $changed;
      }
   print "\n";
   print "$record_ct foreign questiontext records examined.\n";
   print "$change_ct foreign questiontext records modified.\n";
   }


sub CleanupJunk
   {
   my ($string) = @_;

   $string =~ s/<\/?\s*div[^>]*>//gi;                  # remove <div> tags
   $string =~ s/<\/?\s*span[^>]*>//gi;                 # remove <span> tags
#  $string =~ s/<\/?\s*p[^>]*>//gi;                    # remove <p> tags
   $string =~ s/&nbsp;/ /gi;                        # remove &nbsp;
   $string =~ s/(<br\s*\/?>){3,}/<br \/><br \/>/gi; # at most 2 consecutive <br />

   # leaving in:
   # <string>
   # <br />
   # <hr />
   # <acronym>
   # <em>
   return Trim($string);
   }


sub DumpChange
   {
   my ($qtid, $stext, $ntext) = @_;

   print "\n-------------[$qtid]------------------------\n";
   print "from: [$stext]\n";
   print "--------------------------------------------\n";
   print "to  : [$ntext]\n";
   print "--------------------------------------------\n";
   }



#############################################################################
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
   ExecSQL($sql, $text);
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


# look at the names in each var, if we find one that matches $name we return it
# otherwise we return blank
#
sub SelectVarByName
   {
   my ($name, @vars) = @_;

   return "" unless scalar @vars;
   foreach my $var (@vars)
      {
      my ($varname) = $var =~ />(.*)<\/var>/i;

      return $var if $varname && $varname =~ /$name/i;
      }
   return "";
   }


# this fn is down here because my editor hates it
#
sub FixVars
   {
   my ($string, @vars) = @_;
   
   return $string unless scalar @vars;

   # any version of (firstname) (first name) ( first name ) etc....
   # is replaced with first english <var> named firstname or childfirstname
   my $var = SelectVarByName("firstname", @vars) || SelectVarByName("childfirstname", @vars);

   $string =~ s/(\(s*first\s*name('s)?\s*\))/$var/gi if $var;

   # next well replace any (foo) with a matching <var>foo</var>
   #
   my @varnames = qw(
         1172 2866 2995 3003 3011 3019 6418 6420 address1 address2 childFirstName
         city compensation DUMMY_AUX_VERB END_QUESTION_UI_TEXT_KEY firstName
         INSURANCE_CHARGES location months state SUBJECT supportEmail zip);

   foreach my $varname (@varnames)
      {
      my $var = SelectVarByName($varname, @vars);

      #debug
      my $initial = $string;

      $string =~ s/(\(s*$varname\s*\))/$var/gi if $var;

      #debug
      print "replaced a var named '$varname'\n" if ($initial ne $string);
      }

   ## any version of (firstname) (first name) ( first name ) etc....
   ## is replaced with first english <var>
   #my $var = $vars[0];
   #$string =~ s/(\(s*first\s*name('s)?\s*\))/$var/gi;

   # any version of ( )
   # is replaced with first english <var>
   # $string =~ s/(\([^(]+\))/$var/gi;

   return $string;
   }

__DATA__

[usage]
QuestionFixFirst.pl - Initial utility for cleaning up questiontext

USAGE: QuestionFixFirst.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick which language were cleaning (spanish|portuguese)
   -test .............. run, but dont actually update the database
   -doit .............. run, actually update the database
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug.............. Use with -test to dump changes

EXAMPLES: 
   QuestionFixFirst.pl -test
   QuestionFixFirst.pl -doit -language=spanish
   QuestionFixFirst.pl -doit -lang=portuguese
   QuestionFixFirst.pl -test -host=test.me.com -user=bubba -pass=password

NOTES:
   The following modification are applied to all active questiontext.text 
   fields in the specified language:

   - <div> tags are stripped   
   - <span> tags are stripped   
   - <p> tags are stripped   
   - &nbsp; tags are replaced with a space
   - excessive <br /> tags are stripped (at most 2 consecutive)
   - Leading / Trailing space is trimmed
   - If the text has a '(first name)' or one of a hundred permutations
      like it, and if the english version of the text has a <var> tag
      that is named firstname or childfirstname or something like it,
      then the '(first name)' is replaced with the var tag
   - If the text has a '(ident)', and if the english version of the 
      text has a <var>ident</var> tag, then the '(ident)' is replaced 
      with the var tag
[fini]