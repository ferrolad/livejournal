package LJ::Setting::FindByEmail;
use base 'LJ::Setting';
use strict;
use warnings;

sub tags { qw(email search) }

sub helpurl {
    my ($class, $u) = @_;

    return "find_by_email";
}

*option = \&as_html;
sub as_html {
    my ($class, $u, $errs, $args) = @_;
    $args ||= {};
    my $key = $class->pkgkey;
    my $ret;
    my $helper = (defined $args->{helper} and $args->{helper} == 0) ? 0 : 1;
    my $faq = (defined $args->{faq} and $args->{faq} == 1) ? 1 : 0;
    my $display_null = (defined $args->{display_null} and $args->{display_null} == 0) ? 0 : 1;

    $ret .= "<label for='${key}opt_findbyemail'>" .
            $class->ml('settings.findbyemail.question',
                { sitename => $LJ::SITENAMESHORT }) . "</label>";

    # Display learn more link?
    $ret .= " (<a href='" . $LJ::HELPURL{$class->helpurl($u)} .
            "'>" . $class->ml('settings.settingprod.learn') . "</a>)<br />"
                if ($faq && $LJ::HELPURL{$class->helpurl($u)});

    $ret .= "<br />";
    my @options;
    push @options, { text => $class->ml('settings.option.select'), value => '' }
        if not $u->opt_findbyemail and $display_null;
    my $default = $display_null ? '' : 'H';
    push @options, { text => LJ::Lang::ml('settings.findbyemail.opt.Y'), value => "Y" };
    push @options, { text => LJ::Lang::ml('settings.findbyemail.opt.H'), value => "H" };
    push @options, { text => LJ::Lang::ml('settings.findbyemail.opt.N'), value => "N" };
    $ret .= LJ::html_select({ 'name' => "${key}opt_findbyemail",
                              'id' => "${key}opt_findbyemail",
                         ###  'class' => "select",
                              'selected' => $u->opt_findbyemail || $default },
                              @options );

    # Display helper text about setting?
    $ret .= "<div class='helper'>" .
            $class->ml('settings.findbyemail.helper', {
                sitename => $LJ::SITENAMESHORT,
                siteabbrev => $LJ::SITENAMEABBREV }) .
            "</div>" if ($helper);
    $ret .= 
        "<div class='helper'>" . 
        $class->ml('settings.findbyemail.notice', {siteroot => $LJ::SITEROOT}) . 
        "</div>";
                
    $ret .= $class->errdiv($errs, "opt_findbyemail");

    return $ret;
}

sub error_check {
    my ($class, $u, $args) = @_;
    my $opt_findbyemail = $class->get_arg($args, "opt_findbyemail");
    $class->errors("opt_findbyemail" => $class->ml('settings.findbyemail.error.invalid')) unless $opt_findbyemail=~ /^[NHY]$/;
    return 1;
}

sub save {
    my ($class, $u, $args) = @_;
    $class->error_check($u, $args);

    my $opt_findbyemail = $class->get_arg($args, "opt_findbyemail");
    return $u->set_prop('opt_findbyemail', $opt_findbyemail);
}

sub label {
    my $class = shift;
    $class->ml('settings.findbyemail.label');
}

# return key value pairs for field names and values chosen
sub settings {
    my ($class, $args) = @_;

    my @list;
    push @list, "opt_findbyemail";
    push @list, $class->get_arg($args, "opt_findbyemail") || '';

    return @list;
}

1;
