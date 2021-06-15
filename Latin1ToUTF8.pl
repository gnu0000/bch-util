#!perl
#
# AddLanguage.pl
#
# This utility is for adding a new language or backfilling an existing language
# to Trivox
# 


use warnings;
use strict;
use feature 'state';
use Encode::Encoder qw(encoder);
use LWP::UserAgent;
use JSON;
use URI::Escape;
use Gnu::TinyDB;
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

MAIN:
   $| = 1;
   CvtLanguiText();
   CvtQuestionText();
   CvtResponseText();

   print "Done.\n";
   exit(0);


sub CvtLanguiText
   {
   print "Converting UI Fields to UTF-8...\n";
   Connection("onlineadvocate");

   my $sql_select = "SELECT * FROM langui ORDER BY langId, uiId";
   my $sql_insert = "INSERT INTO utf8_langui(uiId, langId, value, adminUserId, confirmed) VALUES (?, ?, ?, ?, 'NO')";
   my $langui = FetchArray($sql_select);
   foreach my $rec (@{$langui})
      {
      $rec->{value} = Transcode($rec->{value});
      ExecSQL($sql_insert, $rec->{uiId}, $rec->{langId}, $rec->{value}, $rec->{adminUserId});
      print ".";
      }
   print "\n\n";
   }


sub CvtQuestionText
   {
   print "Converting Questions to UTF-8...\n";
   Connection("questionnaires");

   my $sql_select = "SELECT * FROM questiontext where current=1 ORDER BY languageId, questionId";
   my $sql_insert = "INSERT INTO utf8_questiontext (questionId, languageId, text, adminUserId, current, noTagText) VALUES (?, ?, ?, ?, 1, ?)";

   my $questiontext = FetchArray($sql_select);
   foreach my $rec (@{$questiontext})
      {
      $rec->{text} = Transcode($rec->{text});
      ExecSQL($sql_insert, $rec->{questionId}, $rec->{languageId}, $rec->{text}, $rec->{adminUserId}, $rec->{noTagText});
      print ".";
      }
   print "\n\n";
   }


sub CvtResponseText
   {
   print "Converting Responses to UTF-8...\n";
   Connection("questionnaires");

   my $sql_select = "SELECT * FROM responsetext where current=1 ORDER BY languageId, responseId";
   my $sql_insert = "INSERT INTO utf8_responsetext (responseId, languageId, text, adminUserId, current, noTagText) VALUES (?, ?, ?, ?, 1, ?)";

   my $responsetext = FetchArray($sql_select);
   foreach my $rec (@{$responsetext})
      {
      $rec->{text} = Transcode($rec->{text});
      ExecSQL($sql_insert, $rec->{responseId}, $rec->{languageId}, $rec->{text}, $rec->{adminUserId}, $rec->{noTagText});
      print ".";
      }
   print "\n\n";
   }


# convert Latin1 encoding to UTF-8
sub Transcode
   {
   my ($source) = @_;

   return $source unless $source;
   my $dest = eval {encoder($source)->latin1->utf8}; 
   print "!" if $@;
   return $source if $@;
   return $dest;
   }

