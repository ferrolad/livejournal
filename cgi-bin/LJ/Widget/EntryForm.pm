package LJ::Widget::EntryForm;

use strict;
use base 'LJ::Widget';
use LJ::Widget::Calendar;

use LJ::Fotki::Photo;
use LJ::Fotki::Album;
use LJ::Widget::Fotki::Upload;


sub set_data {
    my ($self, $opts, $head, $onload, $errors, $js) = @_;
    $self->{'opts'} = $opts;
    $self->{'head'} = $head;
    $self->{'onload'} = $onload;
    $self->{'errors'} = $errors;
    $self->{'js'} = $js;
}

sub opts {
    my ($self) = @_;
    return $self->{'opts'} || {};
}

sub head {
    my ($self) = @_;
    my $dummy_head;
    return $self->{'head'} || \$dummy_head;
}

sub onload {
    my ($self) = @_;
    my $dummy_onload;
    return $self->{'onload'} || \$dummy_onload;
}

sub errors {
    my ($self) = @_;
    return $self->{'errors'} || {};
}

sub js {
    my ($self) = @_;
    my $dummy_js;
    return $self->{'js'} || \$dummy_js;
}

sub remote {
    my ($self) = @_;
    return $self->opts->{'remote'};
}

sub altlogin {
    my ($self) = @_;
    return $self->opts->{'altlogin'};
}

sub usejournal {
    my ($self) = @_;
    return $self->opts->{'usejournal'};
}

# do a login action to get pics and usejournals, but only if using remote
sub login_data {
    my ($self) = @_;
    my $opts = $self->opts;

    return undef unless $opts->{'auth_as_remote'};

    $self->{'login_data'} ||= LJ::Protocol::do_request("login", {
        "ver" => $LJ::PROTOCOL_VER,
        "username" => $self->remote->username,
        "getpickws" => 1,
        "getpickwurls" => 1,
    }, undef, {
        "noauth" => 1,
        "u" => $self->remote,
    });

    return $self->{'login_data'};
}

sub should_show_userpics {
    my ($self) = @_;

    my $login_data = $self->login_data;

    return 0 if $self->altlogin;
    return 0 unless $login_data;
    return 0 unless ref $login_data->{'pickws'} eq 'ARRAY';
    return 0 unless scalar @{$login_data->{'pickws'}} > 0;

    return 1;
}

sub should_show_userpicselect {
    my ($self) = @_;

    return 0 if $LJ::DISABLED{userpicselect};
    return $self->remote->get_cap('userpicselect');
}

sub should_show_lastfm {
    my ($self) = @_;

    return $self->opts->{'prop_last_fm_user'} ? 1 : 0;
}

sub tabindex {
    my ($self) = @_;

    $self->{'tabindex'} ||= 10;
    return $self->{'tabindex'}++;
}

sub rte_not_supported {
    return LJ::conf_test(
        $LJ::DISABLED{'rte_support'},
        BML::get_client_header("User-Agent")
    );
}

sub should_show_geolocation {
    my ($self) = @_;

    return 0 if $IpMap::VERSION lt "1.1.0";
    return 0 if $LJ::DISABLED{'geo_location_update'};
    return 1;
}

sub should_show_friendgroups {
    my ($self) = @_;
    my $login_data = $self->login_data;

    my $usejournalu = LJ::load_user($self->usejournal);

    return 0 unless $login_data;
    return 0 unless ref $login_data->{'friendgroups'} eq 'ARRAY';
    return 0 unless @{$login_data->{'friendgroups'}};
    return 0 if $usejournalu && $usejournalu->is_comm;
    return 1;
}

sub lastfm_geolocation_width {
    my ($self) = @_;

    my $ret_width = 0;
    $ret_width = 32 if $self->should_show_geolocation;
    $ret_width = 45 if $self->should_show_lastfm;

    return ('style' => "width: $ret_width\%;");
}

sub need_res {
    my ($self) = @_;
    my $opts = $self->opts;

    my @ret;

    push @ret, qw(
        js/ippu.js
        js/lj_ippu.js
        js/ck/ckeditor.js
        js/rte.js
        stc/display_none.css
    );

    if ($self->should_show_userpics && $self->should_show_userpicselect) {
        push @ret, qw(
            js/json.js
            js/template.js
            js/userpicselect.js
            js/httpreq.js
            js/hourglass.js
            js/inputcomplete.js
            stc/ups.css
            js/datasource.js
            js/selectable_table.js
        );
    }

    if ($self->should_show_lastfm) {
        push @ret, qw(
            js/lastfm.js
            js/jobstatus.js
        );
    }

    return @ret;
}

sub wrap_js {
    my ($class, $code) = @_;

    return qq{
        <script type="text/javascript">
        // <![CDATA[
            $code
        // ]]>
        </script>
    };
}

sub render_userpicselect_js {
    my ($self) = @_;

    return $self->wrap_js(q{
        DOM.addEventListener(window, "load", function (evt) {
            // attach userpicselect code to userpicbrowse button
                var ups_btn = $("lj_userpicselect");
                var ups_btn_img = $("lj_userpicselect_img");
            if (ups_btn) {
                DOM.addEventListener(ups_btn, "click", function (evt) {
                    var ups = new UserpicSelect();
                    ups.init();
                    ups.setPicSelectedCallback(function (picid, keywords) {
                        var kws_dropdown = $("prop_picture_keyword");

                        if (kws_dropdown) {
                            var items = kws_dropdown.options;

                            // select the keyword in the dropdown
                            keywords.forEach(function (kw) {
                                for (var i = 0; i < items.length; i++) {
                                    var item = items[i];
                                    if (item.value == kw) {
                                        kws_dropdown.selectedIndex = i;
                                        userpic_preview();
                                        return;
                                    }
                                }
                            });
                        }
                    });
                    ups.show();
                });
            }
            if (ups_btn_img) {
                DOM.addEventListener(ups_btn_img, "click", function (evt) {
                    var ups = new UserpicSelect();
                    ups.init();
                    ups.setPicSelectedCallback(function (picid, keywords) {
                        var kws_dropdown = $("prop_picture_keyword");

                        if (kws_dropdown) {
                            var items = kws_dropdown.options;

                            // select the keyword in the dropdown
                            keywords.forEach(function (kw) {
                                for (var i = 0; i < items.length; i++) {
                                    var item = items[i];
                                    if (item.value == kw) {
                                        kws_dropdown.selectedIndex = i;
                                        userpic_preview();
                                        return;
                                    }
                                }
                            });
                        }
                    });
                    ups.show();
                });
                DOM.addEventListener(ups_btn_img, "mouseover", function (evt) {
                    var msg = $("lj_userpicselect_img_txt");
                    msg.style.display = 'block';
                });
                DOM.addEventListener(ups_btn_img, "mouseout", function (evt) {
                    var msg = $("lj_userpicselect_img_txt");
                    msg.style.display = 'none';
                });
            }
        });
    });
}

