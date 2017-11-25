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
    JS => ['categories.js'],
});

my @tags = Flavors::Data::Tag::List($dbh);
my $categorizeargs = Flavors::Util::Categorize($dbh, {
    ITEMS => \@tags,
});
$categorizeargs->{TABLE} = 'flavors_tagcategory';

print qq{ <div class="post-nav"> };

print Flavors::HTML::Categorize($dbh, $categorizeargs);

print qq{ </div> };
print Flavors::HTML::Footer();
