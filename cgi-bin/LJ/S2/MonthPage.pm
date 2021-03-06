#!/usr/bin/perl
#

use strict;
package LJ::S2;

use LJ::TimeUtil;
use LJ::UserApps;
use LJ::DelayedEntry;
use LJ::Entry::Repost;

sub MonthPage
{
    my ($u, $remote, $opts) = @_;

    my $get = $opts->{'getargs'};

    my $p = Page($u, $opts);
    $p->{'_type'} = "MonthPage";
    $p->{'view'} = "month";
    $p->{'days'} = [];
    $p->{'head_content'}->set_object_type( $p->{'_type'} );

    my $ctx = $opts->{'ctx'};

    my $dbcr = LJ::get_cluster_reader($u);

    my $user = $u->{'user'};
    my $journalbase = LJ::journal_base($user, $opts->{'vhost'});

    my ($year, $month);
    if ($opts->{'pathextra'} =~ m!^/(\d\d\d\d)/(\d\d)\b!) {
        ($year, $month) = ($1, $2);
    }

    $opts->{'errors'} = [];
    if ($month < 1 || $month > 12) { push @{$opts->{'errors'}}, "Invalid month: $month"; }
    if ($year < 1970 || $year > 2038) { push @{$opts->{'errors'}}, "Invalid year: $year"; }
    unless ($dbcr) { push @{$opts->{'errors'}}, "Database temporarily unavailable"; }
    return if @{$opts->{'errors'}};

    $p->{'date'} = Date($year, $month, 0);

    # load the log items
    my $dateformat = "%Y %m %d %H %i %s %w"; # yyyy mm dd hh mm ss day_of_week
    my $sth;

    my $secwhere = "AND l.security='public'";
    my $viewall = 0;
    my $viewsome = 0;
    if ($remote) {

        # do they have the viewall priv?
        if ($get->{'viewall'} && LJ::check_priv($remote, "canview", "suspended")) {
            LJ::statushistory_add($u->{'userid'}, $remote->{'userid'},
                                  "viewall", "month: $user, statusvis: $u->{'statusvis'}");
            $viewall = LJ::check_priv($remote, 'canview', '*');
            $viewsome = $viewall || LJ::check_priv($remote, 'canview', 'suspended');
        }

        if ($remote && $remote->can_manage($u) || $viewall) {
            $secwhere = "";   # see everything
        } elsif ($remote->{'journaltype'} eq 'P') {
            my $gmask = LJ::get_groupmask($u, $remote);
            $secwhere = "AND (l.security='public' OR (l.security='usemask' AND l.allowmask & $gmask))"
                if $gmask;
        }
    }

    $sth = $dbcr->prepare("SELECT l.jitemid, l.posterid, l.anum, l.day, ".
                          "       DATE_FORMAT(l.eventtime, '$dateformat') AS 'alldatepart', ".
                          "       l.replycount, l.security, l.allowmask ".
                          "FROM log2 l ".
                          "WHERE l.journalid=? AND l.year=? AND l.month=? ".
                          "$secwhere LIMIT 2000");
    $sth->execute($u->{userid}, $year, $month);

    my @items;
    push @items, $_ while $_ = $sth->fetchrow_hashref;
    
    @items = sort { $a->{'alldatepart'} cmp $b->{'alldatepart'} } @items;

    my @itemids = map { $_->{'jitemid'} } @items;

    # load the log properties
    my %logprops = ();
    LJ::load_log_props2($u->{'userid'}, \@itemids, \%logprops);
    my $lt = LJ::get_logtext2($u, @itemids);

    my (%pu, %pu_lite);  # poster users; UserLite objects
    foreach (@items) {
        $pu{$_->{'posterid'}} = undef;
    }
    LJ::load_userids_multiple([map { $_, \$pu{$_} } keys %pu], [$u]);
    $pu_lite{$_} = UserLite($pu{$_}) foreach keys %pu;

    my %day_entries;  # <day> -> [ Entry+ ]

    my $opt_text_subjects = S2::get_property_value($ctx, "page_month_textsubjects");
    my $userlite_journal = UserLite($u);

  ENTRY:
    foreach my $item (@items)
    {
        my ($posterid, $itemid, $security, $allowmask, $alldatepart, $replycount, $anum) =
            map { $item->{$_} } qw(posterid jitemid security allowmask alldatepart replycount anum);
        my $subject = $lt->{$itemid}->[0];
        my $day = $item->{'day'};
        my $journalu = $u;

        my $ditemid = $itemid*256 + $anum;
        my $entry_obj  = LJ::Entry->new($u, ditemid => $ditemid);
        $entry_obj->handle_prefetched_props($logprops{$itemid}); 

        my $repost_entry_obj;
        my $removed;
        my $lite_journalu = $userlite_journal;

        my $content =  { 'original_post_obj' => \$entry_obj,
                         'repost_obj'        => \$repost_entry_obj,
                         'ditemid'           => \$ditemid,
                         'itemid'            => \$itemid,
                         'journalu'          => \$journalu,                        
                         'posterid'          => \$posterid,
                         'security'          => \$security,
                         'allowmask'         => \$allowmask,
                         'subject_repost'    => \$subject,
                         'removed'           => \$removed,
                         'reply_count'       => \$replycount, };

        if (LJ::Entry::Repost->substitute_content( $entry_obj, $content )) {
            next ENTRY if $removed; 
            next ENTRY unless $entry_obj->visible_to($remote);

            $pu{$posterid} = $entry_obj->poster;
            $lite_journalu =  UserLite($entry_obj->journal);
            $pu_lite{$posterid} = UserLite($entry_obj->poster);
        }

        # don't show posts from suspended users or suspended posts
        my $pu = $pu{$posterid};
        next unless $pu;
        next ENTRY if $pu->is_suspended eq 'S' && !$viewsome;
        next ENTRY if $entry_obj && $entry_obj->is_suspended_for($remote);
        if ( !$viewsome && $pu && $pu->is_deleted
          && !$LJ::JOURNALS_WITH_PROTECTED_CONTENT{$pu->username} )
        {
            my ($purge_comments, $purge_community_entries)
                = split /:/, $pu->prop("purge_external_content");

            next ENTRY if $purge_community_entries;
        }

        if ($LJ::UNICODE && $logprops{$itemid}->{'unknown8bit'}) {
                my $text;
            LJ::item_toutf8($journalu, \$subject, \$text, $logprops{$itemid});
        }
        
        if ($opt_text_subjects) {
            LJ::CleanHTML::clean_subject_all(\$subject);
        } else {
            LJ::CleanHTML::clean_subject(\$subject);
        }

        my $permalink = $entry_obj->permalink_url;
        my $readurl   = $entry_obj->comments_url;
        my $posturl   = $entry_obj->reply_url;

        my $comments = CommentInfo({
            'read_url' => $readurl,
            'post_url' => $posturl,
            'count' => $replycount,
            'maxcomments' => ($replycount >= LJ::get_cap($journalu, 'maxcomments')) ? 1 : 0,
            'enabled' => $entry_obj->comments_shown,
            'locked' => !$entry_obj->posting_comments_allowed,
            'screened' => ($logprops{$itemid}->{'hasscreened'} && $remote &&
                           ($remote->user eq $journalu->user || $remote->can_manage($journalu))) ? 1 : 0,
        });

        my $userlite_poster = $lite_journalu;
        my $userpic = $p->{'journal'}->{'default_pic'};
        if ($u->{'userid'} != $posterid) {
            $userlite_poster = $pu_lite{$posterid};
            my $pickw = LJ::Entry->userpic_kw_from_props($logprops{$itemid});
            $userpic = Image_userpic($pu{$posterid}, 0, $pickw);
        }

        my $entry = Entry($journalu, {
            'subject' => $subject,
            'text' => "",
            'dateparts' => $alldatepart,
            'system_dateparts' => $item->{system_alldatepart},
            'security' => $security,
            'allowmask' => $allowmask,
            'props' => $logprops{$itemid},
            'itemid' => $ditemid,
            'journal' => $lite_journalu,
            'poster' => $userlite_poster,
            'comments' => $comments,
            'userpic' => $userpic,
            'permalink_url' => $permalink,
            'real_journalid' => $repost_entry_obj ? $repost_entry_obj->journalid : undef,
            'real_itemid'    => $repost_entry_obj ? $repost_entry_obj->jitemid : undef,
        });

        push @{$day_entries{$day}}, $entry;
    }

    my $days_month = LJ::TimeUtil->days_in_month($month, $year);
    for my $day (1..$days_month) {
        my $entries = $day_entries{$day} || [];
        my $month_day = {
            '_type' => 'MonthDay',
            'date' => Date($year, $month, $day),
            'day' => $day,
            'has_entries' => scalar @$entries > 0,
            'num_entries' => scalar @$entries,
            'url' => $journalbase . sprintf("/%04d/%02d/%02d/", $year, $month, $day),
            'entries' => $entries,
        };
        push @{$p->{'days'}}, $month_day;
    }

    # populate redirector
    my $vhost = $opts->{'vhost'};
    $vhost =~ s/:.*//;
    $p->{'redir'} = {
        '_type' => "Redirector",
        'user' => $u->{'user'},
        'vhost' => $vhost,
        'type' => 'monthview',
        'url' => "$LJ::SITEROOT/go.bml",
    };
    
    # figure out what months have been posted into
    my $nowval = $year*12 + $month;

    $p->{'months'} = [];

    my $days = LJ::get_daycounts($u, $remote) || [];
    my $lastmo;
    foreach my $day (@$days) {
        my ($oy, $om) = ($day->[0], $day->[1]);
        my $mo = "$oy-$om";
        next if $mo eq $lastmo;
        $lastmo = $mo;

        my $date = Date($oy, $om, 0);
        my $url = $journalbase . sprintf("/%04d/%02d/", $oy, $om);
        push @{$p->{'months'}}, {
            '_type' => "MonthEntryInfo",
            'date' => $date,
            'url' => $url,
            'redir_key' => sprintf("%04d%02d", $oy, $om),
        };

        my $val = $oy*12+$om;
        if ($val < $nowval) {
            $p->{'prev_url'} = $url;
            $p->{'prev_date'} = $date;
        }
        if ($val > $nowval && ! $p->{'next_date'}) {
            $p->{'next_url'} = $url;
            $p->{'next_date'} = $date;
        }
    }

    return $p;
}

1;
