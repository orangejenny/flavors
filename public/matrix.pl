#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Util;
use Flavors::HTML;

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

my $dbh = Flavors::Data::Util::DBH();

Flavors::HTML::Header($dbh, {
    FDAT => $fdat,
    TITLE => "Matrix",
    BUTTONS => Flavors::HTML::SelectionControl(),
    CSS => ['data.css', 'matrix.css', 'song_attributes.css'],
    JS => ['data.js', 'chart/matrix.js', 'matrix.js', 'song-attributes.js'],
});

printf(qq{
        <div class="post-nav">
            <div class="post-nav-positioning">
                <div class="axis-label mood-high">%s</div>
                <div class="axis-label energy-high">%s</div>
                <div class="axis-label energy-low">%s</div>
                <div class="chart-container">
                    <svg></svg>
                </div>
                <div class="axis-label mood-low">%s</div>
            </div>
        </div>
    },
    Flavors::HTML::Rating(5, 'heart'),
    Flavors::HTML::Rating(5, 'fire'),
    Flavors::HTML::Rating(1, 'fire'),
    Flavors::HTML::Rating(1, 'heart'),
);

print Flavors::HTML::SongsModal();

print Flavors::HTML::Footer();
