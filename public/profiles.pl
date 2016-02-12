#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::EchoNest;
use Flavors::HTML;
use Flavors::Data::Playlist;
use Flavors::Data::Song;
use Flavors::Data::Util;

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);

Flavors::HTML::Header({
    TITLE => "Profiles",
    JS => ['echo_nest.js', 'profiles.js'],
    SPINNER => 1,
});

my @playlists = Flavors::Data::Playlist::List($dbh);

print qq{ <div class="post-nav"> };

my $count = Flavors::Data::Song::Count($dbh, {
    FILTER => "echonestid is null",
});

printf(qq{
        <div>
            <button id="populate-ids" class="btn %s" %s>
                <i class="glyphicon glyphicon-%s"></i>
                %s
            </button> 
            <br />
            <br />
        </div>
    },
    $count ? "btn-primary" : "btn-success",
    $count ? "" : "disabled",
    $count ? "search" : "ok",
    $count ? sprintf("Fetch IDs for <span class='count'>%s</span> songs", $count) : "All songs populated",
);

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

print Flavors::EchoNest::ModalHTML();

print Flavors::HTML::Footer();
