#!perl
# -- a minimized version of this script, trades readibility for brevity
use feature 'state';
use Gnu::TinyDB;
use Gnu::FileUtil qw(SlurpFile);

Connection("onlineadvocate");
my $data = FetchHash("id", "select id, email from users");
foreach my $id (sort {$a<=>$b} keys %{$data})
   {
   next if $id == 24379 || $id == 1879; # skip me and pete
   #ExecSQL("update users set firstName=?, lastName=?, email=?, mobilePhone=null where id=?", GenFirstName(), GenLastName(), 'e'.$id.'@onlineadvocate.org', $id);
   print("update users set firstName='".GenFirstName()."' lastName='".GenLastName()."', email='".'e'.$id.'@onlineadvocate.org'."', mobilePhone=null where id=".$id."\n");
   }

sub GenFirstName
   {
   state $names = [split(/\n/, SlurpFile("firstnames.dat"))];
   return Camelize($names->[int(rand(scalar @{$names}))]);
   }

sub GenLastName
   {
   state $names = [split(/\n/, SlurpFile("lastnames.dat"))];
   return Camelize($names->[int(rand(scalar @{$names}))]);
   }

sub Camelize 
   {
   my ($s) = @_;
   $s =~ s{(\w+)}{($a=lc $1)=~ s<(^[a-z]|_[a-z])><($b=uc $1)=~ s/^_//;$b;>eg;$a;}eg;
   $s;
   }