#!perl -d
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
use Encode::Encoder qw(encoder);
use Encode qw(is_utf8 encode_utf8 decode_utf8 _utf8_off);
use LWP::UserAgent;
use JSON;
use URI::Escape qw(uri_escape uri_escape_utf8);
use Gnu::TinyDB;
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

my $STATS = {};

my $DEFAULT_ADMIN_ID       = 8888;
my $DEFAULT_GOOGLE_API_KEY = 'AIzaSyA7HOINCmQg0w5Me6ZvAwiW1rZI0kRmexY';

# NOTE: if the language you want to add has an id=9999, you'll need to
# change it, and add extra stuff to the trivox resource database
#
my $LANGUAGE_CHOICES =
  {"afrikaans"      => {code=>"af" , id=>9999},  "korean"     => {code=>"ko", id=>3123},
   "albanian"       => {code=>"sq" , id=>9999},  "lao"        => {code=>"lo", id=>9999},
   "arabic"         => {code=>"ar" , id=> 345},  "latin"      => {code=>"la", id=>9999},
   "armenian"       => {code=>"hy" , id=>9999},  "latvian"    => {code=>"lv", id=>9999},
   "azerbaijani"    => {code=>"az" , id=>9999},  "lithuanian" => {code=>"lt", id=>9999},
   "basque"         => {code=>"eu" , id=>9999},  "macedonian" => {code=>"mk", id=>9999},
   "belarusian"     => {code=>"be" , id=>9999},  "malagasy"   => {code=>"mg", id=>9999},
   "bengali"        => {code=>"bn" , id=> 620},  "malay"      => {code=>"ms", id=>9999},
   "bosnian"        => {code=>"bs" , id=>9999},  "malayalam"  => {code=>"ml", id=>9999},
   "bulgarian"      => {code=>"bg" , id=>9999},  "maltese"    => {code=>"mt", id=>9999},
   "catalan"        => {code=>"ca" , id=>9999},  "maori"      => {code=>"mi", id=>9999},
   "cebuano"        => {code=>"ceb", id=>9999},  "marathi"    => {code=>"mr", id=>9999},
   "chichewa"       => {code=>"ny" , id=>9999},  "mongolian"  => {code=>"mn", id=>9999},
   "croatian"       => {code=>"hr" , id=>9999},  "norwegian"  => {code=>"no", id=>9999},
   "czech"          => {code=>"cs" , id=>1224},  "persian"    => {code=>"fa", id=>1875},
   "danish"         => {code=>"da" , id=>9999},  "polish"     => {code=>"pl", id=>5259},
   "dutch"          => {code=>"nl" , id=>9999},  "portuguese" => {code=>"pt", id=>5265},
   "english"        => {code=>"en" , id=>1804},  "punjabi"    => {code=>"ma", id=>9999},
   "esperanto"      => {code=>"eo" , id=>9999},  "romanian"   => {code=>"ro", id=>9999},
   "estonian"       => {code=>"et" , id=>9999},  "russian"    => {code=>"ru", id=>5577},
   "filipino"       => {code=>"tl" , id=>9999},  "serbian"    => {code=>"sr", id=>9999},
   "finnish"        => {code=>"fi" , id=>9999},  "sesotho"    => {code=>"st", id=>9999},
   "french"         => {code=>"fr" , id=>1916},  "sinhala"    => {code=>"si", id=>9999},
   "galician"       => {code=>"gl" , id=>9999},  "slovak"     => {code=>"sk", id=>9999},
   "georgian"       => {code=>"ka" , id=>9999},  "slovenian"  => {code=>"sl", id=>9999},
   "german"         => {code=>"de" , id=>1534},  "somali"     => {code=>"so", id=>5899},
   "greek"          => {code=>"el" , id=>1778},  "spanish"    => {code=>"es", id=>5912},
   "gujarati"       => {code=>"gu" , id=>9999},  "sudanese"   => {code=>"su", id=>9999},
   "haitian creole" => {code=>"ht" , id=>2291},  "swahili"    => {code=>"sw", id=>9999},
   "hausa"          => {code=>"ha" , id=>9999},  "swedish"    => {code=>"sv", id=>9999},
   "hebrew"         => {code=>"iw" , id=>9999},  "tajik"      => {code=>"tg", id=>9999},
   "hindi"          => {code=>"hi" , id=>9999},  "tamil"      => {code=>"ta", id=>9999},
   "hmong"          => {code=>"hmn", id=>9999},  "telugu"     => {code=>"te", id=>9999},
   "hungarian"      => {code=>"hu" , id=>9999},  "thai"       => {code=>"th", id=>6248},
   "icelandic"      => {code=>"is" , id=>9999},  "turkish"    => {code=>"tr", id=>9999},
   "igbo"           => {code=>"ig" , id=>9999},  "ukrainian"  => {code=>"uk", id=>9999},
   "indonesian"     => {code=>"id" , id=>9999},  "urdu"       => {code=>"ur", id=>6701},
   "irish"          => {code=>"ga" , id=>9999},  "uzbek"      => {code=>"uz", id=>9999},
   "italian"        => {code=>"it" , id=>2597},  "vietnamese" => {code=>"vi", id=>6775},
   "japanese"       => {code=>"ja" , id=>2720},  "welsh"      => {code=>"cy", id=>9999},
   "javanese"       => {code=>"jw" , id=>9999},  "yiddish"    => {code=>"yi", id=>7377},
   "kannada"        => {code=>"kn" , id=>9999},  "yoruba"     => {code=>"yo", id=>9999},
   "kazakh"         => {code=>"kk" , id=>9999},  "zulu"       => {code=>"zu", id=>9999},
   "khmer"          => {code=>"km" , id=>2940},  "chinese"    => {code=>"zh-CN", id=>7575},
   };                                  