sub render_userpics_js {
    my ($self) = @_;

    my $ret = '';

    my $userpics;
    my $login_data = $self->login_data;

    my $num = 0;
    $userpics .= "    userpics[$num] = \"$login_data->{'defaultpicurl'}\";\n";
    foreach (@{$login_data->{'pickwurls'}}) {
        $num++;
        $userpics .= "    userpics[$num] = \"$_\";\n";
    }

    my $code = qq{
        var userpics = new Array();
        $userpics
    } . q{
        function userpic_preview() {
            if (! document.getElementById) return false;
            var userpic_select = $('prop_picture_keyword');

            if ($('userpic') && $('userpic').style.display == 'none') {
                $('userpic').style.display = 'block';
            }
            var userpic_msg;
            if (userpics[0] == "") { userpic_msg = 'Choose default userpic' }
            if (userpics.length == 0) { userpic_msg = 'Upload a userpic' }

            if (userpic_select && userpics[userpic_select.selectedIndex] != "") {
                $('userpic_preview').className = '';
                var userpic_preview_image = $('userpic_preview_image');
                userpic_preview_image.style.display = 'block';
                if ($('userpic_msg')) {
                    $('userpic_msg').style.display = 'none';
                }
                userpic_preview_image.src = userpics[userpic_select.selectedIndex];
            } else {
                userpic_preview.className += " userpic_preview_border";
                userpic_preview.innerHTML = '<a href="'+Site.siteroot+'/editpics.bml"><img src="" alt="selected userpic" id="userpic_preview_image" style="display: none;" /><span id="userpic_msg">' + userpic_msg + '</span></a>';
            }
        }
    };

    $ret .= $self->wrap_js(qq{
        if (document.getElementById) {
            $code
        }
    });

    $ret .= $self->render_userpicselect_js
        if $self->should_show_userpicselect;

    return $ret;
}

sub render_userpics_block {
    my ($self) = @_;

    my $onload = $self->onload;
    my $head = $self->head;

    my $out = '';

    if ($self->should_show_userpics) {
        $$onload .= " userpic_preview();";

        my $userpic_link_text;
        $userpic_link_text = BML::ml('entryform.userpic.choose')
            if $self->remote;

        $$head .= $self->render_userpics_js;

        $out .= qq{
            <div id='userpic' style='display: none;'>
                <p id='userpic_preview'>
                    <a href='javascript:void(0);' id='lj_userpicselect_img'>
                        <img src='' alt='selected userpic' id='userpic_preview_image' />
                        <span id='lj_userpicselect_img_txt'>$userpic_link_text</span>
                    </a>
                </p>
            </div>
        };
    } elsif (!$self->remote || $self->altlogin)  {
        $out .= q{
            <div id='userpic'>
                <p id='userpic_preview'>
                    <img src='/img/userpic_loggedout.gif'
                        alt='selected userpic' id='userpic_preview_image'
                        class='userpic_loggedout'  />
                </p>
            </div>
        };
    } else {
        $out .= qq{
            <div id='userpic'>
                <p id='userpic_preview' class='userpic_preview_border'>
                    <a href='$LJ::SITEROOT/editpics.bml'>Upload a userpic</a>
                </p>
            </div>
        };
    }

    return $out;
}

sub render_infobox_block {
    my ($self) = @_;

    my $out = '';

    my $opts = $self->opts;

    $out .= "<div id='infobox'>\n";
    $out .= LJ::run_hook('entryforminfo', $opts->{'usejournal'}, $opts->{'remote'});
    $out .= "</div><!-- end #infobox -->\n\n";

    return $out;
}

