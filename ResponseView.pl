#!perl
#
# ResponseView.pl
# This utility is for examining response/responsetext text
#
# Craig Fitzgerald

# This utility is usefull for determining what problems exist, what 
#  foreign fields are missing, what <var> names are present, etc...
#
# This utility can generate html as well as text.  This can be usefull for
#  detecting broken tags, as all following html will likely be screwed up.
#
# See the bottom of this file, or run this script with no options to
#  get usage information.
#
# See the README for more information.
#
# Some examples:
#
#   Generate a html page of all the responses:
#
#     ResponseView.pl -e -html > foo.html
#
#   Generate a html page of all the responses and the protugeuse translations:
#
#     ResponseView.pl -language=portuguese -e -f -html > foo.html
#
#   Display all responses (and associated responsetext) that have both english
#   and spanish text:
#
#     ResponseView.pl -language=spanish -e -f
#
#   Display all responses (and associated responsetext) that have both english
#   and spanish text, and that have the "<" char encoded as an html entity
#   in ther spanish text:
#
#     ResponseView.pl -language=spanish -e -f -ftext="&lt;"
#
#   Create a web page containing all responses (and associated responsetext) that 
#    have <var>'s in the english text, but dont have <var>'s in the spanish text
#
#     ResponseView.pl -language=spanish -e -f -ve -vnf -html > foo.html
#
#   Generate response index files for the web page editor:
#
#     ResponseView.pl -language=spanish -e -f -idsonly > 5912
#     ResponseView.pl -language=portuguese -e -f -idsonly > 5265


use warnings;
use strict;
use feature 'state';
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);


MAIN:
   $| = 1;
   ArgBuild("*^all ^e ^ne ^f ^nf ^v ^nv ^ve ^vf ^vne ^vnf ^vars " .
            "^varsonly *^varnameonly *^idsonly *^orphans "        .
            "*^etext= *^ftext= ^id= ^eid= ^fid= *^language= "     .
            "*^html *^host= *^username= *^password= *^help");

   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !scalar @ARGV;

   Connection("questionnaires", ArgsGet("host", "username", "password"));

   PrintResponseVars       () if ArgIs("varsonly");
   PrintResponsesIDs       () if ArgIs("idsonly");
   PrintResponseTextOrphans() if ArgIs("orphans");
   PrintResponses          ();
   exit(0);


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


sub PrintResponses          
   { 
   my ($responses, $responsetexts) = ResponseData(); 

   my $title = "showing responses";
   $title .= " with english text"    if ArgIs("e" );
   $title .= " without english text" if ArgIs("ne"); 
   $title .= " with foreign text"    if ArgIs("f" ); 
   $title .= " without foreign text" if ArgIs("nf"); 
   $title .= " with var tags"        if ArgIs("v" ); 

   PrintStart($title);

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$responses})
      {
      my $response = $responses->{$id};

      next unless PassesResponseFilters($response);

      my $responsetext = $responsetexts->{$id} || {};
      my $etext = $responsetext->{$english_lang_id};
      my $ftext = $responsetext->{$foreign_lang_id};

      next unless PassesTextFilters($etext->{text}, $ftext->{text});
      next unless PassesIdFilters($id, $etext->{id}, $ftext->{id});
                                   
      PrintResponseStart($response);
      PrintQVar  ("English"        , $response, $etext);
      PrintQText ("English"        , $response, $etext);
      PrintQVar  ("Foreign"        , $response, $ftext);
      PrintQPar  ("Foreign"        , $response, $ftext);
      PrintQText ("Foreign"        , $response, $ftext);
      PrintQText ("English_Encoded", $response, $etext);
      PrintQText ("Foreign_Encoded", $response, $ftext);

      PrintResponseEnd($response);
      $count++;
      }
   PrintEnd ($count++)
   }

# special case #1
sub PrintResponseTextOrphans
   { 
   my ($responses, $responsetexts) = ResponseData();  

   print "\nresponsetext orphans (iq,responseid,langid,text):\n";
   print "=" x 100 . "\n";
   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$responsetexts})
      {
      my $responsetext = $responsetexts->{$id};
      foreach my $record (values %{$responsetext})
         {
         next if $record->{used};
         print "$record->{id} : $record->{responseId} : $record->{languageId} : $record->{text}\n";
         $count++;
         }
      }
   print "($count responsetexts)\n";
   }


