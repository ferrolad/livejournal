#!/usr/bin/perl
#

use strict;

require "$ENV{'LJHOME'}/cgi-bin/ljlib.pl";
my $dbh = LJ::get_dbh("master");
$dbh->{'RaiseError'} = 1;
$dbh->{'PrintError'} = 1;
my $sth;

$sth = $dbh->prepare("SELECT userid, clusterid, user, statusvisdate FROM user WHERE statusvis='D' AND statusvisdate < DATE_SUB(NOW(), INTERVAL 35 DAY) ORDER BY statusvisdate");
$sth->execute;
my @delusers;
my $czero = 0;
while (my $du = $sth->fetchrow_hashref) {
    if ($du->{'clusterid'}) {
	push @delusers, $du;
    } else {
	$czero++;
    }
}
print "Users to delete: ", scalar(@delusers), "\n";
print "Cluster 0: $czero (can't delete)\n" if $czero;

LJ::load_props($dbh, "talk");
my $p_delposter = LJ::get_prop("talk", "deleted_poster");
die "No 'deleted_poster' talkprop?" unless $p_delposter;
my $ids;

my $lastbreak = time();
my $pause = sub {
    if (time() - $lastbreak > 3) { print "pause.\n"; sleep(1); $lastbreak = time(); }
};

my $runsql = sub {
    my $db = $dbh;
    if (ref $_[0]) { $db = shift; }
    my $user = shift;
    my $sql = shift;
    print "  ($user) $sql\n";
    $db->do($sql);
};

foreach my $du (@delusers)
{
    my $uid = $du->{'userid'};
    my $user = $du->{'user'};
    print "$du->{'user'} ($du->{'userid'}) @ $du->{'statusvisdate'} (cluster $du->{'clusterid'})...\n";
    $pause->();

    # get a db handle for the cluster master.
    LJ::start_request(); # might've been awhile working with last handle, we don't want to be given an expired one.
    my $dbcm = LJ::get_cluster_master($du);
    $dbcm->{'RaiseError'} = 1;
    $dbcm->{'PrintError'} = 1;

    # make all the user's comments posted now be owned by posterid 0 (anonymous)
    # but with meta-data saying who used to own it
    # ..... hm, with clusters this is a pain.  let's not.
    
    # delete memories
    print "  memories\n";
    while (($ids = $dbh->selectcol_arrayref("SELECT memid FROM memorable WHERE userid=$uid LIMIT 100")) && @{$ids})
    {
	my $in = join(",", @$ids);
	print "  id: $in\n";
	$runsql->($dbh, $user, "DELETE FROM memkeyword WHERE memid IN ($in)");
	$runsql->($dbh, $user, "DELETE FROM memorable WHERE memid IN ($in)");
    }

    # delete todos
    print "  todos\n";
    while (($ids = $dbh->selectcol_arrayref("SELECT todoid FROM todo WHERE journalid=$uid LIMIT 100")) && @{$ids})
    {
	my $in = join(",", @$ids);
	print "  id: $in\n";
	$runsql->($dbh, $user, "DELETE FROM tododep WHERE todoid IN ($in)");
	$runsql->($dbh, $user, "DELETE FROM todokeyword WHERE todoid IN ($in)");
	$runsql->($dbh, $user, "DELETE FROM todo WHERE todoid IN ($in)");
    }

    # delete userpics
    print "  userpics\n";
    $ids = $dbh->selectcol_arrayref("SELECT picid FROM userpic WHERE userid=$uid");
    {
	my $in = join(",",@$ids);
	if ($in) {
	    print "  userpics: $in\n";
	    $runsql->($dbcm, $user, "DELETE FROM userpicblob2 WHERE userid=$uid AND picid IN ($in)");
	    $runsql->($dbh, $user, "DELETE FROM userpic WHERE userid=$uid");
	    $runsql->($dbh, $user, "DELETE FROM userpicmap WHERE userid=$uid");
	}
    }

    # delete posts
    print "  posts\n";
    while (($ids = $dbcm->selectall_arrayref("SELECT jitemid, anum FROM log2 WHERE journalid=$uid LIMIT 100")) && @{$ids})
    {
	foreach my $idanum (@$ids) {
	    my ($id, $anum) = ($idanum->[0], $idanum->[1]);
	    print "  deleting $id (a=$anum) ($uid; $du->{'user'})\n";
	    LJ::delete_item2($dbcm, $uid, $id, 0, $anum);
	    $pause->();
	}
    }

    # misc:
    $runsql->($user, "DELETE FROM userusage WHERE userid=$uid");
    $runsql->($user, "DELETE FROM friends WHERE userid=$uid");
    $runsql->($user, "DELETE FROM friends WHERE friendid=$uid");
    $runsql->($user, "DELETE FROM friendgroup WHERE userid=$uid");
    $runsql->($user, "DELETE FROM userbio WHERE userid=$uid");
    $runsql->($dbcm, $user, "DELETE FROM userbio WHERE userid=$uid");
    $runsql->($user, "DELETE FROM userinterests WHERE userid=$uid");
    $runsql->($user, "DELETE FROM userprop WHERE userid=$uid");
    $runsql->($user, "DELETE FROM userproplite WHERE userid=$uid");   
    $runsql->($user, "DELETE FROM txtmsg WHERE userid=$uid");   
    $runsql->($user, "DELETE FROM overrides WHERE user='$du->{'user'}'");
    $runsql->($user, "DELETE FROM priv_map WHERE userid=$uid");
    $runsql->($user, "DELETE FROM infohistory WHERE userid=$uid");
    $runsql->($user, "DELETE FROM reluser WHERE userid=$uid");
    $runsql->($user, "DELETE FROM reluser WHERE targetid=$uid");

    $runsql->($user, "UPDATE user SET statusvis='X', statusvisdate=NOW(), password='' WHERE userid=$uid");

}


