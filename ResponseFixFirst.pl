#!perl
#
# ResponseFixFirst.pl 
#
# This utility is for cleaning up responsetext text
#
# This utility is the first step in cleaning up the responsetext when adding a 
#  new foreign language. 
#
# Specifically, this utility:
# 1> Removes duplicate records (if the text is the same)
# 2> strips various tags
#
#
use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);

my $STATS = {original_count  => 0,
             duplicate_count => 0,
             delete_count    => 0,
             problem_count   => 0,
             new_count       => 0,
             change_count    => 0};

MAIN:
   $| = 1;
   ArgBuild("*^test *^doit *^language= *^debug *^host= *^username= *^password= *^help");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !(ArgIs("test") || ArgIs("doit"));

   CleanupResponseText();
   exit(0);


# spanish only for now
#
sub CleanupResponseText
   {
   Connection("questionnaires", ArgsGet("host", "username", "password"));

   print "Checking for Duplicates\n";
   RemoveDuplicates();

   print "Cleaning up tags and vars\n";
   CleanupTagsAndVars();

   PrintStats();
   }
   
#############################################################################
#                                                                           #
#############################################################################

sub RemoveDuplicates
   {
   my $languageid = GetLanguageId();

   my $rts = FetchArray("select * from responsetext where languageId=$languageid and current=1 order by id");
   $STATS->{original_count} = scalar @{$rts};

   my %hold;
   foreach my $rt (@{$rts})
      {
      my $key = $rt->{responseId} . "_" . $rt->{languageId};
      RemoveDuplicate ($hold{$key}, $rt) if exists $hold{$key};
      $hold{$key} = $rt unless exists $hold{$key};
      }
   }

sub RemoveDuplicate
   {
   my ($rt1, $rt2) = @_;

   $STATS->{duplicate_count}++;

   if ($rt1->{text} eq $rt2->{text})
      {
      ExecSQL ("delete from responsetext where id=?", $rt2->{id}) if ArgIs("doit");
      print "Will remove responsetext id: $rt2->{id} (its a dup of $rt1->{id})\n" unless ArgIs("doit");
      $STATS->{delete_count}++;
      }
   else
      {
      print "response text $rt2->{id} is a duplicate of $rt1->{id} but the text is different!\n";
      DumpChange ($rt1, $rt2->{text}) if ArgIs("debug");
      $STATS->{problem_count}++;
      }      
   }


#############################################################################
#                                                                           #
#############################################################################

sub CleanupTagsAndVars
   {
   my $languageid = GetLanguageId();
   my $rts = FetchArray("select * from responsetext where languageId=$languageid and current=1 order by id");
   $STATS->{new_count} = scalar @{$rts};

   foreach my $rt (@{$rts})
      {
      $rt->{ntext} = CleanupJunk($rt->{text});
      CleanupRecordVars($rt);

      my $changed = $rt->{ntext} ne $rt->{text};

      print $changed ? "*" : "." unless ArgIs("debug");

      DumpChange ($rt, $rt->{ntext})        if $changed && ArgIs("debug");
      UpdateResponseText($rt, $rt->{ntext}) if $changed && ArgIs("doit");

      $STATS->{change_count}++ if $changed;
      }
   }

#sub CleanupRecordTags
#   {
#   my ($rt) = @_;
#
#   my $ntext = CleanupJunk($rt->{text});
#
#   my $changed = $ntext ne $rt->{text};
#
#   print $changed ? "*" : "." unless ArgIs("debug");
#
#   DumpChange ($rt, $ntext)         if $changed && ArgIs("debug");
#   UpdateResponseText($rt, $ntext)  if $changed && ArgIs("doit");
#
#   $STATS->{change_count}++ if $changed;
#   }


sub CleanupJunk
   {
   my ($string) = @_;

   $string =~ s/<\/?div[^>]*>//gi;                  # remove <div> tags
   $string =~ s/<\/?span[^>]*>//gi;                 # remove <span> tags
#  $string =~ s/<\/?p[^>]*>//gi;                    # remove <p> tags
   $string =~ s/&nbsp;/ /gi;                        # remove &nbsp;
   $string =~ s/(<br\s*\/?>){3,}/<br \/><br \/>/gi; # at most 2 consecutive <br />

   # leaving in: <string> <br /> <hr /> <acronym> <em>
   return Trim($string);
   }


sub CleanupRecordVars
   {
   my ($rt) = @_;

   return if GetLanguageId() == 1804;

   my $ert = FetchRow("select * from responsetext where responseId=$rt->{responseId} and languageId=1804 and current=1");

   return "There is no english version for response $rt->{responseId}!\n" unless $ert;

   my @vars  = ($ert->{text} =~ /(\<var.*?\<\/var\>)/gis);
   my @pars  = ($rt->{ntext} =~ /(\([^(]+\))/gi);
   
   return unless scalar @vars; # no source vars to use
   return unless scalar @pars; # no dest vars to fix

   $rt->{ntext} = FixVars($rt->{ntext}, @vars);
   }




#############################################################################
#                                                                           #
#############################################################################


sub UpdateResponseText
   {
   my ($rt, $text) = @_;

   ExecSQL ("update responsetext set text=? where id=$rt->{id}", $text);
   }


sub DumpChange
   {
   my ($rt, $text) = @_;

   print "\n-------------[id:$rt->{id},responseId:$rt->{responseId}]------------------------\n";
   print "from: $rt->{text}\n";
   print "-----------------------------------------------------------\n";
   print "to  : $text\n";
   print "-----------------------------------------------------------\n";
   }

#############################################################################
#                                                                           #
#############################################################################

sub PrintStats
   {
   print "\n";
   print "Original count : $STATS->{original_count}\n";
   print "Duplicate count: $STATS->{duplicate_count}\n";
   print "Delete count   : $STATS->{delete_count}\n";
   print "Problem count  : $STATS->{problem_count}\n";
   print "Change count   : $STATS->{change_count}\n";
   }

#############################################################################
#                                                                           #
#############################################################################

# Return an array containing the two languages we're working with
# The first is always english, the second depends on the -language= param
# and defaults to spanish
#
sub GetLanguageId
   {
   my $language = ArgIs("language") ? ArgGet("language") : 1804;
   $language = 1804 if $language =~ /engl/i;
   $language = 5912 if $language =~ /span/i;
   $language = 5265 if $language =~ /port/i;
   return $language;
   }


#############################################################################
#                                                                           #
#############################################################################


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
ResponseFixFirst.pl - Initial utility for cleaning up responsetext

USAGE: ResponseFixFirst.pl [options]

WHERE: [options] is one or more of:
   -language=english .. Pick which language were cleaning (english|spanish|portuguese)
   -test .............. run, but dont actually update the database
   -doit .............. run, actually update the database
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug.............. Use with -test to dump changes

EXAMPLES: 
   ResponseFixFirst.pl -test
   ResponseFixFirst.pl -doit -language=1804
   ResponseFixFirst.pl -doit -language=spanish
   ResponseFixFirst.pl -test -debug -lang=portuguese
   ResponseFixFirst.pl -test -host=test.me.com -user=bubba -pass=password

NOTES:
   The following modification are applied to all active responsetext.text 
   fields in the specified language:

   - Duplicate records are removed.
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