# special case #2
sub PrintResponseVars
   { 
   my ($responses, $responsetexts) = ResponseData(); 

   my $title = "showing vars";
   $title .= " with english text"    if ArgIs("e" );
   $title .= " without english text" if ArgIs("ne"); 
   $title .= " with foreign text"    if ArgIs("f" ); 
   $title .= " without foreign text" if ArgIs("nf"); 
   $title .= " with var tags"        if ArgIs("v" ); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   foreach my $id (sort {$a<=>$b} keys %{$responses})
      {
      my $response = $responses->{$id};

      next unless PassesResponseFilters ($response);

      my $responsetext = $responsetexts->{$id} || {};
      PrintVars($responsetexts, $id, $english_lang_id);
      PrintVars($responsetexts, $id, $foreign_lang_id);
      }
   exit(0);
   }


# special case 3
sub PrintResponsesIDs
   { 
   my ($responses, $responsetexts) = ResponseData(); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();
   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$responses})
      {
      my $response = $responses->{$id};

      next unless PassesResponseFilters($response);

      my $responsetext = $responsetexts->{$id} || {};
      my $etext = $responsetext->{$english_lang_id};
      my $ftext = $responsetext->{$foreign_lang_id};

      next unless PassesTextFilters($etext->{text}, $ftext->{text});
      next unless PassesIdFilters($id, $etext->{id}, $ftext->{id});
                                   
      print "$id\n";
      }
   exit(0);
   }




sub PrintVars
   {
   my ($responsetexts, $responseid, $language) = @_;

   my $responsetext = $responsetexts->{$responseid} || return;
   my $record = $responsetext->{$language} || return;
   my $id   = $record->{id};
   my $text = $record->{text};
   my @vars = ($text =~ /(\<var.*?\<\/var\>)/gis);

   foreach my $var (@vars)
      {
      my ($varname) = $var =~ />(.*)<\/var>/i;

      #print "### $var ###\n" unless $varname;

      my $str = ArgIs("varnameonly") ? $varname : $var;

      print sprintf ("%5.5d %5.5d %s\n", $language, $id, $str);
      }
   }

sub PassesResponseFilters
   {
   my ($response) = @_;

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   return 0 if ArgIs("e"  ) && !$response->{"has_"      . $english_lang_id};
   return 0 if ArgIs("ne" ) &&  $response->{"has_"      . $english_lang_id};
   return 0 if ArgIs("f"  ) && !$response->{"has_"      . $foreign_lang_id};
   return 0 if ArgIs("nf" ) &&  $response->{"has_"      . $foreign_lang_id};
   return 0 if ArgIs("v"  ) && !$response->{"has_var"                     };
   return 0 if ArgIs("nv" ) &&  $response->{"has_var"                     };
   return 0 if ArgIs("ve" ) && !$response->{"has_var_"  . $english_lang_id};
   return 0 if ArgIs("vne") &&  $response->{"has_var__" . $english_lang_id};
   return 0 if ArgIs("vf" ) && !$response->{"has_var__" . $foreign_lang_id};
   return 0 if ArgIs("vnf") &&  $response->{"has_var__" . $foreign_lang_id};
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
   return 1 unless $id;
   return 1 unless ArgIs($pname);
   for (my $i=0; my $match = ArgGet($pname, $i); $i++) 
      {
      return 1 if $id == $match;
      }
   return 0;
   }



#############################################################################
#                                                                           #
#############################################################################

sub PrintStart 
   { 
   my ($title) = @_;

   my $tname = AppendType("Start");
   print Template($tname, title=>$title);
   }

sub PrintResponseStart
   { 
   my ($response) = @_;

   my $tname = AppendType("ResponseStart");
   print Template($tname, %{$response});
   }

sub PrintQText 
   { 
   my ($template_base, $response, $record) = @_;

   return unless $record;

   #if (ArgIs("vars"))
   #   {
   #   my @vars  = ($etext =~ /(\<var.*?\<\/var\>)/gis);
   #   my @pars  = ($ftext =~ /(\([^(]+\))/gi);
   #   my $tname = AppendType("ResponseVarText_" . $template_base);
   #   map {print Template($tname, label=>"var", var=>$_)} @vars;
   #   map {print Template($tname, label=>"par", var=>$_)} @pars;
   #   }

   my $tname = AppendType("ResponseText_" . $template_base);
   my $enctext = HtmlEncode($record->{text} || "");
   print Template($tname, %{$response}, %{$record}, enctext=>$enctext);
   }


