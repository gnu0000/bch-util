#!perl
#
# UifieldView.pl 
#
# This utility is for examining Uifield/langui text
#
# This utility is usefull for determining what problems exist, what 
#  foreign fields are missing, what <var> names are present, and generating
#  indexes of uifields that can be used with the web page editor.
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
#   Generate a html page of all the uifields:
#
#     UifieldView.pl -e -html > foo.html
#
#   Generate a html page of all the uifields and the protugeuse translations:
#
#     UifieldView.pl -language=portuguese -e -f -html > foo.html
#
#   Display all uifields (and associated langui) that have both english
#   and spanish text:
#
#     UifieldView.pl -language=spanish -e -f
#
#   Display all uifields (and associated langui) that have both english
#   and spanish text, and that have the "<" char encoded as an html entity
#   in ther spanish text:
#
#     UifieldView.pl -language=spanish -e -f -ftext="&lt;"
#
#   Create a web page containing all uifields (and associated langui) that 
#    have <var>'s in the english text, but dont have <var>'s in the spanish text
#
#     UifieldView.pl -language=spanish -e -f -ve -vnf -html > foo.html
#
#
#
#
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
            "^varsonly *^varnameonly *^idsonly *^orphans " .
            "*^etext= *^ftext= ^id= ^eid= ^fid= *^language= " .
            "*^html *^host= *^username= *^password= *^help *^debug");

   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   die ArgDump() if ArgIs("debug");
   Usage() if ArgIs("help") || !scalar @ARGV;

   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   PrintUIFieldVars  () if ArgIs("varsonly");
   PrintUIFieldsIDs  () if ArgIs("idsonly");
   PrintLanguiOrphans() if ArgIs("orphans");
   PrintUIFields     ();
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


sub PrintUIFields          
   { 
   my ($uifields, $languis) = UIFieldData(); 

   my $title = "showing uifields";
   $title .= " with english text"    if ArgIs("e" );
   $title .= " without english text" if ArgIs("ne"); 
   $title .= " with foreign text"    if ArgIs("f" ); 
   $title .= " without foreign text" if ArgIs("nf"); 
   $title .= " with var tags"        if ArgIs("v" ); 

   PrintStart($title);

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$uifields})
      {
      my $uifield = $uifields->{$id};

      next unless PassesUIFieldFilters($uifield);

      my $langui = $languis->{$id} || {};
      my $etext = $langui->{$english_lang_id};
      my $ftext = $langui->{$foreign_lang_id};

      next unless PassesTextFilters($etext->{value}, $ftext->{value});
      next unless PassesIdFilters($id, $etext->{id}, $ftext->{id});
                                   
      PrintUIFieldStart($uifield);
      PrintQVar  ("English"        , $uifield, $etext);
      PrintQText ("English"        , $uifield, $etext);
      PrintQVar  ("Foreign"        , $uifield, $ftext);
      PrintQPar  ("Foreign"        , $uifield, $ftext);
      PrintQText ("Foreign"        , $uifield, $ftext);
      PrintQText ("English_Encoded", $uifield, $etext);
      PrintQText ("Foreign_Encoded", $uifield, $ftext);

      PrintUIFieldEnd($uifield);
      $count++;
      }
   PrintEnd ($count++)
   }

# special case #1
sub PrintLanguiOrphans
   { 
   my ($uifields, $languis) = UIFieldData();  

   print "\nlangui orphans (id,uiid,langid,text):\n";
   print "=" x 100 . "\n";
   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$languis})
      {
      my $langui = $languis->{$id};
      foreach my $record (values %{$langui})
         {
         next if $record->{used};
         print "$record->{id} : $record->{uiId} : $record->{langId} : $record->{value}\n";
         $count++;
         }
      }
   print "($count languis)\n";
   }


# special case #2
sub PrintUIFieldVars
   { 
   my ($uifields, $languis) = UIFieldData(); 

   my $title = "showing vars";
   $title .= " with english text"    if ArgIs("e" );
   $title .= " without english text" if ArgIs("ne"); 
   $title .= " with foreign text"    if ArgIs("f" ); 
   $title .= " without foreign text" if ArgIs("nf"); 
   $title .= " with var tags"        if ArgIs("v" ); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   foreach my $id (sort {$a<=>$b} keys %{$uifields})
      {
      my $uifield = $uifields->{$id};

      next unless PassesUIFieldFilters ($uifield);

      my $langui = $languis->{$id} || {};
      PrintVars($languis, $id, $english_lang_id);
      PrintVars($languis, $id, $foreign_lang_id);
      }
   exit(0);
   }


