#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::HTML;
use Flavors::Data::Tag;
use Flavors::Data::Util;

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

Flavors::HTML::Header($dbh, {
    CSS => ['colors.css'],
    JS => ['colors.js'],
});

my @colors = Flavors::Data::Tag::ColorList($dbh);

print qq{ <div class="post-nav form-group"> };

foreach my $color (@colors) {
    printf(qq{
            <div class="color">
                <div class="name">%s</div>
                <input class="minicolors-input form-control" value="#%s" />
                <div class="btn-group white-text" data-toggle="buttons-radio">
                    <button class="btn btn-default%s" value="0">black text</button>
                    <button class="btn btn-default%s" value="1">white text</button>
                </div>
            </div>
        },
        $color->{NAME},
        $color->{HEX},
        $color->{WHITETEXT} ? "" : " active",
        $color->{WHITETEXT} ? " active" : "",
    );
}

print qq{ </div> };
print Flavors::HTML::Footer();