sub render_metainfo_block {
    my ($self) = @_;

    my $out = '';

    my $opts = $self->opts;
    my $login_data = $self->login_data;
    my $remote = $self->remote;
    my $errors = $self->errors;
    my $onload = $self->onload;

    $out .= LJ::html_hidden({
        name => 'timezone',
        value => 'guess',
        id => 'journal_timezone',
    });
    $out .= LJ::html_hidden({
        name => 'custom_time',
        value => '0',
        id => 'journal_time_edited',
    });
    $out .= "<script>try { \$('journal_timezone').value = - (new Date).getTimezoneOffset()/0.6; } catch(e) {} </script>";
    $out .= "<div id='metainfo-wrap'><ul id='metainfo'>";


    # login info
    $out .= $opts->{'auth'};
    if ($opts->{'mode'} eq "update") {
        # communities the user can post in
        my $usejournal = $opts->{'usejournal'};
        if ($usejournal) {
            $out .= "<li id='usejournal_single' class='pkg'>\n";
            $out .= "<label for='usejournal' class='left'>" .
                BML::ml('entryform.postto') . "</label>\n";

            $out .= LJ::ljuser($usejournal);
            $out .= LJ::html_hidden({
                name => 'usejournal',
                value => $usejournal,
                id => 'usejournal_username',
            });

            $out .= LJ::html_hidden( usejournal_set => 'true' );
            $out .= "</li>";
        } elsif ($login_data && ref $login_data->{'usejournals'} eq 'ARRAY') {
            my $submitprefix = BML::ml('entryform.update3');
            $out .= "<li id='usejournal_list' class='pkg'>\n";
            $out .= "<label for='usejournal' class='title'>" .
                BML::ml('entryform.postto') . "</label>\n";

            my @choices;

            if ( $remote->is_personal ) {
                push @choices, $remote->username => $remote->username;
            } else {
                push @choices,
                    '[none]' => LJ::Lang::ml('entryform.postto.select');
            }

            push @choices, map { $_ => $_ } @{ $login_data->{'usejournals'} };

            $out .= "<span class='wrap'>";
            $out .= LJ::html_select(
                {
                    'name' => 'usejournal',
                    'id' => 'usejournal',
                    'selected' => $usejournal,
                    'tabindex' => $self->tabindex,
                    'class' => 'select',
                    "onchange" => "changeSubmit('" . $submitprefix . "',this[this.selectedIndex].value, '$BML::ML{'entryform.update4'}');".
                        "getUserTags(this[this.selectedIndex].value);".
                        "setPostingPermissions(this[this.selectedIndex].value);".
                        "changeSecurityOptions(this[this.selectedIndex].value)"
                },
                @choices,
            );
            $out .= "</span></li>\n";
        }
    }

    # Authentication box
    $out .= "<li class='update-errors'><?inerr $errors->{'auth'} inerr?></li>\n"
        if $errors->{'auth'};

    # Date / Time
    my ($year, $mon, $mday, $hour, $min) = split(/\D/, $opts->{'datetime'});
    my $monthlong = LJ::Lang::month_long($mon);
    
    # date entry boxes / formatting note
    my $datetime = LJ::html_datetime({
        'name' => "date_ymd",
        'notime' => 1,
        'default' => "$year-$mon-$mday",
        'disabled' => $opts->{'disabled_save'}
    });

    $datetime .= "<span class='float-left'>&nbsp;&nbsp;</span>";
    $datetime .= LJ::html_text({
        size => 2,
        class => 'text',
        maxlength => 2,
        value => $hour,
        name => "hour",
        tabindex => $self->tabindex,
        disabled => $opts->{'disabled_save'}
    }) . "<span class='float-left'>:</span>";

    $datetime .= LJ::html_text({
        size => 2,
        class => 'text',
        maxlength => 2,
        value => $min,
        name => "min",
        tabindex => $self->tabindex,
        disabled => $opts->{'disabled_save'}
    });

    # JavaScript sets this value, so we know that the time we get is correct
    # but always trust the time if we've been through the form already
    my $date_diff = ($opts->{'mode'} eq "edit" || $opts->{'spellcheck_html'}) ?
        1 : 0;

    my $date_diff_input = LJ::html_hidden("date_diff", $date_diff);

    # but if we don't have JS, give a signal to trust the given time
    $date_diff_input .= "<noscript>" .  LJ::html_hidden("date_diff_nojs", "1") .
        "</noscript>";

    my $help_icon = LJ::help_icon("24hourshelp");

    if ( $opts->{'mode'} eq "edit" ) {
        $out .= qq{ <li class='pkg' id='currentdate'><label class='title'>$BML::ML{'entryform.date'}</label>
                <span class='wrap'>
                    $monthlong, $mday, $year, $hour:$min
                    <a href='javascript:void(0)' onclick='editdate();' id='currentdate-edit'>$BML::ML{'entryform.date.edit'}</a>
                    $help_icon
                  </span>
                </li> };
    } else {
        $out .= qq{ <li class='pkg' id='currentdate'><label class='title'>$BML::ML{'entryform.post'}</label>
                <span class='wrap'>
                    $BML::ML{'entryform.post.right.now'}
                    <a href='javascript:void(0)' onclick='editdate();' id='currentdate-edit'>$BML::ML{'entryform.date.edit'}</a>
                    $help_icon
                </span>
            </li>};
    }

    $out .= qq{ <li class='pkg' id='modifydate' style='display: none;'><label class='title'>$BML::ML{'entryform.postponed.until'}</label>
                <span class='wrap'>
                    <input type="hidden" name="date_ymd_mm" value="$mon" />
                    <input type="hidden" name="date_ymd_dd" value="$mday" />
                    <input type="hidden" name="date_ymd_yyyy" value="$year" />
                    $date_diff_input
                    <span class="wrap-calendar"><a id="currentdate-date" href="#">$monthlong $mday, $year</a><i class='i-calendar'></i></span>
                    <span class='datetime'>
                        <input type='text' name='hour' value='$hour' class='input-num' /> : <input type='text' value='$min' name='min' class='input-num' />
                        <?de $BML::ML{'entryform.date.24hournote'} de?>
                    </span>
                </span>
            </li>
        <li>
        <noscript>
            <p id='time-correct' class='small'>
                $BML::ML{'entryform.nojstime.note'}
            </p>
        </noscript>
        </li>
    };

    $$onload .= " defaultDate();";

    # User Picture
    if ($self->should_show_userpics) {
        my $pickw_select = LJ::html_select(
            {
                'name' => 'prop_picture_keyword',
                'id' => 'prop_picture_keyword',
                'class' => 'select',
                'selected' => $opts->{'prop_picture_keyword'},
                'onchange' => "userpic_preview()",
                'tabindex' => $self->tabindex
            },
            (
                "" => BML::ml('entryform.opt.defpic'),
                map { ($_, $_) } @{$login_data->{'pickws'}}
            )
        );

        my $userpics_help = LJ::help_icon_html("userpics", "", " ");
        my $userpic_display = $self->altlogin ? 'none' : '';
        my $style = "display: $userpic_display;";

        $out .= qq{
            <li id='userpic_select_wrapper' class='pkg' style='$style'>
                <label for='prop_picture_keyword' class='title'>
                    $BML::ML{'entryform.userpic'}
                </label>
                <span class='wrap'>
                    $pickw_select
                    <a href='javascript:void(0);' id='lj_userpicselect'> </a>
                    $userpics_help
                </span>
            </li>
        };

        $$onload .= " insertViewThumbs();" if $self->should_show_userpicselect;
    }

    $out .= "</ul></div>";
}

sub render_top_block {
    my ($self) = @_;

    my $out = '';

    $out .= LJ::Widget::Calendar->render();
    $out .= $self->render_userpics_block;
    $out .= $self->render_infobox_block;
    $out .= $self->render_metainfo_block;

    return $out;
}

sub render_subject_block {
    my ($self) = @_;

    my $out = '';

    my $opts = $self->opts;
    my $onload = $self->onload;

    my $block_qotd = '';
    if ($opts->{prop_qotdid}) {
        my $qotd = LJ::QotD->get_single_question($opts->{prop_qotdid});
        my $qotd_show = LJ::Widget::QotD->qotd_display_embed(
            questions => [ $qotd ],
            no_answer_link => 1
        );

        $block_qotd .= qq{
            <div style='margin-bottom: 10px;' id='qotd_html_preview'>
                $qotd_show
            </div>
        };
    }

    my $subject_field = LJ::html_text({
        'name' => 'subject',
        'value' => $opts->{'subject'},
        'class' => 'text',
        'id' => 'subject',
        'size' => '43',
        'maxlength' => '100',
        'tabindex' => $self->tabindex,
        'disabled' => $opts->{'disabled_save'}
    });

    my $switch_rte_link = BML::ml("entryform.htmlokay.rich4", {
        'opts' => 'href="javascript:void(0);" '.
            'onclick="return useRichText(\'' .
            $LJ::JSPREFIX. '\');"'
    });

    my $switch_rte_tab = '';
    unless ($self->rte_not_supported) {
        $switch_rte_tab = "<li id='jrich'>" . $switch_rte_link  . "</li>";
    }

    my $switch_plaintext_link = BML::ml("entryform.plainswitch2", {
        'aopts' => 'href="javascript:void(0);" '.
            'onclick="return usePlainText();"'
    });

    my $switch_plaintext_tab =
        "<li id='jplain'>" . $switch_plaintext_link . "</li>";

    $out .= qq{
        $block_qotd
        <div id='entry' class='pkg'>
            <label class='left' for='subject'>
                $BML::ML{'entryform.subject'}
            </label>
            $subject_field
            <ul id='entry-tabs' style='visibility:hidden'>
                $switch_rte_tab
                $switch_plaintext_tab
            </ul>
        </div>
    };

    $$onload .= " showEntryTabs();";

    return $out;
}

sub render_htmltools_block {
    my ($self) = @_;

    my $out = '';

    my $opts = $self->opts;

    my $insert_image = qq{
        <li class='image'>
            <a
                href='javascript:void(0);'
                onclick='InOb.handleInsertImage();'
                title='$BML::ML{'fckland.ljimage'}'
            >
                $BML::ML{'entryform.insert.image2'}
            </a>
        </li>
    };

    my $insert_media = '';
    unless ($LJ::DISABLED{embed_module}) {
        $insert_media = qq{
            <li class='media'>
                <a
                    href='javascript:void(0);'
                    onclick='InOb.handleInsertEmbed();'
                    title='$BML::ML{'entryform.insert.embed'}'
                >
                    $BML::ML{'entryform.insert.embed'}
                </a>
            </li>
        };
    }

    my $autoformat_check = LJ::html_check({
        'type' => "check",
        'class' => 'check',
        'value' => 'preformatted',
        'name' => 'event_format',
        'id' => 'event_format',
        'selected' => 
            $opts->{'prop_opt_preformatted'} || $opts->{'event_format'},
        'label' => BML::ml('entryform.format3'),
    });

    my $autoformat_help = LJ::help_icon_html("noautoformat", "", " ");

    $out .= qq{
        <div id='htmltools' class='pkg'>
            <ul class='pkg'>
                $insert_image
                $insert_media
            </ul>
            <span id='linebreaks'>$autoformat_check $autoformat_help</span>
        </div>
    };

    return $out;
}

