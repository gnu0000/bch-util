#!perl
#
# AddResponseTranslations.pl
# This utility copies response translations from the demo to production DB
#
# Craig Fitzgerald


use warnings;
use strict;
use Gnu::SimpleDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);
use Gnu::DebugUtil  qw(DumpHash DumpRef);

my $LOCAL_VISITED = {};
my $DEMO_VISITED  = {};

MAIN:
   ArgBuild("*^test *^doit *^host= *^username= *^password= ^help ^debug ^debug2");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !scalar @ARGV;
   AddResponses();
   exit(0);


sub AddResponses
   {
   my $db1 = Connect(     "questionnaires", ArgsGet("host", "username", "password")); # from iciss dev
   my $db2 = Connect("demo_questionnaires", ArgsGet("host", "username", "password")); # from demo

   my $prod_responses = GetAllResponses($db1);
   my $demo_responses = GetAllResponses($db2);

   PrintResponsesInfo("production", $prod_responses);
   PrintResponsesInfo("demo"      , $demo_responses);

   my $demo_textmap = BuildResponseTextMap($demo_responses);
   PopulatefromTextMap ($db1, $prod_responses, $demo_textmap);

   PrintUntranslatedResponses($prod_responses);
   }

sub PopulatefromTextMap
   {
   my ($db1, $prod_responses, $demo_textmap) = @_;

   my ($addcount, $alreadypresent) = (0, 0);
   foreach my $id (keys %{$prod_responses})
      {
      my $response = $prod_responses->{$id};

      next unless $response->{t1804};

      $alreadypresent++ if $response->{t5912}; # we already have a translation
      next if $response->{t5912}; # we already have a translation

      my $match = $demo_textmap->{$response->{t1804}};
      next unless $match;

      next unless $match->{t5912}; # demo doesn't have a translation

      print "Adding spanish translation from demo.response $match->{id} to response $response->{id}\n";

      if (ArgIs("debug"))
         {
         print "=" x 80 . "\n";
         print "$response->{rt1804}->{text}\n";
         print "-" x 80 . "\n";
         print "$match->{rt5912}->{text}\n";
         print "=" x 80 . "\n";
         }
      InsertTranslationText ($db1, $response, $match->{rt5912}->{text}, 5912) if ArgIs("doit");
      $addcount++;
      }
   print "pre-existing translations: $alreadypresent\n";      
   print "translations added: $addcount\n";
   }


sub GetAllResponses
   {
   my ($db) = @_;

   my $responses = FetchHash($db, "id", "select * from responses");
   my $alltexts  = FetchHash($db, ["responseId", "languageId"], "select * from responsetext where current=1");

   foreach my $id (keys %{$responses})
      {
      my $response      = $responses->{$id};
      my $responsetexts = $alltexts->{$id};
      next unless $responsetexts;

      foreach my $langid (keys %{$responsetexts})
         {
         my $responsetext = $responsetexts->{$langid};
         $response->{"rt".$langid} = $responsetext;
         $response->{"t" .$langid} = NormalizeText ($responsetext->{text});
         }
      }
   return $responses;
   }

sub BuildResponseTextMap
   {
   my ($responses) = @_;

   my $textmap = {};
   my ($alternates, $matches, $entries) = (0, 0, 0);

   foreach my $id (keys %{$responses})
      {
      my $response = $responses->{$id};
      my $etext = $response->{t1804};
      next unless $etext;

      my $stext = $response->{t5912};
      next unless $stext;

      $entries++;

      my $match = $textmap->{$etext};

      # if we already have a translation for this text
      if ($match)
         {
         $matches++;

         # its the same translation
         next unless exists $response->{t5912} && exists $match->{t5912};
         next if $response->{t5912} eq $match->{t5912};
         $alternates++;

         if (ArgIs("debug"))
            {
            print "Repeated response with alternate translation ($match->{id} and $response->{id}):\n";
            print "=" x 80 . "\n";
            print "$match->{rt5912}->{text}\n";
            print "-" x 80 . "\n";
            print "$response->{rt5912}->{text}\n";
            print "=" x 80 . "\n";
            }

         my $rlen = length $response->{rt5912}->{text};
         my $mlen = length $match->{rt5912}->{text};

         # keep the longer translation
         next unless $rlen > $mlen;
         }
      $textmap->{$etext} = $response;
      }
   print "demo TextMapInfo...    \n"  ;
   print "entries   : $entries   \n"  ;
   print "matches   : $matches   \n"  ;
   print "alternates: $alternates\n\n";
   return $textmap;
   }


sub PrintResponsesInfo
   {
   my ($label, $responses) = @_;

   my $response_count = scalar (keys %{$responses});

   my ($e_count, $s_count, $p_count) = (0, 0, 0);
   foreach my $id (keys %{$responses})
      {
      $e_count++ if $responses->{$id}->{rt1804};
      $s_count++ if $responses->{$id}->{rt5912};
      $p_count++ if $responses->{$id}->{rt5265};
      }
   print "$label responses: $response_count\n";
   print "$label responses with english text: $e_count\n";
   print "$label responses with spanish text: $s_count\n\n";
   }


sub PrintUntranslatedResponses
   {
   my ($prod_responses) = @_;

   my $untranslated = {};
   foreach my $id (keys %{$prod_responses})
      {
      my $response = $prod_responses->{$id};
      next unless $response->{t1804}; # must have engl text
      next if $response->{t5912};     # cant have span text

      $untranslated->{$id} = $response;
      }
   
   print "\nUntranslated responses:\n";
   foreach my $id (keys %{$untranslated})
      {
      my $response = $untranslated->{$id};
      print "$response->{rt1804}->{text} ($id) \n";
      }
   my $ct = scalar keys %{$untranslated};
   print "$ct responses\n";

   my $ut = {};
   foreach my $id (keys %{$untranslated})
      {
      my $response = $untranslated->{$id};
      $ut->{$response->{t1804}} = $response;
      }
   my $ctu = scalar keys %{$ut};
   print "$ctu unique responses\n";
   }



# cut out as much clutter as we can so that when we compare, there is a better chance of a match
#
sub NormalizeText
   {
   my ($string) = @_;

   $string =~ s/<\/?div[^>]*>//gi;     
   $string =~ s/<\/?span[^>]*>//gi;    
   $string =~ s/<\/?p[^>]*>//gi;       
   $string =~ s/<\/?br[^>]*>//gi;      
   $string =~ s/<\/?hr[^>]*>//gi;      
   $string =~ s/<\/?acronym[^>]*>//gi; 
   $string =~ s/<\/?em[^>]*>//gi;      
   $string =~ s/&nbsp;/ /gi;           
   $string =~ s/(<br\s*\/?>){3,}/<br \/><br \/>/gi;
   return Trim($string);
   }


sub InsertTranslationText
   {
   my ($db, $response, $text, $language) = @_;

   my $sql = "INSERT INTO responsetext (responseId, languageId, text) VALUES (?, ?, ?)";
                                                
   ExecSQL ($db, $sql, $response->{id}, $language, $text);

   print "Inserting [$response->{id}, $language, '$text']\n" if ArgIs("debug");

   #print "sql inserted id: $db->{mysql_insertid}\n" unless $db->errstr;
   die "sql error: $db->errstr\n" if $db->errstr;
   }



#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]

todo ..... 
AddResponseTranslations.pl  -  
This utility copies response translations from the demo to production DB

USAGE: AddResponseTranslations.pl [options]

WHERE: [options] are one or more of:
   -test 
   -doit 
   -host 
   -username 
   -password
   -help

[fini]