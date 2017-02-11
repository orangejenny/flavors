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

Flavors::HTML::Header($dbh, {
    JS => ['playlists.js', 'filters.js', 'tags.js'],
    TITLE => "Tags",
});

my $results = Flavors::Data::Util::TrySQL($dbh, {
    SUB => 'Flavors::Data::Tag::List',
    ARGS => {
        FILTER => $fdat->{FILTER},
        UPDATEPLAYLIST => 1,
    }
});
my $sqlerror = $results->{ERROR} || "";
my @tags = @{ $results->{RESULTS} };

print Flavors::HTML::FilterControl($dbh, {
    FILTER => $fdat->{FILTER},
    ERROR => $sqlerror,
});

# Print tags by frequency, click to pull up related tags
printf(qq{
    <div class='post-nav'>
        <ul class='text-center'>%s</ul>
    </div>
}, join("", map { Flavors::HTML::Tag($_) } @tags));

printf(q{
    <div id="item-detail" class="modal" data-tag="">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h4>
                        <span class="modal-title"></span>
                        <div class="pull-right">%s</div>
                    </h4>
                </div>
                <div class="modal-body clearfix">
                    <ul class="text-center"></ul>
                </div>
            </div>
        </div>
    </div>
}, Flavors::HTML::ExportControl());

print Flavors::HTML::Footer();
