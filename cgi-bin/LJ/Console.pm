# LJ::Console family of libraries
#
# Initial structure:
#
# LJ::Console.pm                 # wrangles commands, parses input, etc
# LJ::Console::Command.pm        # command base class
# LJ::Console::Command::Foo.pm   # individual command implementation
# LJ::Console::Response.pm       # success/failure, very simple
#
# Usage:
#
# my $out_html = LJ::Console->run_commands_html($user_input);
# my $out_text = LJ::Console->run_commands_text($user_text);
#

package LJ::Console;

use strict;
use Carp qw(croak);

use LJ::ModuleLoader;
# use LJ::Console::Command::InvalidCommand;

my @CLASSES = module_subclasses("LJ::Console::Command");
my %cmd2class;
foreach my $class (@CLASSES) {
    eval "use $class";
    die "Error loading class '$class': $@" if $@;
    $cmd2class{$class->cmd} = $class;
}

# takes a set of console commands, returns command objects
sub parse_text {
    my $class = shift;
    my $text = shift;

    my @ret;

    foreach my $line (split(/\n/, $text)) {
        my @args = LJ::Console->parse_line($line);

        my $cmd_name = lc(shift @args);
        my $cmd_class = $cmd2class{$cmd_name} || "LJ::Console::Command::InvalidCommand";

        push @ret, $cmd_class->new(
                                   command => $cmd_name,
                                   args    => \@args,
                                   );
    }

    return @ret;
}

# parses each console command, parses out the arguments
sub parse_line {
    my $class = shift;
    my $cmd = shift;

    return () unless $cmd =~ /\S/;

    $cmd =~ s/^\s+//;
    $cmd =~ s/\s+$//;
    $cmd =~ s/\t/ /g;

    my $state = 'a';  # w=whitespace, a=arg, q=quote, e=escape (next quote isn't closing)

    my @args;
    my $argc = 0;
    my $len = length($cmd);
    my ($lastchar, $char);

    for (my $i=0; $i < $len; $i++) {
        $lastchar = $char;
        $char = substr($cmd, $i, 1);

        ### jump out of quots
        if ($state eq "q" && $char eq '"') {
            $state = "w";
            next;
        }

        ### keep ignoring whitespace
        if ($state eq "w" && $char eq " ") {
            next;
        }

        ### finish arg if space found
        if ($state eq "a" && $char eq " ") {
            $state = "w";
            next;
        }

        ### if non-whitespace encountered, move to next arg
        if ($state eq "w") {
            $argc++;
            if ($char eq '"') {
                $state = "q";
                next;
            } else {
                $state = "a";
            }
        }

        ### don't count this character if it's a quote
        if ($state eq "q" && $char eq '"') {
            $state = "w";
            next;
        }

        ### respect backslashing quotes inside quotes
        if ($state eq "q" && $char eq "\\") {
            $state = "e";
            next;
        }

        ### after an escape, next character is literal
        if ($state eq "e") {
            $state = "q";
        }

        $args[$argc] .= $char;
    }

    return @args;
}

# takes a set of response objects and returns string implementation
sub run_commands_text {
    my ($pkg, $text) = @_;

    my $out;
    foreach my $c (LJ::Console->parse_text($text)) {
        $c->execute_safely;
        $out .= join("\n", map { $_->as_string } $c->responses) . "\n";
    }
    return $out;
}

sub run_commands_html {
    my ($pkg, $text) = @_;

    my $out;

    foreach my $c (LJ::Console->parse_text($text)) {
        $c->execute_safely;
        $out .= join("<br />", map { $_->as_html } $c->responses) . "<br />";
    }
    return $out;
}

1;
