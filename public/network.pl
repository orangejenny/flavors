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
    JS => ['data.js', 'network.js'],
});

print qq{
    <div class="post-nav">
        <div class="chart-container">
            <svg class="network" width="960" height="600"></svg>
        </div>
    </div>
};

print Flavors::HTML::SongsModal();

print Flavors::HTML::Footer();