MAIN:
   $| = 1;
   ArgBuild("*^list *^language= *^test= *^adminid *^apikey= ^remove ^latin1 " .
            "*^host= *^username= *^password= *^proxy? ^help *^debug");

   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   ListLanguages() if ArgIs("list");
   Usage() if ArgIs("help") || !ArgIs("language");

   TargetLanguage(ArgGet("language"));

   Test()           if ArgIs("test");
   RemoveLanguage() if ArgIs("remove");

   print "('*'=Translated,' '=No English,'.'=Already Done,'-'=No Translation,'X'=Too Big)\n";
   AddLanguiText();
   AddQuestionText();
   AddResponseText();

   AddStudyLanguage();
   print "Done.\n";
   exit(0);


sub AddLanguiText
   {
   print "Adding UI Fields...\n";
   Connection("onlineadvocate");
   ClearStats();

   my $lang     = TargetLanguage();
   my $uifields = FetchHash("id"              , "select * from uifields");
   my $languis  = FetchHash(["uiId", "langId"], "select * from langui");

   foreach my $uiid (sort {$a<=>$b} keys %{$uifields})
      {
      my $uifield = $uifields->{$uiid};
      my $langui  = $languis->{$uiid} || {};

      IncStat("count");
      next if NoEnglish ($langui);
      next if TooBig    ($langui, "value");
      next if HasForeign($langui, $lang->{id});

      my $english    = $langui->{1804}->{value};
      my $translated = Translate($english, $lang->{code});

      next if NoTranslation($translated);
      my $transcoded = Transcode ($translated);
      AddLanguiRecord ($uiid, $lang->{id}, $transcoded);
      print "*";
      }
   ShowStats();
   }

sub AddLanguiRecord
   {
   my ($uiid, $langid, $value) = @_;

   my $adminid = ArgIs("adminid") ? ArgGet("adminid") : $DEFAULT_ADMIN_ID;
   my $sql     = "INSERT INTO langui(uiId, langId, value, adminUserId, confirmed) VALUES (?, ?, ?, ?, 'NO')";
   ExecSQL($sql, $uiid, $langid, $value, $adminid);
   }

sub AddQuestionText
   {
   print "Adding Questions...\n";
   Connection("questionnaires");
   ClearStats();

   my $lang          = TargetLanguage();
   my $questions     = FetchHash("id"         , "select * from questions");
   my $questiontexts = FetchHash(["questionId", "languageId"], "select * from questiontext where current=1");

   foreach my $questionid (sort {$a<=>$b} keys %{$questions})
      {
      my $question     = $questions->{$questionid};
      my $questiontext = $questiontexts->{$questionid} || next;

      IncStat("count");
      next if NoEnglish ($questiontext);
      next if TooBig    ($questiontext, "text");
      next if HasForeign($questiontext, $lang->{id});

      my $english    = $questiontext->{1804}->{text};
      my $translated = Translate($english, $lang->{code});

      next if NoTranslation($translated);

      my $transcoded = Transcode ($translated);

      AddQuestionTextRecord ($questionid, $lang->{id}, $transcoded);
      print "*";
      }
   ShowStats();
   }

sub AddQuestionTextRecord
   {
   my ($questionid, $languageid, $text) = @_;

   my $adminid = ArgIs("adminid") ? ArgGet("adminid") : $DEFAULT_ADMIN_ID;
   my $sql     = "INSERT INTO questiontext (questionId, languageId, text, adminUserId, current) VALUES (?, ?, ?, ?, 1)";
   ExecSQL($sql, $questionid, $languageid, $text, $adminid);
   }

