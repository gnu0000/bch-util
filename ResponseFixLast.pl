#!perl
#
# ResponseFixLast.pl
# This utility is for cleaning up response/responsetext text
#
# Craig Fitzgerald

# This utility is the last step in cleaning up the responses when adding a 
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

   FixResponseTextCharset();
   exit(0);



sub FixResponseTextCharset
   {
   Connection("questionnaires", ArgsGet("host", "username", "password"));
   my $languageid = GetLanguageId();

   my $qts = GetResponseTexts($languageid);

   my ($record_ct, $change_ct) = (0, 0);
   foreach my $qt (@{$qts})
      {
      next if ArgIs("id") && (ArgGet("id") != $qt->{id});

      my $old_text = $qt->{text};
      my $new_text = FixText($old_text);
      my $changed  = $new_text ne $old_text;

      print $changed ? "*" : "." unless ArgIs("debug") || ArgIs("debug2");
      UpdateResponseText($qt->{id}, $new_text)      if $changed && ArgIs("doit" );
      DumpResponseText ($qt->{id}, $old_text, $new_text) if $changed && ArgIs("debug");
      DumpFunkyText    ($qt)                             if ArgIs("debug2");

      $record_ct++;
      $change_ct++ if $changed;
      }
   print "\n";
   print "$record_ct foreign responsetext records examined.\n";
   print "$change_ct foreign responsetext records modified.\n";
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
   $text =~ s/\xC2\xBF/&iquest;/g; # 
   $text =~ s/\xC3\x93/&Oacute;/g; # 
   $text =~ s/\xC3\xA0/&agrave;/g; # 
   $text =~ s/\xC3\xA1/&aacute;/g; # 
   $text =~ s/\xC3\xA3/&atilde;/g; # 
   $text =~ s/\xC3\xA7/&ccedil;/g; # 
   $text =~ s/\xC3\xA9/&eacute;/g; # 
   $text =~ s/\xC3\xAA/&ecirc;/g;  # 
   $text =~ s/\xC3\xAD/&iacute;/g; # 
   $text =~ s/\xC3\xB1/&ntilde;/g; # 
   $text =~ s/\xC3\xB3/&oacute;/g; # 
   $text =~ s/\xC3\xB5/&otilde;/g; # 
   $text =~ s/\xC3\xBA/&uacute;/g; # 

# selected html entities to the original character
#
   $text =~ s/&lt;/</ig;   # <
   $text =~ s/&gt;/>/ig;   # >
   $text =~ s/&amp;/&/g;   # &
   $text =~ s/&#xa0;/ /ig; # space
   $text =~ s/&#160/ /ig;  # space
   $text =~ s/&nbsp;/ /ig; # space


   return $text;
   }

sub GetResponseTexts
   {
   my ($languageid) = @_;

   my $sql = "select * from responsetext where languageid=$languageid and current=1";
   my $qts = FetchArray($sql);
   return $qts;
   }

sub UpdateResponseText
   {
   my ($id, $text) = @_;

   my $sql = "update responsetext set text=? where id=$id";
   ExecSQL ($sql, $text);
   }

sub DumpResponseText  
   {
   my ($id, $old_text, $new_text) = @_;

   print "\n-------------[$id]------------------------\n";
   print "from: $old_text\n";
   print "--------------------------------------------\n";
   print "to  : $new_text\n";
   print "--------------------------------------------\n";
   }

sub DumpFunkyText0
   {
   my ($id, $text) = @_;

   my @chars = split(//, $text);
   my $header_printed = 0;
   for (my $idx=0; $idx<scalar @chars; $idx++)
      {
      my $char = $chars[$idx];
      my $val = ord($char);
      next unless $val > 127;
      print sprintf ("[id: %5.5d] ", $id) unless $header_printed++;
      print sprintf ("%3.3d:[%2.2x] ", $idx, $val);
      }
   print "\n" if $header_printed;
   }

sub DumpFunkyText
   {
   my ($qt) = @_;

   my ($id, $qid, $text) = ($qt->{id}, $qt->{responseId}, $qt->{text});


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
         print sprintf ("[qid:$qid, id:%5.5d]", $qid, $id) unless $header_printed++;
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
[doc-8859-1]
<html>
   <head>
      <meta http-equiv="Content-Type" content="text/html;charset=ISO-8859-1">
   </head>
   <body>
      <div>
      $text
      </div>
   </body>
</html>
[doc-utf8]
<!DOCTYPE html>
<html>
   <head>
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
      <meta charset="utf-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
   </head>
   <body>
      <div>
      $text
      </div>
   </body>
</html>
[usage]
ResponseFixLast.pl - Utility to convert utf-8 characters to html 
                            entities for questionnaires.responsetext.text data.

USAGE: ResponseFixLast.pl [options]

WHERE: [options] is one or more of:
   -language=spanish .. Pick language to clean (english|spanish|portuguese)
   -test .............. Run, but dont actually update the database
   -doit .............. Run, actually update the database
   -id=responsetextid.. Only process this record
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug ............. (with -test) show string changes
   -debug2 ............ (with -test) show utf-8 char bytes

EXAMPLES:
   ResponseFixLast.pl -lang=spanish -test
   ResponseFixLast.pl -lang=spanish -test -debug
   ResponseFixLast.pl -lang=spanish -doit

NOTES:
   The following modification are applied to all active responsetext.text
   fields in the specified language:
   
   - Known UTF-8 char codes are replaced with html entities.
   - Certain html entities (&amp; &lt; &gt;) are replaced with the char

   - this utility can be used to dump the hex codes of the non ascii 
     characters used in the text (using -test and -debug)

[fini]
