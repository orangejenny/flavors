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

my @colors = Flavors::Data::Tag::ColorList($dbh);
my %colormap = ();
foreach my $color (@colors) {
    $colormap{$color->{NAME}} = $color;
}

Flavors::HTML::Header($dbh, {
    TITLE => "Songs",
    BUTTONS => Flavors::HTML::ExportControl(),
    INITIALPAGEDATA => {
        TOKENS => $tokens,
        COLORS => \%colormap,
        LETTERS => $letters,
        LETTERCOUNTS => $lettercounts,
        STARRED => $starred,
        SONGS => { map { $_->{ID} => $_ } @songs },
    },
    JS => ['songs.js', 'song_attributes.js', 'filters.js', 'playlists.js'],
});

print Flavors::HTML::FilterControl($dbh, {
    ERROR => $sqlerror,
    FILTER => $fdat->{FILTER},
});

print qq{
    <div id="song-table-container">
        <table class='song-table'>
            <tbody></tbody>
        </table>
    </div>
};

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

print qq{
    <script type="text/html" id="template-song-row">
        <tr id="song-<%= ID %>" data-song-id="<%= ID %>" data-echo-nest-id="<%= ECHONESTID %>" data-colors='<%= colors %>'>
            <td class='icon-cell is-starred'><%= ratingStar %></td>
            <td class='name clickable'><%= NAME %></td>
            <td class='artist clickable'><%= ARTIST %></td>
            <td class='collections clickable'>
                <% _.each(COLLECTIONS, function(c) { %>
                    <div><%= c %></div>
                <% }) %>
            </td>
            <td contenteditable='true' data-key='rating' class='rating'><%= ratingRating %></td>
            <td contenteditable='true' data-key='energy' class='rating'><%= ratingEnergy %></td>
            <td contenteditable='true' data-key='mood' class='rating'><%= ratingMood %></td>
            <td contenteditable='true' data-key='tags'><%= TAGLIST %></td>
            <td class='icon-cell <%= lyricsClass %>'>
                <i class='glyphicon glyphicon-font'></i>
            </td>
            <td class='icon-cell see-more'>
                <% if (ECHONESTID) { %>
                    <i class='glyphicon glyphicon-option-horizontal'></i>
                <% } %>
            </td>
        </tr>
    </script>
};

print qq{
    <script type="text/html" id="template-rating">
        <% _.each(_.range(rating), function(i) { %><span class='glyphicon glyphicon-<%= symbol %><% if (!rating) { %> blank<% } %>'></span><% }) %>
    </script>
};

print Flavors::HTML::Footer();
