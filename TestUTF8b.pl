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
use utf8;
#use open ':encoding(utf8)';
use Encode::Encoder qw(encoder);
use HTML::Entities;
use LWP::UserAgent;
use JSON;
use URI::Escape qw(uri_escape uri_escape_utf8);
use Encode qw(is_utf8 encode_utf8 decode_utf8 _utf8_off);
use DBI;
use DBD::mysql;
use Gnu::TinyDB;
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

my $DEFAULT_GOOGLE_API_KEY = 'AIzaSyA7HOINCmQg0w5Me6ZvAwiW1rZI0kRmexY';

MAIN:
   $| = 1;
   ArgBuild("*^language= *^test= *^adminid *^apikey= ^remove ^latin1 " .
            "*^host= *^username= *^password= *^proxy? ^help *^debug");

   Test();
   exit(0);

sub Test
   {
   my $sample1 = "\x{8fd9}\x{662f}\x{4e00}\x{4e2a}\x{6d4b}\x{8bd5}";
   my $sample2 = FetchLanguiSample(2677);
   my $sample3 = FetchSample(5);

   my $s1_thru = ThruDB($sample1, 2);
   my $s2_thru = encode_entities($sample2);
   my $s3_thru = encode_entities($sample3);
   my $s3_clean= test_clean     ($sample3);

#   DumpSample($sample2,2);
#   DumpSample($sample3,3);
#   my $s4 = LoadSample(2);
#   my $s5 = decode_utf8($s4); # no effect on string

   open (my $file, ">", "sample_utf8.html");
   print $file Template("UTF8");
   print $file "<table>\n";
   PrintRow($file, "sample1        ", $sample1);
   PrintRow($file, "sample1 thru db", $s1_thru);

   PrintRow($file, "sample2 from DB", $sample2);
   PrintRow($file, "sample2 ent    ", $s2_thru);

   PrintRow($file, "sample3 from DB", $sample3);
   PrintRow($file, "sample3 ent    ", $s3_thru);
   PrintRow($file, "sample3 cleaned", $s3_clean);

   print $file "</table>\n";

##   Testz($file, $s1_translated, $sample2);
#   Testz($file, $s5, $sample2);

   print $file Template("end");
   close ($file);

   #DumpSamples($s1_translated,$sample3);
   }

sub PrintRow
   {
   my ($file, $label, $text) = @_;

#  my $a = join(",", @u);
#   my @u = unpack("U*", $text);
#   my $a = join(",", map {sprintf("%x", $_)} @u);

   my $is = is_utf8($text) ? "yes" : "no";
   my $a = join(",", map {sprintf("%x", $_)} unpack("U*", $text));
   
   my $text2 = encode_utf8($text);
   my $is2 = is_utf8($text2) ? "yes" : "no";
   my $b = join(",", map {sprintf("%x", $_)} unpack("U*", $text2));

   my $text3 = decode_utf8($text2);
   my $is3 = is_utf8($text3) ? "yes" : "no";
   #my $text3 = decode("iso-8859-1", $text); 

   my $c = join(",", map {sprintf("%x", $_)} unpack("U*", $text3));

   print $file "<tr>"
   . "<td>$label</td>"
   . "<td>$text</td><td>$is,$is2,$is3</td>"
   . "<td>$a</td>"
   . "<td>$b</td>"
   . "<td>$c</td></tr>\n";
   }


sub Translate
   {
   my ($source, $code) = @_;

   return $source if $source =~ /^\s*$/s;

   my $apikey = ArgIs("apikey") ? ArgGet("apikey") : $DEFAULT_GOOGLE_API_KEY;

   my $user_agent = LWP::UserAgent->new;

   my $proxy = ArgGet("proxy") || $ENV{"http_proxy"} || "";
   $user_agent->proxy(http => $proxy) if $proxy;

   my $escaped = uri_escape_utf8($source);
   my $uri     = "https://www.googleapis.com/language/translate/v2?" .
                 "key=$apikey&source=en&target=$code&q=$escaped";
   print "$uri\n";
   my $request = HTTP::Request->new(GET => $uri);
   my $res     = $user_agent->request($request);

   my $data = eval {from_json($res->content())};
   return "" if $@;

   return $data->{data}->{translations}->[0]->{translatedText};
   }


sub Transcode
   {
   my ($source) = @_;

#   _utf8_off($source);
#   my $dest = decode_utf8($source); # no effect on string
#   return $dest;
#   #my $dest = encode_utf8($source);   # messes up
#   #return $source;

   DumpSample($source,1);
   my $source2 = LoadSample(2);
   my $source3 = decode_utf8($source2);

   return $source3;
   }


sub ThruDB
   {
   my ($source, $id) = @_;

   Connection("test");

   ExecSQL("update test set text='$source' where id=$id");
   return FetchColumn("select text from test where id=$id");
   }


