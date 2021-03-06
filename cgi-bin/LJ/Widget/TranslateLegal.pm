package LJ::Widget::TranslateLegal;

use strict;
use base qw(LJ::Widget);

sub render {
    my $class = shift;
    my %opts = @_;
    my $GET = $opts{'GET'};
        
    my $lang = $GET->{'uselang'} || BML::get_language() || "en";
    my $file = $ENV{'LJHOME'} . $opts{'file'};
    return $opts{'file'} if $lang eq "debug";
    
    if (-e $file . "." . $lang) {
        $file = $file . "." . $lang;
    }else{
        if (! -e $file){
            return "Error include file!";
        }
    }

    $file =~ s/.*\///;

    return LJ::load_include($file);
}


1;
