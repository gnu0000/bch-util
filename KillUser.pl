#!perl
#
# KillUser.pl
#
# This utility is for deleting a Trivox user
#
use warnings;
use strict;
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;

MAIN:
   ArgBuild("*^userid= *^host= *^username= *^password= ^help ^debug");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs("userid");

   Connection("onlineadvocate", ArgsGet("host", "username", "password"));
   KillUser(ArgGet("userid"));
   exit(0);


sub KillUser
   {
   my ($userid) = @_;

   # onlineadvocate
   my $qtrms = FetchArray("select id from onlineadvocate.userrelationships where userid=$userid or relatedUserId=$userid");
   map {Exec("delete from onlineadvocate.groupmembershipinclusions where userRelationshipId=". $_->{id})} @{$qtrms};
   Exec("delete from onlineadvocate.userrelationships          where userid=$userid or relatedUserId=$userid");
   Exec("delete from onlineadvocate.users                      where id=$userid"               );
   Exec("delete from onlineadvocate.userblobdata               where userid=$userid"           );
   Exec("delete from onlineadvocate.userblobdatadeclarations   where userid=$userid"           );
   Exec("delete from onlineadvocate.usercontactinfo            where userid=$userid"           );
   Exec("delete from onlineadvocate.usermobiledevices          where userid=$userid"           );
   Exec("delete from onlineadvocate.usersystemroles            where userid=$userid"           );
   Exec("delete from onlineadvocate.associatedinteractionusers where associatedUserId=$userid" );
   Exec("delete from onlineadvocate.emailernonces              where RecipientUserId=$userid"  );
   Exec("delete from onlineadvocate.emailverification          where userId=$userid"           );
   Exec("delete from onlineadvocate.groupcontentsubscribers    where subscriberId=$userid"     );
   Exec("delete from onlineadvocate.interactiondata            where userId=$userid"           );
   Exec("delete from onlineadvocate.interactiondata            where responderId=$userid"      );
   Exec("delete from onlineadvocate.login                      where userId=$userid"           );
   Exec("delete from onlineadvocate.remoteaccesslinks          where userId=$userid"           );

   # notifications
   Exec("delete from notifications.messageoutbox               where recipientUserId=$userid"  );
   Exec("delete from notifications.postednotifications         where recipientUserId=$userid"  );
   Exec("delete from notifications.storedmessages              where userId=$userid"           );
   Exec("delete from notifications.usermessagetypepreferences  where userId=$userid"           );
   Exec("delete from notifications.usernotificationpreferences where userId=$userid"           );

   # researchdata
   my $us = FetchArray("select id from researchdata.userscreenings where userid=$userid or responderUserId=$userid");
   map {Exec("delete from researchdata.userquestionnairedata  where userscreeningsid=". $_->{id})} @{$us};
   Exec("delete from researchdata.userscreenings where userid=$userid or responderUserId=$userid");
   Exec("delete from researchdata.calculationresult  where SubjectUserId=$userid or ResponderUserId=$userid" );
   Exec("delete from researchdata.evaluationresult   where SubjectUserId=$userid or ResponderUserId=$userid" );
   Exec("delete from researchdata.questionresult     where SubjectUserId=$userid or ResponderUserId=$userid" );

   # userdata
   Exec("delete from userdata.users      where userid=$userid");
   Exec("delete from userdata.userroles  where userid=$userid");
   }


sub Exec
   {
   my ($query) = @_;
   
   print "$query\n";
   ExecSQL ($query) unless ArgIs("debug");
   }


#############################################################################
#                                                                           #
#############################################################################

__DATA__

[usage]
KillUser    - Eradicate a Trivox user from existence!

USAGE: KillUser.pl [options]

WHERE: [options] are one or more of:
   -userId=99999 ...... Kill user with this id
   -debug ............. Print out lots of info
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)

EXAMPLES:
   KillUser.pl -userid=16034