sub AddResponseText
   {
   print "Adding Responses...\n";
   Connection("questionnaires");
   ClearStats();

   my $lang          = TargetLanguage();
   my $responses     = FetchHash("id"         , "select * from responses");
   my $responsetexts = FetchHash(["responseId", "languageId"], "select * from responsetext where current=1");

   foreach my $responseid (sort {$a<=>$b} keys  %{$responses})
      {
      my $response     = $responses->{$responseid};
      my $responsetext = $responsetexts->{$responseid} || next;

      IncStat("count");
      next if NoEnglish ($responsetext);
      next if TooBig    ($responsetext, "text");
      next if HasForeign($responsetext, $lang->{id});

      my $english    = $responsetext->{1804}->{text};
      my $translated = Translate($english, $lang->{code});

      next if NoTranslation($translated);

      my $transcoded = Transcode ($translated);

      AddResponseTextRecord ($responseid, $lang->{id}, $transcoded);
      print "*";
      }
   ShowStats();
   }

sub AddResponseTextRecord
   {
   my ($responseid, $languageid, $text) = @_;

   my $adminid = ArgIs("adminid") ? ArgGet("adminid") : $DEFAULT_ADMIN_ID;
   my $sql     = "INSERT INTO responsetext (responseId, languageId, text, adminUserId, current) VALUES (?, ?, ?, ?, 1)";
   ExecSQL($sql, $responseid, $languageid, $text, $adminid);
   }


sub AddStudyLanguage
   {
   my $langid = TargetLanguage()->{id};

   Connection("onlineadvocate");
   my $languages = FetchHash("languageId", "select * from studyLanguages");
   return "Study Language exists.\n" if $languages->{$langid};
   print "Adding Study Language...\n";

   my $sql = "INSERT INTO studyLanguages (languageId) VALUES (?)";
   ExecSQL($sql, $langid);
   }


sub RemoveLanguage
   {
   my $langid = TargetLanguage()->{id};

   print "Removing langui for language $langid...\n";
   Connection("onlineadvocate");
   ExecSQL("DELETE FROM langui where langId=$langid");

   print "Removing questiontext for language $langid...\n";
   Connection("questionnaires");
   ExecSQL("DELETE FROM questiontext where languageId=$langid");

   print "Removing responsetext for language $langid...\n";
   ExecSQL("DELETE FROM responsetext where languageId=$langid");

   print "Removing studyLanguages record for language $langid...\n";
   Connection("onlineadvocate");
   ExecSQL("DELETE FROM studyLanguages where languageId=$langid");

   print "Done.\n";
   exit (0);
   }


sub NoEnglish
   {
   my ($rec) = @_;

   return 0 if $rec->{1804};
   IncStat("noenglish");
   print " ";
   return 1;
   }

sub TooBig
   {
   my ($rec, $key) = @_;

   my $english = $rec->{1804};
   my $too_big = length $english->{$key} > 1024 * 5;
   return 0 unless $too_big;
   IncStat("toobig");
   print "X";
   return 1;
   }

sub HasForeign
   {
   my ($rec, $langid) = @_;

   return 0 unless $rec->{$langid};
   IncStat("hasforeign");
   print ".";
   return 1;
   }

sub NoTranslation
   {
   my ($new_text) = @_;

   return 0 unless !defined $new_text || $new_text =~ /^\s*$/s;
   IncStat("notranslation");
   print "-";
   return 1;
   }

sub TargetLanguage
   {
   my ($name) = @_;

   state $lang = undef;
   return $lang unless $name;
   $lang = $LANGUAGE_CHOICES->{lc $name};
   die "Unknown language '$name'" unless $lang;
   return $lang
   }

sub ListLanguages
   {
   map {print "$_\n"} sort keys %{$LANGUAGE_CHOICES};
   exit(0);
   }

sub Convert
   {
   my ($source, $print) = @_;

   my $lang = TargetLanguage();
   my $translated = Translate($source, $lang->{code});
   my $transcoded = Transcode($translated);
   
   if ($print || ArgIs("debug"))
      {
      print "Language  : '$lang->{code} ($lang->{id})'\n";
      print "English   : '$source'\n";
      print "Translated: '$translated'\n";
      print "Transcoded: '$transcoded'\n" if ArgIs("latin1");
      }
   CreateSamples($lang->{code}, $source, $translated, $transcoded) if ArgIs("test");

   return $transcoded;
   }

sub Translate
   {
   my ($source, $code) = @_;

   #debug test#   return "-$code-$source-";  #debug test

   return $source if $source =~ /^\s*$/s;

   my $apikey = ArgIs("apikey") ? ArgGet("apikey") : $DEFAULT_GOOGLE_API_KEY;

   my $user_agent = LWP::UserAgent->new;

   my $proxy = ArgGet("proxy") || $ENV{"http_proxy"} || "";
   $user_agent->proxy(http => $proxy) if $proxy;

   my $escaped = uri_escape_utf8($source);
   my $uri     = "https://www.googleapis.com/language/translate/v2?" .
                 "key=$apikey&source=en&target=$code&q=$escaped";
   my $request = HTTP::Request->new(GET => $uri);
   my $res     = $user_agent->request($request);

   #print "source: $source\n";
   #print "ret: " . $res->content() . "\n";

   my $data = eval {from_json($res->content())};
   return "" if $@;

   return $data->{data}->{translations}->[0]->{translatedText};
   }