sub render_options_block {
    my ($self) = @_;

    my $opts = $self->opts;
    my $remote = $self->remote;
    my $head = $self->head;
    my $onload = $self->onload;

    my $out = '';

    $out .= "<ul id='options' class='pkg'>";

    my %blocks = (
        'sticky' => sub {
            my $journalu = LJ::load_user($opts->{'usejournal'}) || $remote;
            my $is_checked = sub {
                if ($opts->{sticky}) {
                    return 'checked'
                }

                if ($opts->{jitemid}) {
                    my $sticky_entry = $journalu->get_sticky_entry();
                    if ( $sticky_entry eq $opts->{jitemid} ) {
                        return 'checked' 
                    }
                }
                
            };

            my $selected = $is_checked->();
            my $sticky_check = LJ::html_check({
                'type' => "check",
                'class' => 'sticky_type',
                'value' => 'sticky',
                'name' => 'sticky_type',
                'id' => 'sticky_type',
                'selected' => $selected,
                $opts->{'prop_opt_preformatted'} || $opts->{'event_format'},
                'label' => "",
            });

            my $sticky_exists = $journalu ? $journalu->has_sticky_entry && !$selected : undef;
            my $sticky_text = $sticky_exists ? $BML::ML{'entryform.sticky_replace.edit'} :
                                               $BML::ML{'entryform.sticky.edit'};
            return qq{$sticky_check <label for='sticky_type' id='sticky_type_label' class='right options'>
                   $sticky_text
                </label>};
        },
         'do_not_add' => sub {
            my $selected = $opts->{'opt_backdated'} || 0;
            my $dot_add_check = LJ::html_check({
                'type' => "check",
                'class' => 'do_not_add_type',
                'value' => '1',
                'name' => 'prop_opt_backdated',
                'id' => 'do_not_add_type',
                'selected' => $selected,
                $opts->{'prop_opt_preformatted'} || $opts->{'event_format'},
                'label' => "",
            });

            my $added_to_rss_text = $BML::ML{'entryform.do_not_add_rss_friends'};
            return qq{$dot_add_check <label for='do_not_add_type' class='right options'>
                   $added_to_rss_text
                </label>};
        },
        'tags' => sub {
            return if $LJ::DISABLED{'tags'};

            my $field = LJ::html_text({
                'name'      => 'prop_taglist',
                'id'        => 'prop_taglist',
                'class'     => 'text',
                'size'      => '35',
                'value'     => $opts->{'prop_taglist'},
                'tabindex'  => $self->tabindex,
                'raw'       => "autocomplete='off'",
            });

            my $help = LJ::help_icon_html('addtags');

            my $selectTags = '';
            if ($remote) {
                $selectTags = qq|<a href="#" onclick="return selectTags(this)" class="i-prop-selecttags">$BML::ML{'entryform.selecttags'}</a>|;
                # we do not use bind, because it was wrongly implemented long ago and this is a quick fix
                $$onload .= " jQuery(function() { getUserTags(jQuery(document.updateForm.usejournal).val()) });";
            }

            return qq{
                <label for='prop_taglist' class='title options'>
                    $BML::ML{'entryform.tags'}
                </label>
                $field
                $selectTags
                $help
            };
        },
        'mood' => sub {
            my @moodlist = ('', BML::ml('entryform.mood.noneother'));
            my $sel;

            my $moods = LJ::get_moods();
            my @moodids = sort {
                $moods->{$a}->{'name'} cmp $moods->{$b}->{'name'}
            } keys %$moods;

            foreach (@moodids) {
                push @moodlist, ($_, $moods->{$_}->{'name'});

                if ($opts->{'prop_current_mood'} eq $moods->{$_}->{'name'} ||
                    $opts->{'prop_current_moodid'} == $_) {
                    $sel = $_;
                }
            }

            if ($remote) {
                LJ::load_mood_theme($remote->{'moodthemeid'});
                my (%moodlist, %moodpics);

                foreach my $mood (@moodids) {
                    my $moodhash = $moods->{$mood};
                    $moodlist{$moodhash->{'id'}} = $moodhash->{'name'};
                    if (LJ::get_mood_picture(
                        $remote->{'moodthemeid'}, $moodhash->{id}, \ my %pic
                    )) {
                        $moodpics{$moodhash->{'id'}} = $pic{'pic'};
                    }
                }

                my $moodlist = LJ::JSON->to_json(\%moodlist);
                my $moodpics = LJ::JSON->to_json(\%moodpics);
                $$onload .= " mood_preview();";
                $$head .= $self->wrap_js(qq{
                    if (document.getElementById) {
                        var moodpics = $moodpics;
                        var moods    = $moodlist;
                    }
                });
            }

            my $dropdown = LJ::html_select({
                'name' => 'prop_current_moodid',
                'id' => 'prop_current_moodid',
                'selected' => $sel,
                'onchange' => $remote ? 'mood_preview()' : '',
                'class' => 'select',
                'tabindex' => $self->tabindex,
            }, @moodlist);
            
            my $textfield = LJ::html_text({
                'name' => 'prop_current_mood',
                'id' => 'prop_current_mood',
                'class' => 'text',
                'value' => $opts->{'prop_current_mood'},
                'onchange' => $remote ? 'mood_preview()' : '',
                'size' => '15',
                'maxlength' => '30',
                'tabindex' => $self->tabindex
            });

            return qq{
                <label for='prop_current_moodid' class='title options'>
                    $BML::ML{'entryform.mood'}
                </label>
                $dropdown
                $textfield
                <span id='mood_preview'></span>
            };
        },
        'comment_settings' => sub {
            my $out = '';

            $out .= "<label for='comment_settings' class='title options'>" .
                BML::ml('entryform.comment.settings2') . "</label>\n";

            my $comment_settings_selected = sub {
                return "noemail" if $opts->{'prop_opt_noemail'};
                return "nocomments" if $opts->{'prop_opt_nocomments'};
                return "lockcomments" if $opts->{'prop_opt_lockcomments'};
                return $opts->{'comment_settings'};
            };

            my %options = (
                "" => BML::ml('entryform.comment.settings.default5'),
                "nocomments" => BML::ml('entryform.comment.settings.nocomments'),
                "noemail" => BML::ml('entryform.comment.settings.noemail'),
            );

            $options{"lockcomments"} = BML::ml('entryform.comment.settings.lockcomments')
                if $opts->{'mode'} eq 'edit';
            
            my @options =
                map { $_ => $options{$_} }
                grep { exists $options{$_} } 
                ( '', 'nocomments', 'lockcomments', 'noemail' );

            $out .= LJ::html_select(
                {
                    'name' => "comment_settings",
                    'id' => 'comment_settings',
                    'class' => 'select',
                    'selected' => $comment_settings_selected->(),
                    'tabindex' => $self->tabindex
                },
                @options
            );

            $out .= LJ::help_icon_html("comment", "", " ");

            return $out;
        },
        'location' => sub {
            my $out = '';

            return if $LJ::DISABLED{'web_current_location'};

            my $textbox = LJ::html_text({
                'name' => 'prop_current_location',
                'value' => $opts->{'prop_current_location'},
                'id' => 'prop_current_location',
                'class' => 'text',
                'size' => '35',
                'maxlength' => '60',
                'tabindex' => $self->tabindex,
                $self->lastfm_geolocation_width,
            });

            $out .= qq{
                <label for='prop_current_location' class='title options'>
                    $BML::ML{'entryform.location'}
                </label>
                $textbox
            };

            if ($self->should_show_geolocation) {
                my $help_icon = LJ::help_icon_html("location", "", " ");
                
                $out .= qq{
                    <span class="detect_btn">
                        <input
                            type="button"
                            value="$BML::ML{'entryform.location.detect'}"
                            onclick="detectLocation()"
                        >
                        $help_icon
                    </span>
                };
            }

            return $out;
        },
        'comment_screening' => sub {
            my $out = '';

            $out .= "<label for='prop_opt_screening' class='title options'>" .
                BML::ml('entryform.comment.screening2') . "</label>\n";

            my @levels = (
                ''  => BML::ml('label.screening.default4'),
                'N' => BML::ml('label.screening.none2'),
                'R' => BML::ml('label.screening.anonymous2'),
                'F' => BML::ml('label.screening.nonfriends2'),
                'A' => BML::ml('label.screening.all2'),
            );

            $out .= LJ::html_select({
                'name' => 'prop_opt_screening', 
                'id' => 'prop_opt_screening',
                'class' => 'select',
                'selected' => $opts->{'prop_opt_screening'},
                'tabindex' => $self->tabindex,
            }, @levels);

            $out .= LJ::help_icon_html("screening", "", " ");

            $out .= "</span>\n";

            return $out;
        },
        'music' => sub {
            my $out = '';

            $out .= "<label for='prop_current_music' class='title options'>" .
                BML::ml('entryform.music') . "</label>\n";

            $out .= LJ::html_text({
                'name' => 'prop_current_music',
                'value' => $opts->{'prop_current_music'},
                'id' => 'prop_current_music',
                'class' => 'text',
                'size' => '35',
                'maxlength' => LJ::std_max_length(),
                'tabindex' => $self->tabindex,
                $self->lastfm_geolocation_width,
            });

            if ($self->should_show_lastfm) {
                my $last_fm_user = LJ::ejs($opts->{'prop_last_fm_user'});
                my $button_label = BML::ml('entryform.music.detect');
                my $help_icon = LJ::help_icon_html("lastfm", "", " ");

                $out .= qq{
                    <input
                        type="button" value="$button_label"
                        style="float: left"
                        onclick="lastfm_current('$last_fm_user', true);"
                    >
                    $help_icon
                };

                # automatically detect current music only if creating new entry
                if ($opts->{'mode'} eq 'update') {
                    $out .= $self->wrap_js(qq{
                        lastfm_current('$last_fm_user', false);
                    });
                }
            }
            $out .= "</span>\n";

            return $out;
        },
        'content_flag' => sub {
            my $out = '';

            return unless LJ::is_enabled("content_flag");

            my @adult_content_menu = (
                ""       => BML::ml('entryform.adultcontent.default'),
                none     => BML::ml('entryform.adultcontent.none'),
                concepts => BML::ml('entryform.adultcontent.concepts'),
                explicit => BML::ml('entryform.adultcontent.explicit'),
            );

            $out .= "<label for='prop_adult_content' class='title options'>" .
                BML::ml('entryform.adultcontent') . "</label>\n";

            $out .= LJ::html_select({
                name => 'prop_adult_content',
                id => 'prop_adult_content',
                class => 'select',
                selected => $opts->{prop_adult_content} || "",
                tabindex => $self->tabindex,
            }, @adult_content_menu);

            $out .= LJ::help_icon_html("adult_content", "", " ");
            return $out;
        },
        'give_features' => sub {
            my $out = '';

            return unless LJ::is_enabled("give_features");
            
            my @give_menu = (
                "enable"  => BML::ml('entryform.give.enable'),
                "disable" => BML::ml('entryform.give.disable'),
            );

            $out .= "<label for='prop_give_features' class='title options'>" .
                BML::ml('entryform.give') . "</label>\n";

            my $is_enabled;
            if ($opts->{'mode'} eq "edit") {
                $is_enabled = $opts->{'prop_give_features'};
            } else {
                my $journalu = LJ::load_user($opts->{'usejournal'}) || $remote;
                $is_enabled = $journalu ? 1 : 0; 
            }

            $out .= LJ::html_select({
                name => 'prop_give_features',
                id => 'prop_give_features',
                class => 'select',
                selected => ($is_enabled) ? "enable" : "disable",
                tabindex => $self->tabindex,
            }, @give_menu);

            $out .= LJ::help_icon_html("give", "", " ");
            return $out;
        },
        'blank' => sub {
          return '';  
        },
        'lastfm_logo' => sub {
            return unless $self->should_show_lastfm;
            return qq{
                <span class='lastfm'>
                    <span>
                        POWERED<br />
                        BY
                    </span>
                </span>
                <a href='$LJ::LAST_FM_SITE_URL' target='_blank'
                    class='lastfm_lnk'>Last.fm</a>
            };
        },
        'spellcheck' => sub {
            my $out = '';

            # extra submit button so make sure it posts the form when
            # person presses enter key
            my %action_map = (
                'edit' => 'save',
                'update' => 'update',
            );
            if (my $action = $action_map{$opts->{'mode'}}) {
                $out .= qq{
                    <input type='submit' name='action:$action'
                        class='hidden_submit' />
                    <span id="preview_button_holder"></span>
                };
            }
            my $preview_tabindex = $self->tabindex;
            my $preview = qq{
                <input
                    type='button'
                    value='$BML::ML{'entryform.preview'}'
                    onclick='entryPreview(this.form)'
                    tabindex='$preview_tabindex'
                />
            };
            $preview =~ s/\s+/ /sg; # JS doesn't like newlines in string
                                    # literals

            unless ($opts->{'disabled_save'}) {
                $out .= $self->wrap_js(qq{
                    if (document.getElementById) {
                        \$('preview_button_holder').innerHTML = "$preview ";
                    }
                });
            }
            if ($LJ::SPELLER && !$opts->{'disabled_save'}) {
                $out .= LJ::html_submit(
                    'action:spellcheck',
                    BML::ml('entryform.spellcheck'),
                    { 'tabindex' => $self->tabindex }
                ) . "&nbsp;";
            }
            
            return qq{<label for='sticky_type' class='title options'>
                $BML::ML{'entryform.spellcheck'}
                </label> $out};
        },
        'none' => sub {return qq{};},
    );

    my @schema = (
        [ 'tags' ],
        [ 'mood', 'comment_settings' ],
        [ 'location', 'comment_screening' ],
        [ 'music', 'content_flag' ],
        [ 'spellcheck', 'do_not_add' ],
        [ 'none','sticky'],
        'extra',
        [ 'lastfm_logo'  ],
    );

    unless ($opts->{'disabled_save'}) {
        foreach my $row (@schema) {
            if (ref $row eq 'ARRAY') {
                $out .= "<li class='pkg'>";
                
                my ($l, $r) = @$row;
                
                next unless $blocks{$l};

                if (scalar(@$row) == 1) {
                    my $block = $blocks{$l}->();

                    $out .= qq{
                        <span id="entryform-${l}-wrapper">$block</span>
                    };
                } else {
                    next unless $blocks{$r};

                    my $block_left = $blocks{$l}->();
                    my $block_right = $blocks{$r}->();

                    $out .= qq{
                        <span id="entryform-$l-wrapper"
                            class='inputgroup-left'>$block_left</span>
                        <span id="entryform-$r-wrapper"
                            class='inputgroup-right'>$block_right</span>
                    };
                }
                $out .= '</li>';
            } elsif ($row eq 'extra') {
                $out .= LJ::run_hook('add_extra_entryform_fields', {
                    opts => $opts,
                    tabindex => sub { return $self->tabindex; }
                });
            }
        }
    }

    $out .= "</ul>";

    return $out;
}

