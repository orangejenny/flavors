#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Tag;
use Flavors::Data::Util;
use Flavors::HTML;

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

my $facet = $fdat->{FACET} || "rating";
my %icons = (
    rating => 'star',
    mood => 'heart',
    energy => 'fire',
);

Flavors::HTML::Header($dbh, {
    FDAT => $fdat,
    TITLE => ucfirst $facet,
    BUTTONS => Flavors::HTML::SelectionControl(),
    JS => ['data.js', 'facet.js', 'playlists.js', 'song_attributes.js', 'stars.js'],
});

print Flavors::HTML::FilterControl($dbh, {
    TYPE => "song",
    FILTER => $fdat->{FILTER},
});

print qq{ <div class="post-nav text-center"> };

# Distribution and rated/unrated chart
printf(qq{
        <div class="facet-container" data-facet="%s">
            <div class="histogram-container">
                <svg></svg>
            </div>
            <div class='axis'>%s</div>
            <div class="binary-container">
                <svg></svg>
            </div>
        </div>
    },
    $facet,
    join("", map { sprintf("<span class='axis-label'>%s</span>", Flavors::HTML::Rating($_, $icons{$facet})) } (1..5)),
);

# Toolbar
my @categories = Flavors::Data::Tag::CategoryList($dbh);
push(@categories, "genres");
print "<div class='btn-group category-buttons'>";
foreach my $category (sort @categories) {
    printf("<button class='btn btn-default' data-category='%s'>%s</button>", $category, $category);
}
print "</div>";

# Category charts
print qq{ <div> };
print sprintf(qq{
    <div class="category-container" data-facet="%s">
        <svg></svg>
    </div>
}, $facet, $icons{$facet});
print qq{ </div> };

print qq{ </div> };    # .post-nav

print Flavors::HTML::SongsModal();

print Flavors::HTML::Footer();
