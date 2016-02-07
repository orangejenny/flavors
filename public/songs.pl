#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Playlist;
use Flavors::Data::Song;
use Flavors::Data::Tag;
use Flavors::Data::Util;
use Flavors::HTML;
use Flavors::Util;
use JSON qw(to_json);

my $dbh = Flavors::Data::Util::DBH();
my $fdat = Flavors::Util::Fdat();

my $cgi = CGI->new;
print $cgi->header();

my $results = Flavors::Data::Util::TrySQL($dbh, {
    SUB => 'Flavors::Data::Song::List',
    ARGS => {
        FILTER => $fdat->{FILTER},
        ORDERBY => $fdat->{ORDERBY},
        SPINNER => 1,
    },
});
my $sqlerror = $results->{ERROR} || "";
my @songs = @{ $results->{RESULTS} };

if (!$sqlerror) {
    Flavors::Data::Playlist::Update($dbh, {
        FILTER => $fdat->{FILTER},
    });
}

my $tokens = {};    # token => [songid1, songid2, ... ]
foreach my $song (@songs) {
    my @songtokens = split(/\s+/, lc(join(" ", $song->{NAME}, $song->{ARTIST}, join(" ", @{ $song->{COLLECTIONS} }), $song->{TAGS})));
    my $songtokenset = {};
    foreach my $token (@songtokens) {
        if ($token) {
            $songtokenset->{$token} = 1;
        }
    }
    foreach my $token (keys $songtokenset) {
        if (!$tokens->{$token}) {
            $tokens->{$token} = [];
        }
        push($tokens->{$token}, $song->{ID});
    }
}

my $letters = {};    # letter => [token1, token2, ... ]
foreach my $token (keys $tokens) {
    foreach my $letter (split(//, $token)) {
        if (!$letters->{$letter}) {
            $letters->{$letter} = [];
        }
        push($letters->{$letter}, $token);
    }
}

my $lettercounts = {};
foreach my $letter (keys $letters) {
    $lettercounts->{$letter} = scalar(@{ $letters->{$letter} });
}

Flavors::HTML::Header({
    TITLE => "Songs",
    BUTTONS => Flavors::HTML::ExportControl(),
    INITIALPAGEDATA => {
        TOKENS => $tokens,
        LETTERS => $letters,
        LETTERCOUNTS => $lettercounts,
    },
    CSS => ['filters.css', 'songs.css', 'thirdparty/jquery.atwho.min.css'],
    JS => ['songs.js', 'thirdparty/jquery.caret.min.js', 'thirdparty/jquery.atwho.min.js'],
});

my @playlists = Flavors::Data::Playlist::List($dbh);
print Flavors::HTML::FilterModal($dbh, {
    ADDITIONALMARKUP => sprintf(qq{
            <ul class="playlists">
                %s
            </ul>
        },
        join("", map {
            sprintf(
                "<li data-id='%s'>%s <a href='#'>%s</a></li>",
                $_->{ID}, 
                Flavors::HTML::Rating(1, $_->{ISSTARRED} ? 'star' : 'star-empty'), 
                $_->{FILTER},
            )
        } @playlists),
    ),
    ERROR => $sqlerror,
    FILTER => $fdat->{FILTER},
    HINTS => [qw(
        id name artist rating energy mood time filename ismix mincollectioncreated
        maxcollectioncreated taglist tagcount collectionlist minyear maxyear isstarred
    )],
});

print qq{ <div class="post-nav"> };
print Flavors::HTML::FilterControl($dbh, {
    FILTER => $fdat->{FILTER},
});

print qq{ <div id="song-table-container"> };

print qq{ <table><tbody> };

my @colors = Flavors::Data::Tag::ColorList($dbh);
my %colormap = ();
foreach my $color (@colors) {
    $colormap{$color->{NAME}} = $color;
}
foreach my $song (@songs) {
    print sprintf(qq {
        <tr id="song-%s" data-song-id="%s" data-colors="%s">
            <td class='isstarred'>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td contenteditable='true' class='rating'>%s</td>
            <td contenteditable='true' class='rating'>%s</td>
            <td contenteditable='true' class='rating'>%s</td>
            <td contenteditable='true'>%s</td>
        </tr>
        },
        $song->{ID},
        $song->{ID},
        Flavors::Util::EscapeHTMLAttribute(lc(JSON::to_json([
            grep { $_->{HEX} } map { $colormap{$_} } grep { exists $colormap{$_} } split(/\s+/, $song->{TAGS})
        ]))),
        Flavors::HTML::Rating(1, $song->{ISSTARRED} ? 'star' : 'star-empty'),
        $song->{NAME},
        $song->{ARTIST},
        join("<br>", @{ $song->{COLLECTIONS} }),
        Flavors::HTML::Rating($song->{RATING}, 'star'),
        Flavors::HTML::Rating($song->{ENERGY}, 'fire'),
        Flavors::HTML::Rating($song->{MOOD}, 'heart'),
        $song->{TAGS},
    );
}

print qq{ </tbody></table> };

print qq{</div> };
print qq{ </div> };

print qq{
    <div id="song-count-container">
        <span id="song-count-span">
            <span id="song-count"></span> songs
        </span>
    </div>
};

print Flavors::HTML::Footer();