sub render_security_container_block {
    my ($self) = @_;

    my $opts = $self->opts;
    my $onload = $self->onload;
    my $remote = $self->remote;
    my $login_data = $self->login_data;

    my $out = '';

    my $usejournalu = LJ::load_user($opts->{usejournal});
    my $is_comm = $usejournalu && $usejournalu->is_comm ? 1 : 0;

    my %strings_map = (
        'public' => 'public2',
        'friends' => 'friends',
        'friends_comm' => 'members',
        'private' => 'private2',
        'custom' => 'custom',
    );

    my %strings_map_converted = map {
        $_ => LJ::ejs(BML::ml("label.security.$strings_map{$_}"))
    } keys %strings_map;

    my $strings_map_converted = LJ::JSON->to_json(\%strings_map_converted);
    $out .= $self->wrap_js("var UpdateFormStrings = $strings_map_converted;");

    $$onload .= " setColumns();" if $remote;

    my @secs = (
        "public" , $strings_map_converted{'public'},
        "friends", $strings_map_converted{$is_comm ? 'friends_comm' : 'friends'},
    );

    push @secs, (
        "private", $strings_map_converted{'private'},
    ) unless $is_comm;

    my @secopts;
    if ($self->should_show_friendgroups) {
        push @secs, (
            "custom" => $strings_map_converted{'custom'},
        );

        push @secopts, ("onchange" => "customboxes()");
    }
    else {
        push @secopts, ("onchange" => "updateRepostButtons(this.selectedIndex)");
    }


    $out .= LJ::html_select({
        'id' => "security",
        'name' => 'security',
        'include_ids' => 1,
        'class' => 'select',
        'selected' => $opts->{'security'},
        'tabindex' => $self->tabindex,
        @secopts
    }, @secs) . "\n";

    return $out;
}