# special case 3
sub PrintUIFieldsIDs
   { 
   my ($uifields, $languis) = UIFieldData(); 

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();
   my $count=0;
   foreach my $id (sort {$a<=>$b} keys %{$uifields})
      {
      my $uifield = $uifields->{$id};

      next unless PassesUIFieldFilters($uifield);

      my $langui = $languis->{$id} || {};
      my $etext = $langui->{$english_lang_id};
      my $ftext = $langui->{$foreign_lang_id};

      next unless PassesTextFilters($etext->{value}, $ftext->{value});
      next unless PassesIdFilters($id, $etext->{id}, $ftext->{id});
                                   
      print "$id\n";
      }
   exit(0);
   }




sub PrintVars
   {
   my ($languis, $uiid, $language) = @_;

   my $langui = $languis->{$uiid} || return;
   my $record = $langui->{$language} || return;
   my $id   = $record->{id};
   my $text = $record->{value};
   my @vars = ($text =~ /(\<var.*?\<\/var\>)/gis);

   foreach my $var (@vars)
      {
      my ($varname) = $var =~ />(.*)<\/var>/i;

      #print "### $var ###\n" unless $varname;

      my $str = ArgIs("varnameonly") ? $varname : $var;

      print sprintf ("%5.5d %5.5d %s\n", $language, $id, $str);
      }
   }

