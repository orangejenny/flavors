#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Tag;
use Flavors::Data::Util;
use Flavors::HTML;

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
Flavors::HTML::Header($dbh, {
    CSS => ['tags.css'],
    JS => ['tags.js'],
    TITLE => "Tags",
});

my @tags = Flavors::Data::Tag::List($dbh);

# Print tags by frequency, click to pull up related tags
printf(qq{
    <div class='post-nav'>
        <ul class='tags'>%s</ul>
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
                    <ul class="tags"></ul>
                    <table class="songs"></table>
                </div>
            </div>
        </div>
    </div>
}, Flavors::HTML::ExportControl());

print Flavors::HTML::Footer();