sub render_submitbar_block {
    my ($self) = @_;

    my $opts = $self->opts;
    my $remote = $self->remote;
    my $onload = $self->onload;

    my $out = '';

    $out .= "<div id='submitbar' class='pkg'>\n\n";
    $out .= "<div id='security_container'>\n";
    $out .= "<div class='security-options'>\n";
    $out .= "<label for='security'>" . BML::ml('entryform.security2') . " </label>\n";
    
    # preview button 
    
    # extra submit button so make sure it posts the form when
    # person presses enter key
    my %action_map = (  'edit' => 'save',
                        'update' => 'update', );
    
    if (my $action = $action_map{$opts->{'mode'}}) {
        $out .= qq{
            <input type='submit' name='action:$action'
            class='hidden_submit' />
        };
    }
    
    my $preview_tabindex = $self->tabindex;
    my $preview = qq{
        <input
        type="button"
        value="$BML::ML{'entryform.preview'}"
        onclick="entryPreview(this.form)"
        tabindex="$preview_tabindex"
        />
    };

    
    $preview =~ s/\s+/ /sg; # JS doesn't like newlines in string
    # literals
        
    unless ($opts->{'disabled_save'}) {
        $out .= $self->wrap_js(qq{
            if (document.getElementById) {
                setTimeout( function() {
                    jQuery( '$preview' ).prependTo('#entryform-update-and-edit' );
                }, 0 );
            }
        });
    }

   
    $out .= $self->render_security_container_block;
    if ($opts->{'mode'} eq "update") {
        my $onclick = "";
        $onclick .= "return sendForm('updateForm');" if ! $LJ::IS_SSL;
        
        my $help_icon = LJ::help_icon("security",
            "<span id='security-help'>\n", "\n</span>\n");
        $out .= $help_icon;
        
        my $defaultjournal;
        if ($opts->{'usejournal'}) {
            $defaultjournal = $opts->{'usejournal'};
        } elsif ($remote && $opts->{auth_as_remote}) {
            $defaultjournal = $remote->user;
        }
        
        $out .= qq{ </div> };
        $out .= qq{ <div class="submit-options"> };
        $out .= qq{ <span id="entryform-update-and-edit"> };
        if ($defaultjournal) {
            $$onload .= " changeSubmit('$BML::ML{'entryform.update3'}', '$defaultjournal', '$BML::ML{'entryform.update4'}');";
            $$onload .= " changeSecurityOptions('$defaultjournal');";
        }
        $out .= qq{</span>};
        
        my $disabled = $remote && $remote->is_identity && !$self->usejournal;

        $out .= LJ::html_submit(
            'action:update',
            BML::ml('entryform.update4'),
            {
                'onclick' => $onclick,
                'class' => 'submit',
                'id' => 'formsubmit',
                'tabindex' => $self->tabindex,
                'disabled' => $disabled,
            }
        ) . "&nbsp;\n";
        
        $out .= qq{</div>};
        
    }
    
    $out .= qq{</div>};
    
    if ($opts->{'mode'} eq "edit") {
        my $onclick = $LJ::IS_SSL ? '' : 'return true;';
        $out .= qq{ <div id="entryform-update-and-edit" class="submit-options"> };
        $out .= LJ::html_submit(
            'action:save',
            BML::ml('entryform.save'),
            {
                'onclick' => $onclick,
                'disabled' => $opts->{'disabled_save'},
                'tabindex' => $self->tabindex,
            }
        ) . "&nbsp;\n";

        if ($opts->{suspended} && !$opts->{unsuspend_supportid}) {
            $out .= LJ::html_submit(
                'action:saveunsuspend',
                BML::ml('entryform.saveandrequestunsuspend2'),
                {
                    'onclick' => $onclick,
                    'disabled' => $opts->{'disabled_save'},
                    'tabindex' => $self->tabindex,
                }
            ) . "&nbsp;\n";
        }

        $out .= LJ::html_submit(
            'action:delete',
            BML::ml('entryform.delete'),
            {
                'disabled' => $opts->{'disabled_delete'},
                'tabindex' => $self->tabindex,
                'onclick' => "return confirm('" .
                    LJ::ejs(BML::ml('entryform.delete.confirm')) . "')",
            }
        ) . "&nbsp;\n";

        if (!$opts->{'disabled_spamdelete'}) {
            $out .= LJ::html_submit(
                'action:deletespam',
                BML::ml('entryform.deletespam'),
                {
                    'onclick' => "return confirm('" .
                        LJ::ejs(BML::ml('entryform.deletespam.confirm')) . "')",
                    'tabindex' => $self->tabindex,
                }
            ) . "\n";
        }
        $out .= qq{</div>};
    }

    $out .= "</div><!-- end #security_container -->\n\n";
    
    my $login_data = $self->login_data;
    # if custom security groups available, show them in a hideable div
    if ($self->should_show_friendgroups) {
        my $display = $opts->{'security'} eq "custom" ? "block" : "none";

        $out .= "<div id='custom_boxes' class='pkg' style='display: $display;'>";
        $out .= "<ul id='custom_boxes_list'>";
        foreach my $fg (@{$login_data->{'friendgroups'}}) {
            $out .= "<li>";
            $out .= LJ::html_check({
                'name' => "custom_bit_$fg->{'id'}",
                'id' => "custom_bit_$fg->{'id'}",
                'selected' => $opts->{"custom_bit_$fg->{'id'}"} ||
                    ($opts->{'security_mask'}+0) & (1 << $fg->{'id'}),
            }) . " ";

            $out .= "<label for='custom_bit_$fg->{'id'}'>" .
                LJ::ehtml($fg->{'name'}) . "</label>\n";

            $out .= "</li>";
        }
        $out .= "</ul>";
        $out .= "</div><!-- end #custom_boxes -->\n";
    }
    
    $out .= "</div><!-- end #submitbar -->\n\n";

    return $out;
}