sub test_clean
   {
   my ($text) = @_;

#   $text =~ s/\xC2/&Acirc;/g;
#   $text =~ s/\x92/\x27/g;

#   $text =~ s/\x{2019}/'/g;
#   $text =~ s/\xC2//g;
#   $text =~ s/\x92/C/g;

   $text =~ s/\xC2\x{2019}/'/g;

   return $text;
   }


sub FetchSample
   {
   my ($id) = @_;

   Connection("test");
   return FetchColumn("select text from test where id=$id");
   }

sub FetchLanguiSample
   {
   my ($id) = @_;

   Connection("onlineadvocate");
   return FetchColumn("select value from langui where id=$id");
   }

sub DumpSample
   {
   my ($sample, $idx) = @_;

   open (my $file, ">", "sample_utf8_$idx.bin");
   binmode $file;
   print $file $sample;
   close ($file);
   }


sub LoadSample
   {
   my ($idx) = @_;

   open (my $file, "<", "sample_utf8_$idx.bin");
   binmode $file;
   my $text = <$file>;
   close ($file);
   return $text;
   }


sub Testz
   {
#   my ($file, $text, $sample2) = @_;
#
#   my $is1 = is_utf8($text) ? "yes" : "no";
#   _utf8_off($text);
#   my $is2 = is_utf8($text) ? "yes" : "no";
#   my $text2 = decode_utf8($text);
#   my $is3 = is_utf8($text) ? "yes" : "no";
#
#   my $a = join(",", map {sprintf("%x", $_)} unpack("U*", $text2));
#   my $b = join(",", map {sprintf("%x", $_)} unpack("U*", $sample2));

   my ($file, $translated, $known) = @_;

#   _utf8_off($translated);
#
#   my $translated_d = decode_utf8($translated);
#   my $known_e      = encode_utf8($known);
#   my $known_d      = decode_utf8($known_e);
#
#   print $file "<p>" . UList($translated)   . "</p>\n";
#   print $file "<p>" . UList($known_e)      . "</p>\n";
#
#   print $file "<p>" . UList($translated_d) . "</p>\n";
#   print $file "<p>" . UList($known_d)      . "</p>\n";

   UShow ($file, "translated", $translated);
   UShow ($file, "known"     , $known);
   }

sub UShow
   {
   my ($file, $label, $string) = @_;

   my $string_e  = encode_utf8($string);
   my $string_ed = decode_utf8($string_e);
   print $file "<p>" . $label . "</p>\n";
   print $file "<p>string:" . UList($string)     . "</p>\n";
   print $file "<p>encoded:" . UList($string_e)   . "</p>\n";
   print $file "<p>decoded:" . UList($string_ed)  . "</p>\n";

   _utf8_off($string_ed);
   print $file "<p>flagoff:" . UList($string_ed) . "</p>\n";
   my $string_edd = decode_utf8($string_ed);
   print $file "<p>decoded:" . UList($string_edd) . "</p>\n";


   }

sub UList
   {
   my ($text) = @_;

   my $is = is_utf8($text) ? "yes" : "no";

   return "($is)" . join(",", map {sprintf("%x", $_)} unpack("U*", $text));
   }

#sub Connection
#   {
#   my ($enable) = @_;
#
#
#   my $db = DBI->connect("DBI:mysql:database=test;user=craig;password=a") or die "cant connect to db";
#   $db->{'mysql_enable_utf8'} = 1 if $enable;
#   $db->do('set names utf8')      if $enable;
#
#   return $db;
#   }
#
#sub ExecSQL
#   {
#   my ($sql, @bindparams) = @_;
#
#   my $db = Connection(1);
#
#   my $sth = $db->prepare ($sql) or return undef;
#   $sth->execute (@bindparams) or die $sth->errstr;
#   $sth->finish();
#   }
#
#sub FetchColumn
#   {
#   my ($sql) = @_;
#
#   my $db = Connection(1);
#   my @row = $db->selectrow_array ($sql);
#   return $row[0];
#   }

sub Template
   {
   my ($key, %data) = @_;

   state $templates = InitTemplates();

   my $template = $templates->{$key};
   $template =~ s{\$(\w+)}{exists $data{$1} ? $data{$1} : "\$$1"}gei;
    return $template;
   }

sub InitTemplates
   {
   my $templates = {};
   my $key = "nada";
   while (my $line = <DATA>)
      {
      my ($section) = $line =~ /^\[(\S+)\]/;
      $key = $section || $key;
      $templates->{$key} = ""      if $section;
      $templates->{$key} .= $line  if !$section;
      }
   return $templates;
   }

__DATA__
[UTF8]
<!DOCTYPE html>
<html>
   <head>
      <meta charset="UTF-8">
      <style>
         body {
            font-size: 1.3em;
         }
         table td {
            padding: 0.15em 1em;
         }
      </style>
   </head>
   <body>
      <h2>UTF-8 sample</h2>
[end]
   </body>
</html>

[fini]