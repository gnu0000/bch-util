#!perl
#
# UifieldFixFirst.pl 
# This utility is for cleaning up Uifield/langui text
#
# Craig Fitzgerald

# This utility is the first step in cleaning up the uifields when adding a 
#  new foreign language. 
#
# Specifically, this utility strips various tags and replaces (varname) in 
#  the foreign text with the corresponding <var>varname</var> from the 
#  english text.
#
# As a secondary feature, this utility can also be used to dump what the
#  changes would be (using -test and -debug options)
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

   CleanupLanguiText();
   exit(0);


sub CleanupLanguiText
   {
   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   print "Checking for Duplicates\n";
   RemoveDuplicates();

   print "Cleaning up tags and vars and stuff\n";
   CleanupTagsAndVars();
   }

#############################################################################
#                                                                           #
#############################################################################

sub RemoveDuplicates
   {
   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();
   my $stats = {delete_count=>0, problem_count=>0};
   my $languis = FetchArray("select * from langui where langId=$foreign_lang_id order by id");
   my %hold;
   foreach my $langui (@{$languis})
      {
      my $key = $langui->{uiId} . "_" . $langui->{langId};
      RemoveDuplicate ($hold{$key}, $langui, $stats) if exists $hold{$key};
      $hold{$key} = $langui unless exists $hold{$key};
      $stats->{count}++;
      }
   print "Duplicates removed: $stats->{delete_count}, Duplicates remaining: $stats->{problem_count}\n\n";
   }


sub RemoveDuplicate
   {
   my ($langui1, $langui2, $stats) = @_;

   $stats->{duplicate_count}++;

   if ($langui1->{value} eq $langui2->{value})
      {
      ExecSQL ("delete from langui where id=?", $langui2->{id}) if ArgIs("doit");
      print "Will remove responsetext id: $langui2->{id} (its a dup of $langui1->{id})\n" unless ArgIs("doit");
      $stats->{delete_count}++;
      }
   else
      {
      print "response text $langui2->{id} is a duplicate of $langui1->{id} but the text is different!\n";
      DumpDup ($langui1, $langui2) if ArgIs("debug");
      $stats->{problem_count}++;
      }      
   }

#############################################################################
#                                                                           #
#############################################################################

