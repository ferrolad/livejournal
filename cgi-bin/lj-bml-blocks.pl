package LJ;
use strict;

use lib "$ENV{LJHOME}/cgi-bin";
use LJ::Config;
LJ::Config->load;

BML::register_block("DOMAIN", "S", $LJ::DOMAIN);

BML::register_block("SITEROOT", "S", $LJ::SITEROOT);
BML::register_block("SITENAME", "S", $LJ::SITENAME);
BML::register_block("ADMIN_EMAIL", "S", $LJ::ADMIN_EMAIL);
BML::register_block("SUPPORT_EMAIL", "S", $LJ::SUPPORT_EMAIL);
BML::register_block("CHALRESPJS", "", $LJ::COMMON_CODE{'chalresp_js'});

BML::register_block("IMGPREFIX", "S", sub {
    return $LJ::IS_SSL ? $LJ::SSLIMGPREFIX : $LJ::IMGPREFIX;
});

BML::register_block("STATPREFIX", "S", sub {
    return $LJ::IS_SSL ? $LJ::SSLSTATPREFIX : $LJ::STATPREFIX;
});

BML::register_block("JSPREFIX", "S", sub {
    return $LJ::IS_SSL ? $LJ::SSLJSPREFIX : $LJ::JSPREFIX;
});

# dynamic blocks to implement calling our ljuser function to generate HTML
#    <?ljuser banana ljuser?>
#    <?ljcomm banana ljcomm?>
#    <?ljuserf banana ljuserf?>
BML::register_block("LJUSER", "DS", sub { LJ::ljuser($_[0]->{DATA}); });
BML::register_block("LJCOMM", "DS", sub { LJ::ljuser($_[0]->{DATA}); });
BML::register_block("LJUSERF", "DS", sub { LJ::ljuser($_[0]->{DATA}, { full => 1 }); });

# dynamic needlogin block, needs to be dynamic so we can get at the full URLs and
# so we can translate it
BML::register_block("NEEDLOGIN", "", \&LJ::needlogin_redirect);

{
    my $dl = "<a href=\"$LJ::SITEROOT/files/%%DATA%%\">HTTP</a>";
    BML::register_block("DL", "DR", $dl);
}

if ($LJ::UNICODE) {
    BML::register_block("METACTYPE", "S", '<meta http-equiv="Content-Type" content="text/html; charset=utf-8">')
} else {
    BML::register_block("METACTYPE", "S", '<meta http-equiv="Content-Type" content="text/html">')
}


1;
