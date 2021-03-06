package LJ::Widget::CurrentTheme;

use strict;
use base qw(LJ::Widget);
use Carp qw(croak);
use Class::Autouse qw( LJ::Customize );
use LJ::Pay::Theme;

sub ajax { 1 }
sub authas { 1 }
sub need_res { qw( stc/widgets/currenttheme.css ) }

sub render_body {
    my $class = shift;
    my %opts = @_;

    my $u = $class->get_effective_remote();
    die "Invalid user." unless LJ::isu($u);

    my $remote = LJ::get_remote();
    my $getextra = $u->user ne $remote->user ? "?authas=" . $u->user : "";
    my $getsep = $getextra ? "&" : "?";

    my $filterarg = $opts{filter_available} ? "&filter_available=1" : "";
    my $showarg = $opts{show} != 12 ? "&show=$opts{show}" : "";
    my $no_theme_chooser = defined $opts{no_theme_chooser} ? $opts{no_theme_chooser} : 0;
    my $no_layer_edit = LJ::run_hook("no_theme_or_layer_edit", $u);

    my $theme = LJ::Customize->get_current_theme($u);
    my $userlay = LJ::S2::get_layers_of_user($u);
    my $layout_name = $theme->layout_name;
    my $designer = $theme->designer;

    my $ret;
    $ret .= "<h2 class='widget-header'><span>" . $class->ml('widget.currenttheme.title', {'user' => $u->ljuser_display}) . "</span></h2>";
    $ret .= "<div class='theme-current-content pkg'>";
    $ret .= "<img src='" . $theme->preview_imgurl . "' class='theme-current-image' />";
    $ret .= "<h3>" . $theme->name . "</h3>";

    my $layout_link = "<a href='$LJ::SITEROOT/customize/$getextra${getsep}layoutid=" . $theme->layoutid . "$filterarg$showarg' class='theme-current-layout'><em>$layout_name</em></a>";
    my $special_link_opts = "href='$LJ::SITEROOT/customize/$getextra${getsep}cat=special$filterarg$showarg' class='theme-current-cat'";
    $ret .= "<p class='theme-current-desc'>";
    if ($designer) {
        my $designer_link = "<a href='$LJ::SITEROOT/customize/$getextra${getsep}designer=" . LJ::eurl($designer) . "$filterarg$showarg' class='theme-current-designer'>$designer</a>";
        if (LJ::run_hook("layer_is_special", $theme->uniq)) {
            $ret .= $class->ml('widget.currenttheme.specialdesc', {'aopts' => $special_link_opts, 'designer' => $designer_link});
        } else {
            $ret .= $class->ml('widget.currenttheme.desc', {'layout' => $layout_link, 'designer' => $designer_link});
        }
    } elsif ($layout_name) {
        $ret .= $layout_link;
    }
    $ret .= "</p>";

    $ret .= "<div class='theme-current-links'>";
    $ret .= $class->ml('widget.currenttheme.options');
    $ret .= "<ul class='nostyle'>";
    if ($no_theme_chooser) {
        $ret .= "<li><a href='$LJ::SITEROOT/customize/$getextra'>" . $class->ml('widget.currenttheme.options.newtheme') . "</a></li>";
    } else {
        $ret .= "<li><a href='$LJ::SITEROOT/customize/options.bml$getextra'>" . $class->ml('widget.currenttheme.options.change') . "</a></li>";
    }
    if (! $no_layer_edit && $theme->is_custom && $theme->available_to($u)) {
        if ($theme->layoutid && !$theme->layout_uniq) {
            $ret .= "<li><a href='$LJ::SITEROOT/customize/advanced/layeredit.bml?id=" . $theme->layoutid . "'>" . $class->ml('widget.currenttheme.options.editlayoutlayer') . "</a></li>";
        }
        if ($theme->themeid && !$theme->uniq) {
            $ret .= "<li><a href='$LJ::SITEROOT/customize/advanced/layeredit.bml?id=" . $theme->themeid . "'>" . $class->ml('widget.currenttheme.options.editthemelayer') . "</a></li>";
        }
    }

    unless ($no_theme_chooser) {
        $ret .= "<li><a href='$LJ::SITEROOT/customize/$getextra#layout'>" . $class->ml('widget.currenttheme.options.layout') . "</a></li>";
    }
    $ret .= "</ul>";
    $ret .= "</div><!-- end .theme-current-links -->";
    $ret .= "</div><!-- end .theme-current-content -->";

    return $ret;
}

sub js {
    q [
        initWidget: function () {
            var self = this;

            var filter_links = DOM.getElementsByClassName(document, "theme-current-cat");
            filter_links = filter_links.concat(DOM.getElementsByClassName(document, "theme-current-layout"));
            filter_links = filter_links.concat(DOM.getElementsByClassName(document, "theme-current-designer"));

            // add event listeners to all of the category, layout, and designer links
            filter_links.forEach(function (filter_link) {
                var getArgs = LiveJournal.parseGetArgs(filter_link.href);
                for (var arg in getArgs) {
                    if (arg == "authas" || arg == "filter_available" || arg == "show") continue;
                    DOM.addEventListener(filter_link, "click", function (evt) { Customize.ThemeNav.filterThemes(evt, arg, getArgs[arg]) });
                    break;
                }
            });
        },
        onRefresh: function (data) {
            this.initWidget();
        }
    ];
}

1;
