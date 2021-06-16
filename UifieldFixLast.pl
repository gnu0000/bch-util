#!perl
#
# UifieldFixLast.pl
# This utility is for cleaning up Uifield/langui text
#
# Craig Fitzgerald

# This utility is the last step in cleaning up the uifields when adding a 
#  new foreign language. 
#
# Specifically, this utility:
#  -Looks for and replaces UTF-8 bytecode sequences and replaces them with html
#    entities.
#
#  -Looks for certain html entities (&amp; &lt; &gt;) and replaces them with the
#    character. (This is necessary because the text sometimes contains template code)
#
#  As a secondary feature, this utility can be used to dump the hex codes of
#    the non ascii characters used in the text
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.


use warnings;
use strict;
use HTML::Entities;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);


MAIN:
   $| = 1;
   ArgBuild("*^language= ^test ^doit ^id= *^host= *^username= *^password= ^help ^debug ^debug2");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !(ArgIs("test") || ArgIs("doit"));

   FixLanguiCharset();
   exit(0);



sub FixLanguiCharset
   {
   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   my $languageid = GetLanguageId();
   my $languis = GetLanguis($languageid);

   my ($record_ct, $change_ct) = (0, 0);
   foreach my $langui (@{$languis})
      {
      next if ArgIs("id") && (ArgGet("id") != $langui->{id});

      my $old_text = $langui->{value};
      my $new_text = FixText($old_text);
      my $changed  = $new_text ne $old_text;

      print $changed ? "*" : "." unless ArgIs("debug") || ArgIs("debug2");
      UpdateLangui($langui->{id}, $new_text)      if $changed && ArgIs("doit" );
      DumpLangui ($langui->{id}, $old_text, $new_text) if $changed && ArgIs("debug");
      DumpFunkyText ($langui)                          if ArgIs("debug2");

      $record_ct++;
      $change_ct++ if $changed;
      }
   print "\n";
   print "$record_ct foreign langui records examined.\n";
   print "$change_ct foreign langui records modified.\n";
   }