sub render_ljphoto_block {
    my ($self) = @_;

    my $opts = $self->opts;
    my $out = '';

    my $remote = $self->remote ();

    # in case of insert one photo or photo album
    my $insert_photos = [];

    my $albums_id = $opts->{'albums_id'};
    my $photos_id = $opts->{'photos_id'};

    my @photos = grep { $_ } map {
        my $photo = LJ::Fotki::Photo->new ( url_id => $_, userid => $remote->userid );
        $photo;
    } split (/,/, $photos_id);

    foreach my $album_id (split /,/, $albums_id) {
        my $album = LJ::Fotki::Album->new ( url_id => $album_id, userid => $remote->userid );
        next unless $album;
        push @photos, @{$album->get_all_photos() || []};
    }

    $insert_photos = [ grep { $_ } map {
            my $photo = $_;

            my $res = $photo->is_valid ? {
                photo_desc  => $photo->desc,
                photo_title => $photo->title,
                photo_url   => @photos > 1 ? $photo->u100_url : $photo->u600_url,
                photo_id    => $photo->url_id,
            } : undef;
            $res;
        } @photos ];

    my @photo_sizes = map {
        my $size = $_;
        $size->{'text'} = $BML::ML{$_->{'text'}};
        $size;
    } @{LJ::Fotki::Photo->get_photo_sizes()};

    my $photo_sizes_json = LJ::JSON->to_json ( \@photo_sizes );
    my $album_list = [];
    my $album_list_json = '';
    my $available_space = '';
    $album_list = LJ::Fotki::Album->get_albums ($remote->userid);
    $album_list = [
        map {
            my $album = $_;
            my $main_photo = $album->main_photo_url;
            {
                album_title     => $album->title,
                album_id        => $album->url_id,
            }
        } @$album_list
    ];
    $album_list_json = LJ::JSON->to_json ( $album_list );
    my $available_space = LJ::Fotki::UserSpace->get_available_space();

    my $auth_token = LJ::Auth->sessionless_auth_token ($LJ::DOMAIN_WEB."/pics/upload", user => $remote ? $remote->user : undef);
    my $user_groups = LJ::JSON->to_json (LJ::Widget::Fotki::Photo->get_user_groups ($remote));
    my $ljphoto_enabled = $remote->can_upload_photo();

    LJ::Widget::Fotki::Upload->render();
       
    $out .= <<JS;
<script type="text/javascript">
    window.ljphotoEnabled = $ljphoto_enabled;
    jQuery('#updateForm').photouploader({
        availableSpace: '$available_space',
        sizesData: $photo_sizes_json,
        albumsData: $album_list_json,
        privacyData: $user_groups,
        type: 'upload',
        guid: '$auth_token'
    });
</script>
JS
 
    if (@$insert_photos) {
        my $insert_photos_json = LJ::JSON->to_json ( $insert_photos );
        $out .= <<JS;
<script type="text/javascript">
    jQuery('#updateForm')
        .photouploader({
            insertPhotosData: $insert_photos_json,
            type: 'add'
        })
        .bind('htmlready', function (event) {
            var html = event.htmlStrings,
                editor;

            if (window.switchedRteOn) {
                editor = CKEDITOR.instances.draft;

                for (var i = 0, l = html.length; i < l; i++) {
                    editor.insertElement(new CKEDITOR.dom.element.createFromHtml(html[i], editor.document));
                }
            } else {
                jQuery('#draft').val(jQuery('#draft').val() + html.join(' '));
            }
        })
        .photouploader('show');
</script>
JS
    }

    return $out;
}

