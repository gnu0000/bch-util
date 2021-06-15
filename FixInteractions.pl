#!perl
#
# FixInteractions.pl
#
# This utility is for fixing broken groupids in unteractionTemplates 1/12/2017
#
use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;

my $GROUPMAP = {
   '26'  => '26,64,67,103'    ,
   '64'  => '26,64,67,103'    ,
   '67'  => '26,64,67,103'    ,
   '103' => '26,64,67,103'    ,
   '25'  => '25,63,66,83,102' ,
   '63'  => '25,63,66,83,102' ,
   '66'  => '25,63,66,83,102' ,
   '83'  => '25,63,66,83,102' ,
   '102' => '25,63,66,83,102' ,
   '27'  => '27,65,68,85,104' ,
   '65'  => '27,65,68,85,104' ,
   '68'  => '27,65,68,85,104' ,
   '85'  => '27,65,68,85,104' ,
   '104' => '27,65,68,85,104' 
};


MAIN:
   ArgBuild("*^userid= *^host= *^username= *^password= ^help ^debug");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   #Usage() if ArgIs("help") || !ArgIs("userid");

   Connection("onlineadvocate", ArgsGet("host", "username", "password"));
   FixInteractions();
   exit(0);


sub FixInteractions
   {
   my $sql = "select * from interactiontemplates where createdTimestamp > '2017-01-10'";
   my $its = FetchArray($sql);
   my $count = scalar @{$its};

   print "Examining the last $count interactions\n";
   map {FixInteraction($_)} @{$its};
   }


sub FixInteraction
   {
   my ($it) = @_;

   my $gmap = $GROUPMAP->{$it->{responderGroupIds}};
   return unless $gmap;

   # first, we fix the responderGroupIds
   print "Adjusting the interactiontemplate.responderGroupIds for id $it->{id} from $it->{responderGroupIds} to $gmap\n";
   Exec("update interactiontemplates set responderGroupIds='$gmap' where id=$it->{id}");

   # next we fix the state if necessary
   # not processed: no action
   return unless $it->{status} =~ /PROCESSED/;

   # if we have interactions: no action
   return if FetchColumn("select count(*) from consolidatedinteractiontemplates where interactionTemplateId=$it->{id}");

   # change the state
   print "Adjusting the interactiontemplate.status for id $it->{id} to NOT_PROCESSED\n\n";
   Exec("update interactiontemplates set status='NOT_PROCESSED' where id=$it->{id}");
   }

sub Exec
   {
   my ($query) = @_;
   
   #print "$query\n";
   ExecSQL ($query) unless ArgIs("debug");
   }

__DATA__

[usage]
todo ...