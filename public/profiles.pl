#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::HTML;
use Flavors::Data::Playlist;
use Flavors::Data::Song;
use Flavors::Data::Util;

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

Flavors::HTML::Header($dbh, {
    TITLE => "Profiles",
    JS => ['profiles.js'],
    SPINNER => 1,
});

my @playlists = Flavors::Data::Playlist::List($dbh);

print qq{ <div class="post-nav"> };

print qq{ <table class="table table-striped table-hover"> };
foreach my $playlist (@playlists) {
    if ($playlist->{ISSTARRED} || $playlist->{ISDEFAULT}) {
        printf(qq{
            <tr>
                <td>%s</td>
                <td>TODO</td>
            </tr>
        }, $playlist->{FILTER});
    }
}
print qq{ </table> };

print qq{ </div> };

print Flavors::HTML::Footer();
