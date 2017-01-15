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
    TITLE => "Network",
    BUTTONS => Flavors::HTML::SelectionControl(),
    JS => ['data.js', 'network.js', 'playlists.js', 'song_attributes.js', 'stars.js'],
});

print Flavors::HTML::FilterControl($dbh, {
    TYPE => "collection",
    FILTER => $fdat->{FILTER},
});

print qq{ <div class="post-nav"> };

my @categories = Flavors::Data::Tag::CategoryList($dbh);
printf(qq{
        <div class="well pull-right network-filters">
            <div>
                <select class="category-select form-control">
                    <option value=''>(all categories)</option>
                    %s
                </select>
            </div>
            <div class="input-group strength-select">
                <span class="input-group-addon" data-increment="-1">-</span>
                <input type="text" class="form-control" value="%i" />
                <span class="input-group-addon" data-increment="1">+</span>
            </div>
            <div><span class="label label-info"></span></div>
        </div>
    },
    join("", map { "<option>$_</option>" } sort @categories),
    $fdat->{FILTER} ? 2 : 25,
);

# Chart
print qq{
        <div class="chart-container">
            <svg class="network" width="800" height="600"></svg>
        </div>
};

print qq{ </div> };

print Flavors::HTML::SongsModal();

print Flavors::HTML::Footer();