sub FixText
   {
   my ($text) = @_;

   $text =~ s/\xC2\x{2019}/\x27/g;
   $text =~ s/\xC2\x{2026}/.../g;
   $text =~ s/\xC2\x{201C}/\x22/g;
   $text =~ s/\xC2\x{201D}/\x22/g;

# utf-8 chars to 8859-1 characters
#
#   $text =~ s/\xC2\xBF/\xBF/; # &iquest;
#   $text =~ s/\xC3\x93/\xD3/; # &Oacute;
#   $text =~ s/\xC3\xA0/\xE0/; # &agrave;
#   $text =~ s/\xC3\xA1/\xE1/; # &aacute;
#   $text =~ s/\xC3\xA3/\xE3/; # &atilde;
#   $text =~ s/\xC3\xA7/\xE7/; # &ccedil;
#   $text =~ s/\xC3\xA9/\xE9/; # &eacute;
#   $text =~ s/\xC3\xAA/\xEA/; # &ecirc;
#   $text =~ s/\xC3\xAD/\xED/; # &iacute;
#   $text =~ s/\xC3\xB1/\xF1/; # &ntilde;
#   $text =~ s/\xC3\xB3/\xF3/; # &oacute;
#   $text =~ s/\xC3\xB5/\xF5/; # &otilde;
#   $text =~ s/\xC3\xBA/\xFA/; # &uacute;

# utf-8 chars to html entities
#
#   $text =~ s/\xC2\xBF/&iquest;/g; # 
#   $text =~ s/\xC3\x93/&Oacute;/g; # 
#   $text =~ s/\xC3\xA0/&agrave;/g; # 
#   $text =~ s/\xC3\xA1/&aacute;/g; # 
#   $text =~ s/\xC3\xA3/&atilde;/g; # 
#   $text =~ s/\xC3\xA7/&ccedil;/g; # 
#   $text =~ s/\xC3\xA9/&eacute;/g; # 
#   $text =~ s/\xC3\xAA/&ecirc;/g;  # 
#   $text =~ s/\xC3\xAD/&iacute;/g; # 
#   $text =~ s/\xC3\xB1/&ntilde;/g; # 
#   $text =~ s/\xC3\xB3/&oacute;/g; # 
#   $text =~ s/\xC3\xB5/&otilde;/g; # 
#   $text =~ s/\xC3\xBA/&uacute;/g; # 

# latin1 chars to html entities;
#
   #$text = encode_entities($text);
   $text =~ s/\xA0/&nbsp;/g;
   $text =~ s/\xA1/&iexcl;/g;
   $text =~ s/\xA2/&cent;/g;
   $text =~ s/\xA3/&pound;/g;
   $text =~ s/\xA4/&curren;/g;
   $text =~ s/\xA5/&yen;/g;
   $text =~ s/\xA6/&brkbar;/g;
   $text =~ s/\xA7/&sect;/g;
   $text =~ s/\xA8/&uml;/g;
   $text =~ s/\xA9/&copy;/g;
   $text =~ s/\xAA/&ordf;/g;
   $text =~ s/\xAB/&laquo;/g;
   $text =~ s/\xAC/&not;/g;
   $text =~ s/\xAD/&shy;/g;
   $text =~ s/\xAE/&reg;/g;
   $text =~ s/\xAF/&macr;/g;
   $text =~ s/\xB0/&deg;/g;
   $text =~ s/\xB1/&plusmn;/g;
   $text =~ s/\xB2/&sup2;/g;
   $text =~ s/\xB3/&sup3;/g;
   $text =~ s/\xB4/&acute;/g;
   $text =~ s/\xB5/&micro;/g;
   $text =~ s/\xB6/&para;/g;
   $text =~ s/\xB7/&middot;/g;
   $text =~ s/\xB8/&cedil;/g;
   $text =~ s/\xB9/&sup1;/g;
   $text =~ s/\xBA/&ordm;/g;
   $text =~ s/\xBB/&raquo;;/g;
   $text =~ s/\xBC/&frac14;/g;
   $text =~ s/\xBD/&frac12;/g;
   $text =~ s/\xBE/&frac34;/g;
   $text =~ s/\xBF/&iquest;/g;
   $text =~ s/\xC0/&Agrave;/g;
   $text =~ s/\xC1/&Aacute;/g;
   $text =~ s/\xC2/&Acirc;/g;
   $text =~ s/\xC3/&Atilde;/g;
   $text =~ s/\xC4/&Auml;/g;
   $text =~ s/\xC5/&Aring;/g;
   $text =~ s/\xC6/&AElig;/g;
   $text =~ s/\xC7/&Ccedil;/g;
   $text =~ s/\xC8/&Egrave;/g;
   $text =~ s/\xC9/&Eacute;/g;
   $text =~ s/\xCA/&Ecirc;/g;
   $text =~ s/\xCB/&Euml;/g;
   $text =~ s/\xCC/&Igrave;/g;
   $text =~ s/\xCD/&Iacute;/g;
   $text =~ s/\xCE/&Icirc;/g;
   $text =~ s/\xCF/&Iuml;/g;
   $text =~ s/\xD0/&ETH;/g;
   $text =~ s/\xD1/&Ntilde;/g;
   $text =~ s/\xD2/&Ograve;/g;
   $text =~ s/\xD3/&Oacute;/g;
   $text =~ s/\xD4/&Ocirc;/g;
   $text =~ s/\xD5/&Otilde;/g;
   $text =~ s/\xD6/&Ouml;/g;
   $text =~ s/\xD7/&times;/g;
   $text =~ s/\xD8/&Oslash;/g;
   $text =~ s/\xD9/&Ugrave;;/g;
   $text =~ s/\xDA/&Uacute;/g;
   $text =~ s/\xDB/&Ucirc;/g;
   $text =~ s/\xDC/&Uuml;/g;
   $text =~ s/\xDD/&Yacute;/g;
   $text =~ s/\xDE/&THORN;/g;
   $text =~ s/\xDF/&szlig;/g;
   $text =~ s/\xE0/&agrave;/g;
   $text =~ s/\xE1/&aacute;/g;
   $text =~ s/\xE2/&acirc;/g;
   $text =~ s/\xE3/&atilde;/g;
   $text =~ s/\xE4/&auml;/g;
   $text =~ s/\xE5/&aring;/g;
   $text =~ s/\xE6/&aelig;/g;
   $text =~ s/\xE7/&ccedil;/g;
   $text =~ s/\xE8/&egrave;/g;
   $text =~ s/\xE9/&eacute;/g;
   $text =~ s/\xEA/&ecirc;/g;
   $text =~ s/\xEB/&euml;/g;
   $text =~ s/\xEC/&igrave;/g;
   $text =~ s/\xED/&iacute;/g;
   $text =~ s/\xEE/&icirc;/g;
   $text =~ s/\xEF/&iuml;/g;
   $text =~ s/\xF0/&eth;/g;
   $text =~ s/\xF1/&ntilde;/g;
   $text =~ s/\xF2/&ograve;/g;
   $text =~ s/\xF3/&oacute;/g;
   $text =~ s/\xF4/&ocirc;/g;
   $text =~ s/\xF5/&otilde;/g;
   $text =~ s/\xF6/&ouml;/g;
   $text =~ s/\xF7/&divide;/g;
   $text =~ s/\xF8/&oslash;/g;
   $text =~ s/\xF9/&ugrave;/g;
   $text =~ s/\xFA/&uacute;/g;
   $text =~ s/\xFB/&ucirc;/g;
   $text =~ s/\xFC/&uuml;/g;
   $text =~ s/\xFD/&yacute;/g;
   $text =~ s/\xFE/&thorn;/g;
   $text =~ s/\xFF/&yuml;/g;


# selected html entities to the original character
#
   $text =~ s/&lt;/</g;   # <
   $text =~ s/&gt;/>/g;   # >
   $text =~ s/&amp;/&/g;  # &

   return $text;
   }