sub PrintQVar
   { 
   my ($template_base, $response, $record) = @_;

   return unless $record;
   return unless ArgIs("vars");

   my @vars  = ($record->{text} =~ /(\<var.*?\<\/var\>)/gis);
   my $tname = AppendType("ResponseVarText_" . $template_base);
   map {print Template($tname, var=>$_)} @vars;
   }


sub PrintQPar
   { 
   my ($template_base, $response, $record) = @_;

   return unless $record;
   return unless ArgIs("vars");

   #my @pars  = ($record->{text} =~ /(\([^(]+\))/gi);
   my @pars  = map {AggressivelyCleanString($_)} ($record->{text} =~ /(\([^(]+\))/gi);


   my $tname = AppendType("ResponseParText_" . $template_base);
   map {print Template($tname, var=>$_)} @pars;
   }


sub PrintResponseEnd  
   { 
   my ($response) = @_;

   my $tname = AppendType("ResponseEnd");
   print Template($tname, %{$response});
   }

sub PrintEnd   
   { 
   my ($count) = @_;

   my $tname = AppendType("End");
   print Template($tname, count=>$count);
   }

sub AppendType
   {
   my ($tname) = @_;
   return $tname . (ArgIs("html") ? "_html" : "_txt");
   }

#############################################################################
#                                                                           #
#############################################################################

sub ResponseData
   {
   state $responses     = FetchHash("id"                        , "select * from responses"   );
   state $responsetexts = FetchHash(["responseId", "languageId"], "select * from responsetext where current=1");
   state $ok            = PrepResponseData ($responses, $responsetexts);

   return ($responses, $responsetexts);
   }


sub PrepResponseData               
   { 
   my ($responses, $responsetexts) = @_; 

   foreach my $response (values %{$responses})
      {
      my $responsetext = $responsetexts->{$response->{id}} || {};
      foreach my $record (values %{$responsetext})
         {
         $record->{used} = 1;
         $response->{"has_" . $record->{languageId}} = 1;

         $response->{has_var} = 1 if $record->{text} =~ /\<var/i;
         $response->{"has_var_" . $record->{languageId}} = 1 if $record->{text} =~ /\<var/i;
         }
      }
   return 1;
   }

sub AggressivelyCleanString
   {
   my ($string) = @_;

   $string =~ s/<\/?div[^>]*>//gi;                 # remove <div> tags
   $string =~ s/<\/?small[^>]*>//gi;               # remove <small> tags
   $string =~ s/<\/?span[^>]*>//gi;                # remove <span> tags
   $string =~ s/<\/?p[^>]*>//gi;                   # remove <p> tags
   $string =~ s/&nbsp;/ /gi;                       # remove &nbsp;
   $string =~ s/(<br\s*\/>){3,}/<br \/><br \/>/gi; # at most 2 consecutive <br />
   $string =~ s/<\/?b>//gi;                        # remove <b> tags

   return $string;
   }


__DATA__

[Start_txt]
$title
=======================================================================
[ResponseStart_txt]
response:$id
[ResponseText_English_txt]

responsetext:$id (english):
----------------------------------
$text

[ResponseText_Foreign_txt]

responsetext:$id (foreign):
----------------------------------
$text

responsetext:$id (new foreign):
----------------------------------
$text

[ResponseText_English_Encoded_txt]
[ResponseText_Foreign_Encoded_txt]
[ResponseVarText_English_txt]
var: $var
[ResponseVarText_Foreign_txt]
var: $var
[ResponseParText_English_txt]
[ResponseParText_Foreign_txt]
par: $var
[ResponseEnd_txt]
=======================================================================
[End_txt]
($count responses)
[Start_txt2]
$title
-----------------------------------------------------------------------
[ResponseStart_txt2]
response $id: $title
[ResponseText_English_txt2]
($languageId : $id) $text
[ResponseText_Foreign_txt2]
($languageId : $id) $text
[ResponseText_English_Encoded_txt2]
[ResponseText_Foreign_Encoded_txt2]
[ResponseVarText_English_txt2]
var: $var
[ResponseVarText_Foreign_txt2]
var: $var
[ResponseParText_English_txt2]
par: $var
[ResponseParText_Foreign_txt2]
par: $var
[ResponseEnd_txt2]
-----------------------------------------------------------------------
[End_txt2]
($count responses)
[Start_html]
<!DOCTYPE html>
<html>
   <head>
      <style>
      .response {
         position: relative;
         border: 2px solid #888; 
         margin: 4px; 
         padding: 5px;
         border-radius: 5px;
      }
      .qlabel {
         background-color: #eee;
      }
      .qtitle {
         font-size: 1.3em;
      }
      .qtext-e  {background-color: #ddf; padding-bottom: 0.5em}
      .qtext-s  {background-color: #fdd; padding-bottom: 0.5em}
      .qtext-ee {background-color: #eef; padding-bottom: 0.5em; font-size: 0.8em; border-top: 1px solid #888;}
      .qtext-se {background-color: #fee; padding-bottom: 0.5em; font-size: 0.8em}
      .qvar-e   {background-color: #ddf; padding-bottom: 0.2em}
      .qvar-s   {background-color: #fdd; padding-bottom: 0.2em}
      .enc {
      }
      .qtext-label {
         font-size: 0.75em;
         padding-top: 0.5em;
      }
      .qtext-text {
      }

      </style>
   </head>
   <body>
   <h3>$title</h3>
[ResponseStart_html]
      <div class="response">
         <div class="qlabel">response id:$id</div>
         <div class="qtitle">$title</div>
[ResponseVarText_English_html]
         <div class="qvar-e">var: $var</div>
[ResponseVarText_Foreign_html]
         <div class="qvar-s">var: $var</div>
[ResponseParText_English_html]
         <div class="qvar-e">par: $var</div>
[ResponseParText_Foreign_html]
         <div class="qvar-s">par: $var</div>
[ResponseText_English_html]
         <div class="qtext-e">
            <div class="qtext-label">responsetext id:$id  langid:$languageId</div>
            <div class="qtext-text">$text</div>
         </div>
[ResponseText_Foreign_html]
         <div class="qtext-s">
            <div class="qtext-label">responsetext id:$id  langid:$languageId</div>
            <div class="qtext-text">$text</div>
         </div>
[ResponseText_English_Encoded_html]
         <div class="qtext-ee enc">$enctext</div>
[ResponseText_Foreign_Encoded_html]
         <div class="qtext-se enc">$enctext</div>
[ResponseEnd_html]
      </div>
[End_html]
      <div>($count records)</div>
   </body>
</html>
[usage]
ResponseView.pl - Utility for dumping TriVox response string data

USAGE: ResponseView.pl [options]

WHERE: [options] is one or more of:
    -language=9999 . Specify language in addition to english (spanish)
    -all ........... Show all responses
    -e ............. Exclude all but responses that have english text
    -ne ............ Exclude all but responses that dont have english text
    -f ............. Exclude all but responses that have foreign text
    -nf ............ Exclude all but responses that dont have foreign text
    -v ............. Exclude all but responses that have vars
    -nv ............ Exclude all but responses that dont have vars
    -ve ............ Exclude all but responses that have english text vars
    -vf ............ Exclude all but responses that have foreign text vars
    -vne ........... Exclude all but responses that dont have english text vars
    -vnf ........... Exclude all but responses that dont have foreign text vars
    -vars .......... Include vars and parens
    -etext=str ..... Exclude all but responses that have this english text
    -ftext=str ..... Exclude all but responses that have this foreign text
    -id ............ Exclude all but responses with this response id
    -eid ........... Exclude all but responses with this responsetext id
    -fid ........... Exclude all but responses with this responsetext id
    -varsonly ...... Special case: only print <var>s
    -idsonly ....... Special case: only print responseids
    -host=foo ...... Set the mysqlhost (localhost)
    -username=foo .. Set the mysqlusername (avocate)
    -password=foo .. Set the mysqlpassword (****************)
    -html .......... Generate html (default is text)

EXAMPLES: 
    ResponseView.pl -lang=portuguese -all
    ResponseView.pl -e -f -v -html
    ResponseView.pl -host=trivox-db.cymcwhoejtz8.us-east-1.rds.amazonaws.com -all
    ResponseView.pl -language=spanish -e -f -ftext="&lt;"

NOTES:
    -language can be set to:
       spanish or 5912 for Spanish
       portuguese or 5265 for Portuguese
[fini]
