#!/usr/bin/perl
#
# <LJDEP>
# lib: Proc::ProcessTable, cgi-bin/ljlib.pl
# </LJDEP>

use strict;
use Getopt::Long
require "$ENV{'LJHOME'}/cgi-bin/ljlib.pl";

my $opt_foreground;
my $opt_debug;
exit 1 unless GetOptions('foreground' => \$opt_foreground,
                         'debug' => \$opt_debug,
                         );

BEGIN {
    $LJ::OPTMOD_PROCTABLE = eval "use Proc::ProcessTable; 1;";
}



my $DELAY = $LJ::QBUFFERD_DELAY || 15;

my $pidfile = $LJ::QBUFFERD_PIDFILE || "$ENV{'LJHOME'}/var/qbufferd.pid";
my $pid;
if (-e $pidfile) {
    open (PID, $pidfile);
    chomp ($pid = <PID>);
    close PID;
    if ($LJ::OPTMOD_PROCTABLE) {
        my $processes = Proc::ProcessTable->new()->table;
        if (grep { $_->cmndline =~ /perl.+qbufferd/ && $_->pid != $$ } @$processes) {
            exit;
        }
    } else {
        # since we can't really check
        exit;
    }
}

my $is_parent = 0;
my $running = 0;

END {
    unless ($is_parent || ! $running) {
        print "END-STOP\n";
        &stop_qbufferd();
    }
}

$SIG{'INT'} = \&stop_qbufferd;
$SIG{'TERM'} = \&stop_qbufferd;
$SIG{'HUP'} = sub { 
    # nothing.  maybe later make a HUP force a flush?
};

# Perhaps I should give it a command to not do this in the future.
if (!$opt_foreground && ($pid = fork)) 
{
    $is_parent = 1;
    unless (open (PID, ">$pidfile")) {
        kill 15, $pid;
        die "Couldn't write PID file.  Exiting.\n";
    }
    print PID $pid, "\n";
    close PID;
    print "qbufferd started with pid $pid\n";
    if (-s $pidfile) { print "pid file written ($pidfile)\n"; }
    exit;
} 

sub stop_qbufferd
{
    print "Quitting.\n";
    unlink $pidfile;
    exit;
}

$running = 1;
while (LJ::start_request())
{
    my $cycle_start = time();
    print "Starting cycle.\n" if $opt_debug;

    # do main cluster updates
    my $dbh = LJ::get_dbh("master");
    unless ($dbh) {
        sleep 10;
        next;
    }
    
    # keep track of what commands we've run the start hook for
    my %started;

    # handle clusters
    foreach my $c (@LJ::CLUSTERS) {
        print "Cluster: $c\n" if $opt_debug;
        my $db = LJ::get_cluster_master($c);
        next unless $db;

        my $sth = $db->prepare("SELECT cmd, COUNT(*) FROM cmdbuffer GROUP BY 1");
        $sth->execute;
        my @cmds;
        while (my ($cmd, $count) = $sth->fetchrow_array) {
            print "  $cmd ($count)\n" if $opt_debug;
            unless ($started{$cmd}++) {
                LJ::cmd_buffer_flush($dbh, $db, "$cmd:start");
            }
            LJ::cmd_buffer_flush($dbh, $db, $cmd);
        }
    }

    # run the end hook for all commands we've rn
    foreach my $cmd (keys %started) {
        LJ::cmd_buffer_flush($dbh, undef, "$cmd:finish");
    }
    

    print "Sleeping.\n" if $opt_debug;
    my $elapsed = time() - $cycle_start;
    sleep ($DELAY-$elapsed) if $elapsed < $DELAY;
};