sub render_body {
    my ($self) = @_;

    LJ::register_hook('add_to_site_js', sub {
        my $site = shift;

        my $remote = LJ::get_remote();
        if (!$remote) {
            return;
        }
        my $login_data = LJ::Protocol::do_request("login", {
                            "ver" => $LJ::PROTOCOL_VER,
                            "username" => $remote->username,
                            "getpickws" => 1,
                            "getpickwurls" => 1,
                        }, undef, {
                            "noauth" => 1,
                            "u" => $remote,
                        });

        my $logins = $login_data->{'usejournals'};
        push @$logins, $remote->username ;

        my $site_data;
        foreach my $login (@$logins) {
            my $u = LJ::load_user($login);

            my $can_manage = $remote->can_manage($u) || 0;
            my $moderated = $u->prop('moderated');
            my $need_moderated = ( $moderated =~ /^[1A]$/ ) ? 1 : 0;
            my $can_post = ($u->{'journaltype'} eq 'C' && !$need_moderated) ||
                            $can_manage;

            $site_data->{$login}->{'is_replace_sticky'} = $u->has_sticky_entry;
            $site_data->{$login}->{'can_create_sticky'} = $can_manage;
            $site_data->{$login}->{'can_post_delayed'} = int $can_post;
        }
        $site->{remote_permissions} = $site_data;
    });

    my $opts = $self->opts;
    my $head = $self->head;
    my $onload = $self->onload;
    my $errors = $self->errors;
    my $js = $self->js;

    my $out = "";
    my $remote = $self->remote;
    my $altlogin = $self->altlogin;
    my ($moodlist, $moodpics);

    # usejournal has no point if you're trying to use the account you're logged
    # in as, so disregard it so we can assume that if it exists, we're trying
    # to post to an account that isn't us
    if ($remote && $opts->{usejournal} &&
        $remote->{user} eq $opts->{usejournal}
    ) {
        delete $opts->{usejournal};
    }

    # Temp fix for FF 2.0.0.17
    my $rte_not_supported = $self->rte_not_supported;
    $opts->{'richtext_default'} = 0 if ($self->rte_not_supported);

    $opts->{'richtext'} = $opts->{'richtext_default'};
    $opts->{'event'} = LJ::durl($opts->{'event'}) if $opts->{'mode'} eq "edit";

    # 1 hour auth token, should be adequate
    my $chal = LJ::challenge_generate(3600);
    my $style = $opts->{'richtext_default'} ? 'hide-html' : 'hide-richtext';
    $out .= "<div id='entry-form-wrapper' class='$style'>";
    $out .= "<input type='hidden' name='chal' id='login_chal' value='$chal' />";
    $out .= "<input type='hidden' name='response' id='login_response' value='' />";

    $out .= LJ::error_list($errors->{entry}) if $errors->{entry};

    my $login_data = $self->login_data;

    $out .= $self->render_top_block;
    $out .= $self->render_subject_block;

    ### Display Spell Check Results:
    if ($opts->{'spellcheck_html'}) {
        $out .= qq{
            <div id='spellcheck-results'>
                <strong>$BML::ML{'entryform.spellchecked'}</strong>
                <br />
                $opts->{'spellcheck_html'}
            </div>
        };
    }

    $out .= $self->render_htmltools_block;

    ## https://jira.sup.com/browse/LJSUP-7534
    ## TODO: after production push, add description of fixed vulnerability here
    LJ::CleanHTML::pre_clean_event_for_entryform(\$opts->{'event'});

    # Main Textarea, with a draft container
    $out .= "<div id='draft-container' class='pkg'>";
    $out .= LJ::html_textarea({
        'name' => 'event',
        'value' => $opts->{'event'},
        'tabindex' => $self->tabindex,
        'disabled' => $opts->{'disabled_save'},
        'id' => 'draft'
    });
    $out .= "</div>";

    $out .= LJ::html_text({
        'disabled' => 1,
        'name' => 'draftstatus',
        'id' => 'draftstatus',
    });

    foreach my $extra (LJ::run_hooks("update_page_extra_html_render", $opts)) {
        $out .= $extra->[0];
    }

    unless ($opts->{'did_spellcheck'}) {
        my %langmap = (
            'UserPrompt' => 'userprompt',
            'InvalidChars' => 'invalidchars',
            'LJUser' => 'ljuser',
            'VideoPrompt' => 'videoprompt',
            'LJVideo' => 'ljvideo2',
            'CutPrompt' => 'cutprompt',
            'ReadMore' => 'readmore',
            'CutContents' => 'cutcontents',
            'LJCut' => 'ljcut',
            'LJEmbedPrompt' => 'ljembedprompt',
            'LJEmbedPromptTitle' => 'ljembedprompttitle',
            'LJEmbed' => 'ljembed',
            'Poll_PollWizardNotice' => 'poll.pollwizardnotice',
            'Poll_PollWizardNoticeLink' => 'poll.pollwizardnoticelink',
            'Poll_AccountLevelNotice' => 'poll.accountlevelnotice',
            'Poll_PollWizardTitle' => 'poll.pollwizardtitle',
            'Poll' => 'poll',
            'LJLike_name' => 'ljlike.name',
            'LJLike_dialogText' => 'ljlike.dialog.text',
            'LJLike_button_google' => 'ljlike.button.google',
            'LJLike_button_facebook' => 'ljlike.button.facebook',
            'LJLike_button_vkontakte' => 'ljlike.button.vkontakte',
            'LJLike_button_twitter' => 'ljlike.button.twitter',
            'LJLike_button_give' => 'ljlike.button.give',
            'LJLike_WizardNotice' => 'ljlike.wizardnotice',
            'LJLike_WizardNoticeLink' => 'ljlike.wizardnoticelink',
            'LJUser_WizardNotice' => 'ljuser.wizardnotice',
            'LJUser_WizardNoticeLink' => 'ljuser.wizardnoticelink',
            'LJLink_WizardNotice' => 'ljlink.wizardnotice',
            'LJLink_WizardNoticeLink' => 'ljlink.wizardnoticelink',
            'LJImage_title' => 'ljimage',
            'LJImage_beta_title' => 'ljimage.beta',
            'LJImage_WizardNotice' => 'ljimage.wizardnotice',
            'LJImage_WizardNoticeLink' => 'ljimage.wizardnoticelink',
            'LJCut_WizardNotice' => 'ljcut.wizardnotice',
            'LJCut_WizardNoticeLink' => 'ljcut.wizardnoticelink',
            'LJRepost_Value' => 'ljrepost',
        );

        my %langmap_translated = map { $_ => BML::ml("fcklang.$langmap{$_}") }
            keys %langmap;

        my $langmap = LJ::JSON->to_json(\%langmap_translated);

        my $jnorich = LJ::ejs(LJ::deemp(BML::ml('entryform.htmlokay.norich2')));
        $out .= $self->wrap_js(qq{
            var CKLang = CKEDITOR.lang[CKEDITOR.lang.detect()] || {};
            jQuery.extend(CKLang, $langmap);
        });

        $out .= qq{
            <noscript>
                <?de $BML::ML{'entryform.htmlokay.norich2'} de?>
                <br />
            </noscript>
        };

        $$js = "initUpdateBml();";
        if ($opts->{'richtext_default'}) {
            $$js .= 'useRichText("' . LJ::ejs($LJ::JSPREFIX) . '");';
        } else {
            $$js .= 'usePlainText();';
        }
        my $ljphoto_enabled = $remote ? $remote->can_upload_photo() : 0;
        $$js .= "window.ljphotoEnabled = $ljphoto_enabled;";
        $$js = $self->wrap_js($$js);

    }

    $out .= LJ::html_hidden({
        name => 'switched_rte_on',
        id => 'switched_rte_on',
        value => '0',
    });

    $out .= $self->render_options_block;
    $out .= LJ::run_hook('entryform_pre_submitbar', $opts);
    $out .= $self->render_submitbar_block;

    ## Show a new photoalbums interface only for logged-in users
    $out .= $self->render_ljphoto_block
        if $remote && $remote->can_upload_photo();

    $out .= "</div><!-- end #entry-form-wrapper -->\n\n";

    return $out;
}

1;