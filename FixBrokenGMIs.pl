#!perl
#
# FixBrokenGMIs.pl 
# fix broken groupmembershipinclusions
# 
# Craig Fitzgerald


use warnings;
use strict;
use feature 'state';
use Gnu::TinyDB;
use Gnu::Template qw(Template Usage);
use Gnu::ArgParse;
use Gnu::StringUtil qw(HtmlEncode Trim);

my @SKIP_GROUPS = (21, 22, 50, 51, 53, 55, 56, 57, 58, 59, 87, 89, 90);
my $GROUP_ADDS = {};

MAIN:
   $| = 1;
   ArgBuild("*^test *^doit *^host= *^username= *^password= *^help *^debug");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help");

   FixBrokenGMIs();
   exit(0);


sub FixBrokenGMIs
   {
   Connection("onlineadvocate", ArgsGet("host", "username", "password"));

   my $users = GetUsers();
   foreach my $user (@{$users})
      {
      FixBrokenUserGMIs($user);
      }
   print "Done!";
   PrintStats();
   }

sub PrintStats
   {
   foreach my $groupid (sort {$a<=>$b} keys %{$GROUP_ADDS})
      {
      print sprintf ("added %3d entries to group $groupid\n", $GROUP_ADDS->{$groupid});
      }
   }

sub GetUsers
   {
   my $sql = "SELECT u.* FROM onlineadvocate.users u join userdata.users on userid=u.id WHERE userstate='ACTIVE' order by u.id desc";
   return FetchArray($sql);
   }

sub FixBrokenUserGMIs
   {
   my ($user) = @_;

   my $self_ur       = GetUserSelfRelationship($user);
   my $responder_urs = GetResponderRelationships($user);
   my $groups        = GetSelfInclusions($self_ur);
   if (ArgIs("debug"))
      {
      print "Looking at data for user $user->{id}\n" if ArgIs("debug");
      print "   groups: ";
      print join(",", map{$_->{groupId}} @{$groups});
      print "\n";
      print "   responders:\n";
      foreach my $responder (@{$responder_urs})
         {
         print "      userrelationships id=$responder->{id},  relatedUserId=$responder->{relatedUserId}\n";
         }
      }
   foreach my $group (@{$groups})
      {
      foreach my $responder (@{$responder_urs})
         {
         next if ResponderInGroup($responder, $group);

         AddResponderGMI ($user, $responder, $group);
         }
      }
   }

sub GetUserSelfRelationship
   {
   my ($user) = @_;

   my $sql = "select * from userrelationships urp where userid=$user->{id} and pairtype='SELF' and isActive=1";
   return FetchRow($sql);
   }

sub GetResponderRelationships
   {
   my ($user) = @_;
   my $sql = "select * from userrelationships urp where userid=$user->{id} and pairtype='RESPONDER' and isActive=1";
   return FetchArray($sql);
   }

sub GetSelfInclusions
   {
   my ($self_gmi) = @_;

   my $sql = "select * from groupmembershipinclusions where userrelationshipid=$self_gmi->{id} and active=1";
   return FetchArray($sql);
   }

sub ResponderInGroup
   {
   my ($responder, $group) = @_;

   my $sql = "select count(*) as count from groupmembershipinclusions where userrelationshipid=$responder->{id} and groupId=$group->{groupId} and active=1";
   return FetchColumn($sql);
   }

sub AddResponderGMI 
   {
   my ($user, $responder, $group) = @_;

   #my $sql = "insert into groupmembershipinclusions"
   #          . " ('groupId', 'userRelationshipId', 'reason', 'startDate', 'lastModifiedTimestamp', 'lastModifiedBy') VALUES"
   #          . " (?, ?, 'Migrated', '2016-08-02 16:25:00', '2016-08-02 16:25:00', 1879'Migrated', '2016-08-02 16:25:00', '2016-08-02 16:25:00', 1879)"
   #ExecSQL ($sql, $group->{groupId}, $responder->{id});

   return if SkipGroup($group->{groupId});

   $GROUP_ADDS->{$group->{groupId}} = 0 unless exists $GROUP_ADDS->{$group->{groupId}};
   $GROUP_ADDS->{$group->{groupId}}++;

   my $sql = "insert into groupmembershipinclusions"
             . " (groupId, userRelationshipId, reason, startDate, lastModifiedTimestamp, lastModifiedBy) VALUES"
             . " ($group->{groupId}, $responder->{id}, 'Migrated per GroupCache Bug', '2016-08-03 15:21:00', '2016-08-03 15:21:00', 1879)";

   print "$sql\n";
   }


sub SkipGroup
   {
   my ($groupid) = @_;
   state $skip_groups = IdentityHash(@SKIP_GROUPS);

   return $skip_groups->{$groupid};
   }


sub IdentityHash
   {
   my (@arr) = @_;
   return {map{$_=>1} @arr};
   }




__DATA__

[usage]
FixBrokenGMIs.pl - fix groupmembershipinclusions

USAGE: FixBrokenGMIs.pl [options]

WHERE: [options] is one or more of:
   -test .............. run, but dont actually update the database
   -doit .............. run, actually update the database
   -host=foo .......... Set the mysqlhost (localhost)
   -username=foo ...... Set the mysqlusername (avocate)
   -password=foo ...... Set the mysqlpassword (****************)
   -debug.............. Use with -test to dump changes

EXAMPLES: 
   FixBrokenGMIs.pl -test
   FixBrokenGMIs.pl -doit
   FixBrokenGMIs.pl -test -host=test.me.com -username=bubba -password=password

NOTES:
   *** todo ***
[fini]