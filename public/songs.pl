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
        UPDATEPLAYLIST => 1,
    },
});
my $sqlerror = $results->{ERROR} || "";
my @songs = @{ $results->{RESULTS} };

my $tokens = {};    # token => [songid1, songid2, ... ]
foreach my $song (@songs) {
    my @songtokens = split(/\s+/, lc(join(" ", $song->{NAME}, $song->{ARTIST}, join(" ", @{ $song->{COLLECTIONS} }), $song->{TAGLIST})));
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

my $starred = {map { $_->{ID} => 1 } grep { $_->{ISSTARRED} } @songs};

my $lettercounts = {};
foreach my $letter (keys $letters) {
    $lettercounts->{$letter} = scalar(@{ $letters->{$letter} });
}

Flavors::HTML::Header($dbh, {
    TITLE => "Songs",
    BUTTONS => Flavors::HTML::ExportControl(),
    INITIALPAGEDATA => {
        TOKENS => $tokens,
        LETTERS => $letters,
        LETTERCOUNTS => $lettercounts,
        STARRED => $starred,
    },
    JS => ['songs.js', 'song_attributes.js', 'filters.js', 'playlists.js'],
});

print Flavors::HTML::FilterControl($dbh, {
    ERROR => $sqlerror,
    FILTER => $fdat->{FILTER},
});

print qq{ <div id="song-table-container"> };

print qq{ <table class='song-table'><tbody> };

my @colors = Flavors::Data::Tag::ColorList($dbh);
my %colormap = ();
foreach my $color (@colors) {
    $colormap{$color->{NAME}} = $color;
}
foreach my $song (@songs) {
    print sprintf(qq {
        <tr id="song-%s" data-song-id="%s" data-echo-nest-id="%s" data-colors="%s">
            <td class='icon-cell is-starred'>%s</td>
            <td class='name clickable'>%s</td>
            <td class='artist clickable'>%s</td>
            <td class='collections clickable'>%s</td>
            <td contenteditable='true' data-key='rating' class='rating'>%s</td>
            <td contenteditable='true' data-key='energy' class='rating'>%s</td>
            <td contenteditable='true' data-key='mood' class='rating'>%s</td>
            <td contenteditable='true' data-key='tags'>%s</td>
            <td class='icon-cell %s'>
                <i class='glyphicon glyphicon-font'></i>
            </td>
            <td class='icon-cell see-more'>%s</td>
        </tr>
        },
        $song->{ID},
        $song->{ID},
        $song->{ECHONESTID},
        Flavors::Util::EscapeHTMLAttribute(lc(JSON::to_json([
            grep { $_->{HEX} } map { $colormap{$_} } grep { exists $colormap{$_} } split(/\s+/, $song->{TAGLIST})
        ]))),
        Flavors::HTML::Rating(1, $song->{ISSTARRED} ? 'star' : 'star-empty'),
        $song->{NAME},
        $song->{ARTIST},
        join("", map { sprintf("<div>%s</div>", $_) } @{ $song->{COLLECTIONS} }),
        Flavors::HTML::Rating($song->{RATING}, 'star'),
        Flavors::HTML::Rating($song->{ENERGY}, 'fire'),
        Flavors::HTML::Rating($song->{MOOD}, 'heart'),
        $song->{TAGLIST},
        $song->{HASLYRICS} ? "has-lyrics" : "no-lyrics",
        $song->{ECHONESTID} ? "<i class='glyphicon glyphicon-option-horizontal'></i>" : "",
    );
}

print qq{ </tbody></table> };

print qq{ </div> };

print Flavors::HTML::ItemCount("songs");

print qq{
    <div id="lyrics-detail" class="modal">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h4 class="modal-title"></h4>
                </div>
                <div class="modal-body">
                    <textarea></textarea>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-primary">Save</button>
                    <button class="btn btn-default">Cancel</button>
                </div>
            </div>
        </div>
    </div>
};

print Flavors::HTML::Footer();