sub PassesUIFieldFilters
   {
   my ($uifield) = @_;

   my ($english_lang_id, $foreign_lang_id) = GetLanguageIds();

   return 0 if ArgIs("e"  ) && !$uifield->{"has_"      . $english_lang_id};
   return 0 if ArgIs("ne" ) &&  $uifield->{"has_"      . $english_lang_id};
   return 0 if ArgIs("f"  ) && !$uifield->{"has_"      . $foreign_lang_id};
   return 0 if ArgIs("nf" ) &&  $uifield->{"has_"      . $foreign_lang_id};
   return 0 if ArgIs("v"  ) && !$uifield->{"has_var"                     };
   return 0 if ArgIs("nv" ) &&  $uifield->{"has_var"                     };
   return 0 if ArgIs("ve" ) && !$uifield->{"has_var_"  . $english_lang_id};
   return 0 if ArgIs("vne") &&  $uifield->{"has_var__" . $english_lang_id};
   return 0 if ArgIs("vf" ) && !$uifield->{"has_var__" . $foreign_lang_id};
   return 0 if ArgIs("vnf") &&  $uifield->{"has_var__" . $foreign_lang_id};
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
          PassesIdFilter($sid, "sid") ;
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

sub PrintUIFieldStart
   { 
   my ($uifield) = @_;

   my $tname = AppendType("UIFieldStart");
   print Template($tname, %{$uifield});
   }

sub PrintQText 
   { 
   my ($template_base, $uifield, $record) = @_;

   return unless $record;

   #if (ArgIs("vars"))
   #   {
   #   my @vars  = ($etext =~ /(\<var.*?\<\/var\>)/gis);
   #   my @pars  = ($ftext =~ /(\([^(]+\))/gi);
   #   my $tname = AppendType("UIFieldVarText_" . $template_base);
   #   map {print Template($tname, label=>"var", var=>$_)} @vars;
   #   map {print Template($tname, label=>"par", var=>$_)} @pars;
   #   }

   my $tname = AppendType("UIFieldText_" . $template_base);
   my $enctext = HtmlEncode($record->{value} || "");
   print Template($tname, %{$uifield}, %{$record}, enctext=>$enctext);
   }


sub PrintQVar
   { 
   my ($template_base, $uifield, $record) = @_;

   return unless $record;
   return unless ArgIs("vars");

   my @vars  = ($record->{value} =~ /(\<var.*?\<\/var\>)/gis);
   my $tname = AppendType("UIFieldVarText_" . $template_base);
   map {print Template($tname, var=>$_)} @vars;
   }


sub PrintQPar
   { 
   my ($template_base, $uifield, $record) = @_;

   return unless $record;
   return unless ArgIs("vars");

   #my @pars  = ($record->{value} =~ /(\([^(]+\))/gi);
   my @pars  = map {AggressivelyCleanString($_)} ($record->{value} =~ /(\([^(]+\))/gi);


   my $tname = AppendType("UIFieldParText_" . $template_base);
   map {print Template($tname, var=>$_)} @pars;
   }


sub PrintUIFieldEnd  
   { 
   my ($uifield) = @_;

   my $tname = AppendType("UIFieldEnd");
   print Template($tname, %{$uifield});
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

sub UIFieldData
   {
   state $uifields = FetchHash("id"              , "select * from uifields");
   state $languis  = FetchHash(["uiId", "langId"], "select * from langui");
   state $ok       = PrepUIFieldData ($uifields, $languis);

   return ($uifields, $languis);
   }

sub PrepUIFieldData               
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
[UIFieldStart_txt]
uifield:$id
[UIFieldText_English_txt]

langui:$id (english):
----------------------------------
$value

[UIFieldText_Foreign_txt]

langui:$id (foreign):
----------------------------------
$value

langui:$id (new foreign):
----------------------------------
$value

[UIFieldText_English_Encoded_txt]
[UIFieldText_Foreign_Encoded_txt]
[UIFieldVarText_English_txt]
var: $var
[UIFieldVarText_Foreign_txt]
var: $var
[UIFieldParText_English_txt]
[UIFieldParText_Foreign_txt]
par: $var
[UIFieldEnd_txt]
=======================================================================
[End_txt]
($count uifields)
[Start_txt2]
$title
-----------------------------------------------------------------------
[UIFieldStart_txt2]
uifield $id: $title
[UIFieldText_English_txt2]
($langId : $id) $value
[UIFieldText_Foreign_txt2]
($langId : $id) $value
[UIFieldText_English_Encoded_txt2]
[UIFieldText_Foreign_Encoded_txt2]
[UIFieldVarText_English_txt2]
var: $var
[UIFieldVarText_Foreign_txt2]
var: $var
[UIFieldParText_English_txt2]
par: $var
[UIFieldParText_Foreign_txt2]
par: $var
[UIFieldEnd_txt2]
-----------------------------------------------------------------------
[End_txt2]
($count uifields)
[Start_html]
<!DOCTYPE html>
<html>
   <head>
      <style>
      .uifield {
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
[UIFieldStart_html]
      <div class="uifield">
         <div class="qlabel">uifield id:$id</div>
         <div class="qtitle">$title</div>
[UIFieldVarText_English_html]
         <div class="qvar-e">var: $var</div>
[UIFieldVarText_Foreign_html]
         <div class="qvar-s">var: $var</div>
[UIFieldParText_English_html]
         <div class="qvar-e">par: $var</div>
[UIFieldParText_Foreign_html]
         <div class="qvar-s">par: $var</div>
[UIFieldText_English_html]
         <div class="qtext-e">
            <div class="qtext-label">langui id:$id  langid:$langId</div>
            <div class="qtext-text">$value</div>
         </div>
[UIFieldText_Foreign_html]
         <div class="qtext-s">
            <div class="qtext-label">langui id:$id  langid:$langId</div>
            <div class="qtext-text">$value</div>
         </div>
[UIFieldText_English_Encoded_html]
         <div class="qtext-ee enc">$enctext</div>
[UIFieldText_Foreign_Encoded_html]
         <div class="qtext-se enc">$enctext</div>
[UIFieldEnd_html]
      </div>
[End_html]
      <div>($count records)</div>
   </body>
</html>
[usage]
UifieldView.pl - Utility for displaying TriVox uifield string data in
                 text or html

USAGE: UifieldView.pl [options]

WHERE: [options] is one or more of:
    -language=9999 . Specify language in addition to english (spanish)
    -all ........... Show all uifields
    -e ............. Exclude all but uifields that have english text
    -ne ............ Exclude all but uifields that dont have english text
    -f ............. Exclude all but uifields that have foreign text
    -nf ............ Exclude all but uifields that dont have foreign text
    -v ............. Exclude all but uifields that have vars
    -nv ............ Exclude all but uifields that dont have vars
    -ve ............ Exclude all but uifields that have english text vars
    -vf ............ Exclude all but uifields that have foreign text vars
    -vne ........... Exclude all but uifields that dont have english text vars
    -vnf ........... Exclude all but uifields that dont have foreign text vars
    -vars .......... Include vars and parens
    -etext=str ..... Exclude all but uifields that have this english text
    -ftext=str ..... Exclude all but uifields that have this foreign text
    -varsonly ...... Special case: only print <var>s
    -idsonly ....... Special case: only print uifield ids
    -orphans ....... Special case: print orphaned langui
    -id ............ Exclude all but uifields with this uifield id
    -eid ........... Exclude all but uifields with this langui id
    -fid ........... Exclude all but uifields with this langui id
    -host=foo ...... Set the mysqlhost (localhost)
    -username=foo .. Set the mysqlusername (avocate)
    -password=foo .. Set the mysqlpassword (****************)
    -html .......... Generate html (default is text)

EXAMPLES: 
    UifieldView.pl -lang=portuguese -all
    UifieldView.pl -e -f -v -html
    UifieldView.pl -host=trivox-db.cymcwhoejtz8.us-east-1.rds.amazonaws.com -all
    UifieldView.pl -language=spanish -e -f -ftext="&lt;"

NOTES:
    -language can be set to:
       spanish or 5912 for Spanish
       portuguese or 5265 for Portuguese
[fini]
