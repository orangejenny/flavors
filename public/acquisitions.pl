#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::HTML;

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);
my $dbh = Flavors::Data::Util::DBH();

my $facet = $fdat->{FACET} || "rating";

Flavors::HTML::Header($dbh, {
    FDAT => $fdat,
    TITLE => "Acquisitions",
    BUTTONS => Flavors::HTML::SelectionControl(),
    JS => ['data.js', 'chart/chart.js', 'chart/acquisitions.js', 'acquisitions.js', 'playlists.js', 'song_attributes.js', 'stars.js'],
});

print Flavors::HTML::FilterControl($dbh, {
    FILTER => $fdat->{FILTER},
});

print qq{
    <div class="post-nav">
        <div class="chart-container">
            <svg></svg>
        </div>
    </div>
};

print Flavors::HTML::SongsModal();

print Flavors::HTML::Footer();