sub Transcode
   {
   my ($source) = @_;

#   #$return $source if ArgIs("donttranscode");
#   return $source unless ArgIs("latin1");
#
#   # convert UTF-8 to Latin1 encoding
#   my $dest = eval {encoder($source)->utf8->latin1}; 
#   return "" if $@;
#   return $dest;

   DumpSample($source,1);
   my $source2 = LoadSample(1);
   my $source3 = decode_utf8($source2);

   return $source3;
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

sub CreateSamples
   {
   my ($code, $source, $translated, $transcoded) = @_;

   open (my $file, ">", "sample_utf8.html");
   print $file Template("UTF8", code=>$code, source=>$source, translated=>$translated, transcoded=>$transcoded);
   close ($file);
   open ($file, ">", "sample_latin1.html");
   print $file Template("Latin1", code=>$code, source=>$source, translated=>$translated, transcoded=>$transcoded);
   close ($file);
   }

sub ShowStats
   {
   print Template("stats", %{$STATS});
   }

sub ClearStats
   {
   $STATS = {count        =>0,
             noenglish    =>0,
             hasforeign   =>0,
             toobig       =>0,
             notranslation=>0};
   }

sub IncStat
   {
   my ($name) = @_;
   $STATS->{$name} = 0 unless exists $STATS->{$name};
   $STATS->{$name}++;
   }

sub GetStat
   {
   my ($name) = @_;
   return $STATS->{$name} || 0 ;
   }

sub Test
   {
   Convert(ArgGet("test"), 1);
   exit(0);
   }

sub Usage
   {
   print Template("usage");
   exit(0);
   }

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

[usage]
AddLanguage.pl  -  Add or remove language text to Trivox

USAGE: AddLanguage.pl [options]

WHERE: [options] are one or more of:
   -help .......... This help
   -list .......... list languages
   -language=name . Set the language to generate
   -test=string ... Test.  Convert this string, print and create sample html
   -remove ........ Delete all text for this language
   -latin1 ........ Transcode from utf8 to Latin1 (dont use!)
   -adminid=id .... Set the Trivox adminId for new records (9999)
   -apikey=key .... Set the Google API key (craigs key)
   -proxy=proxy ... Set the proxy (or use env: http_proxy)
   -host=foo ...... Set the mysqlhost (localhost)
   -username=foo .. Set the mysqlusername (avocate)
   -password=foo .. Set the mysqlpassword (****************)
   -debug ......... Show stuff.

Examples:
   AddLanguage.pl -list
      List all possible languages that you can specify

   AddLanguage.pl -language=swedish -test="<b>This</b> is a test."
      Do a simple test conversion
      creates sample_utf8.html and sample_Latin1.html

   AddLanguage.pl -language=russian
      Add Russian to trivox. Using all defaults

   AddLanguage.pl -language=german -proxy="http://foo.com:3128" -apikey=AIzaSyA7HOINCmxY
      Add German to trivox. Use an alternate proxy and google api key

   set http_proxy=http://proxy.tch.harvard.edu:3128
   AddLanguage.pl -language=italian -username=advocate -pass=puppies -adminid=1234
      Add Italian to trivox. Use an alternate mysql creds and use a new adminid
      Use proxy set in the environment

   AddLanguage.pl -language=yiddish -remove
      Remove all yiddish text

[stats]

Results:
   Total Records examined ............... $count
   Records w/o English source text ...... $noenglish
   Records with existing foreign text ... $hasforeign
   Records too large to translate ....... $toobig
   Records with untranslatable text ..... $notranslation

[UTF8]
<!DOCTYPE html>
   <head>
      <meta charset="UTF-8">
   </head>
   <body>
      <h2>UTF-8 sample</h2>
      <h3>Source</h3>     
      <p>$source</p>
      <h3>Translated to '$code'</h3> 
      <p>$translated</p>
      <h3>Transcoded from UTF-8 to Latin1</h3> 
      <p>$transcoded</p>
   </body>
<html>
</html>

[Latin1]
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
   <head>
      <meta charset="ISO-8859-1">
   </head>
   <body>
      <h2>Latin1 sample</h2>
      <h3>Source</h3>     
      <p>$source</p>
      <h3>Translated to '$code'</h3> 
      <p>$translated</p>
      <h3>Transcoded from UTF-8 to Latin1</h3> 
      <p>$transcoded</p>
   </body>
<html>
</html>
