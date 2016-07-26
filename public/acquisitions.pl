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
    CSS => ['data.css', 'song_attributes.css'],
    JS => ['data.js', 'chart/chart.js', 'chart/acquisitions.js', 'acquisitions.js', 'song-attributes.js'],
});

print qq{
    <div class="post-nav">
        <div class="chart-container">
            <svg></svg>
        </div>
    </div>
};

printf(qq{
    <div id="song-list" class="modal">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h4>
                        <div class="pull-right">%s</div>
                        <span class="modal-title">Song Selection</span>
                    </h4>
                </div>
                <div class="modal-body"></div>
            </div>
        </div>
    </div>
}, Flavors::HTML::ExportControl());

print Flavors::HTML::Footer();
