#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Util;
use Flavors::HTML;

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

my $dbh = Flavors::Data::Util::DBH();

my $facet = $fdat->{FACET} || "rating";

Flavors::HTML::Header($dbh, {
    FDAT => $fdat,
    TITLE => "Timeline",
    BUTTONS => Flavors::HTML::SelectionControl(),
    JS => ['data.js', 'chart/chart.js', 'chart/timeline.js', 'timeline.js', 'song_attributes.js', 'playlists.js', 'filters.js'],
});

print Flavors::HTML::FilterControl($dbh, {
    FILTER => $fdat->{FILTER},
});

print qq{
    <div class="post-nav">
        <div class="timeline-container">
            <svg></svg>
        </div>
    </div>
};

print Flavors::HTML::SongsModal();

print Flavors::HTML::Footer();