sub CleanupTagsAndVars
   {
   my ($uifields, $languis) = UiFieldData(); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();
   my ($record_ct, $change_ct) = (0,0);

   foreach my $id (sort {$a<=>$b} keys %{$uifields})
      {
      my $uifield = $uifields->{$id};
      next unless $uifield->{"has_". $english_lang_id} && 
                  $uifield->{"has_". $foreign_lang_id};

      my $langui = $languis->{$id} || {};

      my $etext = $langui->{$english_lang_id}->{value};
      my $stext = $langui->{$foreign_lang_id}->{value};
      my $id    = $langui->{$foreign_lang_id}->{id};

      my $isenglish = ($english_lang_id == $foreign_lang_id);

      my $ntext = CleanupJunk($stext, $isenglish);

      my @vars  = ($etext =~ /(\<var.*?\<\/var\>)/gis);
      my @pars  = ($ntext =~ /(\([^(]+\))/gi);

      $ntext = FixVars($ntext, @vars) unless $isenglish;

      $ntext = MatchTrim($ntext, $etext) unless $isenglish;

      my $changed = $ntext ne $stext;

      print $changed ? "*" : "." unless ArgIs("debug");

      DumpChange ($id, $stext, $ntext) if $changed && ArgIs("debug");
      UpdateLangui($id, $ntext)  if $changed && ArgIs("doit");

      $record_ct++;
      $change_ct++ if $changed;
      }
   print "\n";
   print "$record_ct foreign uifield records examined.\n";
   print "$change_ct foreign uifield records modified.\n";
   }


# We make the assumption that the english text was added by the developers
# who know what they are doing, and the foreign language was done by the 
# translators who don't.  So we are permissive about the english text
# and more strict about cleaning up foreign text.
#
#
#
sub CleanupJunk
   {
   my ($string, $isenglish) = @_;

   $string =~ s/<\/?div[^>]*>//gi  unless $isenglish; # remove <div> tags
   $string =~ s/<\/?span[^>]*>//gi unless $isenglish; # remove <span> tags
#  $string =~ s/<\/?p[^>]*>//gi;   unless $isenglish; # remove <p> tags
   $string =~ s/&nbsp;/ /gi;                          # remove &nbsp;
   $string =~ s/(<br\s*\/?>){3,}/<br \/><br \/>/gi;   # at most 2 consecutive <br />

   # leaving in:
   # <string>
   # <br />
   # <hr />
   # <acronym>
   # <em>
   #return Trim($string);
   return $string;
   }


# return $ntext modified so that the leading and trailing
# whitespace matches the english version of the text
#
sub MatchTrim
   {
   my ($ntext, $etext) = @_;

   my ($prestr, $poststr) = $etext =~ /^([\r\n\s]*).*?([\r\n\s]*)$/s;

   return $prestr . Trim($ntext) .  $poststr;
   }



sub DumpDup
   {
   my ($langui1, $langui2) = @_;

   print "\n-------------[$langui1->{id}]--------------------------------------------\n";
   print "'$langui1->{value}'\n";
   print "\n-------------[$langui2->{id}]--------------------------------------------\n";
   print "'$langui2->{value}'\n";
   print "----------------------------------------------------------------\n";
   }

sub DumpChange
   {
   my ($id, $stext, $ntext) = @_;

   print "\n-------------[$id]--------------------------------------------\n";
   print "from:'$stext'\n";
   print "----------------------------------------------------------------\n";
   print "to  :'$ntext'\n";
   print "----------------------------------------------------------------\n";
   }

#############################################################################
#############################################################################

sub UiFieldData
   {
   my $uifields = FetchHash("id"              , "select * from uifields");
   my $languis  = FetchHash(["uiId", "langId"], "select * from langui");
   my $ok       = PrepUiFieldData ($uifields, $languis);

   return ($uifields, $languis);
   }


sub UpdateLangui
   {
   my ($id, $text) = @_;

   my $sql = "update langui set value=? where id=$id";
   ExecSQL ($sql, $text);
   }


sub PrepUiFieldData
   { 
   my ($uifields, $languis) = @_; 

   foreach my $uifield (values %{$uifields})
      {
      my $langui = $languis->{$uifield->{id}} || {};
      foreach my $record (values %{$langui})
         {
         $record->{used} = 1;
         $uifield->{"has_" . $record->{langId}} = 1;
         $uifield->{has_var} = 1 if $record->{value} =~ /\<var/i;
         $uifield->{"has_var_" . $record->{langId}} = 1 if $record->{value} =~ /\<var/i;
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
   $language = 5912 if $language =~ /span/i;
   $language = 5265 if $language =~ /port/i;
   $language = 1804 if $language =~ /engl/i;

   return (1804, $language);
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
UifieldFixFirst.pl - Initial utility for cleaning up uifields

USAGE: UifieldFixFirst.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick which language were cleaning (spanish|portuguese)
   -test .............. run, but dont actually update the database
   -doit .............. run, actually update the database
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug.............. Use with -test to dump changes

EXAMPLES: 
   UifieldFixFirst.pl -test
   UifieldFixFirst.pl -doit -language=english
   UifieldFixFirst.pl -doit -language=spanish
   UifieldFixFirst.pl -doit -lang=portuguese
   UifieldFixFirst.pl -test -host=test.me.com -username=bubba -password=password

NOTES:
   The following modifications are applied to all active langui.value fields
   in the specified language:

   - Duplicate records are removed.
   - <div> tags are stripped   
   - <span> tags are stripped   
   - <p> tags are stripped   
   - &nbsp; tags are replaced with a space
   - excessive <br /> tags are stripped (at most 2 consecutive)
   - Leading / Trailing space is trimmed

   The following modifications are applied to all active langui.value fields
   if the language is not english:

   - If the text has a '(first name)' or one of a hundred permutations
      like it, and if the english version of the text has a <var> tag
      that is named firstname or childfirstname or something like it,
      then the '(first name)' is replaced with the var tag
   - If the text has a '(ident)', and if the english version of the 
      text has a <var>ident</var> tag, then the '(ident)' is replaced 
      with the var tag
[fini]