sub GetLanguis
   {
   my ($languageid) = @_;

   my $sql = "select * from langui where langId=$languageid";
   my $languis = FetchArray($sql);
   return $languis;
   }

sub UpdateLangui
   {
   my ($id, $text) = @_;

   my $sql = "update langui set value=? where id=$id";
   ExecSQL ($sql, $text);
   }

sub DumpLangui  
   {
   my ($id, $old_text, $new_text) = @_;

   print "\n-------------[$id]------------------------\n";
   print "from: $old_text\n";
   print "--------------------------------------------\n";
   print "to  : $new_text\n";
   print "--------------------------------------------\n";
   }

sub DumpFunkyText
   {
   my ($langui) = @_;

   my ($id, $uiid, $text) = ($langui->{id}, $langui->{uiId}, $langui->{value});

   my @chars = split(//, $text);
   my ($header_printed, $last_was_funky)  = (0, 0);
   for (my $idx=0; $idx<scalar @chars; $idx++)
      {
      my $char = $chars[$idx];
      my $val = ord($char);
      if ($val < 128)
         {
         $last_was_funky = 0;
         next;
         }
      else
         {
         print sprintf ("[uiid:%4.4d, id:%5.5d]", $uiid, $id) unless $header_printed++;
         print " " unless $last_was_funky;
         print sprintf ("%2.2x", $val);
         $last_was_funky = 1;
         }
      }
   print "\n" if $header_printed;
   }

sub GetLanguageId
   {
   my $language = ArgIs("language") ? ArgGet("language") : 5912;
   $language = 5912 if $language =~ /span/i;
   $language = 5265 if $language =~ /port/i;
   $language = 1804 if $language =~ /engl/i;

   return $language;
   }


__DATA__
[usage]
UifieldFixLast.pl - Final utility for cleaning up uifields

USAGE: UifieldFixLast.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick language to clean (english|spanish|portuguese)
   -test .............. Run, but dont actually update the database
   -doit .............. Run, actually update the database
   -id=languiid ....... Only process this record
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug ............. (with -test) show string changes
   -debug2 ............ (with -test) show utf-8 char bytes

EXAMPLES:
   UifieldFixLast.pl -lang=spanish -test
   UifieldFixLast.pl -lang=spanish -test -debug
   UifieldFixLast.pl -lang=spanish -doit

NOTES:
   The following modification are applied to all active langui.value fields
   in the specified language:
   
   - Known UTF-8 char codes are replaced with html entities.
   - Certain html entities (&amp; &lt; &gt;) are replaced with the char

   - this utility can be used to dump the hex codes of the non ascii 
     characters used in the text (using -test and -debug)
[fini]