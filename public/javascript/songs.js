// Globals
var tokens;
var letters;
var letterCounts;
var colors;
var starred;
var songs;

jQuery(document).ready(function() {
    tokens = InitialPageData('tokens');
    letters = InitialPageData('letters');
    letterCounts = InitialPageData('lettercounts');
    colors = InitialPageData('colors');
    starred = InitialPageData('starred');
    songs = InitialPageData('songs');
    updatePagination();

    initSimpleFilter(filterSongs, {
        minLength: 4,
    });

    // Column names hint for filter
    jQuery(".hint").tooltip({
        html: true,
        placement: "right"
    });

    var $table = jQuery("#song-table-container");

    // Highlight on hover
    $table.on("mouseover", "tr", function() {
        // default highlight: pale grey
        var backgroundColor = "fafafa";
        var color = "";

        var $row = jQuery(this);
        var colors = $row.data("colors");
        if (colors.length) {
            colors = colors[Math.floor(Math.random() * colors.length)];
            backgroundColor = colors.HEX;
            if (parseInt(colors.WHITETEXT)) {
                color = "ffffff";
            }
        }
        jQuery(this).css("background-color", backgroundColor);
        jQuery(this).css("color", color);
    });
    $table.on("mouseout", "tr", function() {
        jQuery(this).css("background-color", "");
        jQuery(this).css("color", "");
    });

    // Click to edit
    $("body").on('song-update', function(e, songData) {
        if (songData.key === 'isstarred') {
            starred[songData.id] = songData.value;
        }
        // Update tokens and letters; don't bother with letter counts
        else if (songData.key === 'tags') {
            var id = songData.id,
                oldTokens = songData.oldValue.split(/\s+/),
                newTokens = songData.value.split(/\s+/),
                commonTokens = _.intersection(oldTokens, newTokens);
            oldTokens = _.difference(oldTokens, commonTokens);
            newTokens = _.difference(newTokens, commonTokens);

            // update letters; don't bother deduping
            _.each(newTokens, function(token) {
                letters[token.substring(0, 1)].push(token);
            });

            // update token index and letter counts
            _.each(newTokens, function(token) {
                if (!tokens[token]) {
                    tokens[token] = [];
                    _.each(token.split(""), function(letter) {
                        letterCounts[letter] = (letterCounts[letter] || 0) + 1;
                    });
                }
                tokens[token].push(id);
            });
            _.each(oldTokens, function(token) {
                tokens[token] = _.without(tokens[token], "" + id);
            });
        }
    });

    // Export buttons
    jQuery(".export-dropdown a").click(function() {
        var options = {};
        options.PATH = jQuery(this).text();
        options.SIMPLEFILTER = jQuery("#filter").val();
        options.FILTER = jQuery('#complex-filter textarea').val();
        options.STARRED = !jQuery("#simple-filter .glyphicon-star-empty").length;
        options.FILENAME = options.FILTER || (options.SIMPLEFILTER ? "[" + options.SIMPLEFILTER.trim().replace(/\s+/g, "][") + "]" : "flavors");
        ExportPlaylist(options);
    });

    // View/edit lyrics
    jQuery(".has-lyrics, .no-lyrics").on("click", function() {
        var $row = jQuery(this).closest("tr"),
            id = $row.data("song-id"),
            name = $row.find(".name").text(),
            artist = $row.find(".artist").text();
        CallRemote({
            SUB: 'Flavors::Data::Song::Lyrics',
            ARGS: {
                ID: id,
            },
            FINISH: function(data) {
                var $modal = jQuery("#lyrics-detail"),
                    textarea = $modal.find("textarea");
                $modal.data("song-id", id);
                $modal.find(".modal-title").html(name + " (" + artist + ")");
                $modal.modal();
                textarea.val(data.LYRICS);
                if (!data.LYRICS) {
                    textarea.focus();
                }
            }
        });
    });

    jQuery("#lyrics-detail .btn-primary").on("click", function() {
        var $modal = jQuery("#lyrics-detail"),
            id = $modal.data("song-id"),
            lyrics = $modal.find("textarea").val();
        CallRemote({
            SUB: 'Flavors::Data::Song::UpdateLyrics',
            ARGS: {
                ID: id,
                LYRICS: lyrics,
            },
            FINISH: function() {
                var $cell = jQuery("tr[data-song-id='" + id + "']").find(".no-lyrics, .has-lyrics");
                if (lyrics) {
                    $cell.addClass("has-lyrics");
                    $cell.removeClass("no-lyrics");
                } else {
                    $cell.addClass("no-lyrics");
                    $cell.removeClass("has-lyrics");
                }
                closeLyricsModal();
            },
        });
    });

    jQuery("#lyrics-detail .btn-default").on("click", function() {
        closeLyricsModal();
    });

    // Click on song table to pop up modal of EchoNest song results
    jQuery(".see-more .glyphicon").on("click", function() {
        var $row = jQuery(this).closest("tr"),
            songID = $row.data("song-id"),
            echoNestID = $row.data("echo-nest-id"),
            name = $row.find(".name").text(),
            artist = $row.find(".artist").text();
        if (echoNestID) {
            getAudioSummary({
                SONG_ID: songID,
                ECHO_NEST_ID: echoNestID,
            });
        }
    });
});

function updatePagination() {
    var count = jQuery("#song-table-container tbody tr:visible").length;
    var $container = jQuery("#item-pagination .pagination");
    $container.empty();
    var template = _.template("<li class='<%= cssClass %>'><a href='#'><%= content %></a></li>");
    $container.append(template({ content: "&laquo;", cssClass: "" }));
    _.each(_.range(Math.ceil(count / 100)), function(p) {
        $container.append(template({ content: p + 1, cssClass: "" }));
    });
    $container.append(template({ content: "&raquo;", cssClass: "" }));
    // TODO: ellipsis (.disabled) if there are more than 9 pages
    // TODO: make pagination work (keep track of 'visible' items, only display pageCount items, change page when link clicked, mark .active link)
}

function filterSongs(force) {
    var query = jQuery("#filter").val(),
        queryTokens = _.without(query.split(/\s+/), ""),
        onlyStarred = !jQuery("#simple-filter .glyphicon-star-empty").length;

    // If there's no text in the filter; just check the star filter
    var $tbody = $("#song-table-container tbody");
        templateSong = _.template($("#template-song-row").text()),
        templateRating = _.template($("#template-rating").text());

    $tbody.empty();
    var _showSong = function(id) {
        var song = songs[id];
        $tbody.append(templateSong(_.extend({}, song, {
            // TODO: parseInt somewhere better (same below)
            ratingStar: templateRating({ rating: 1, symbol: parseInt(song.ISSTARRED) ? 'star' : 'star-empty' }),
            ratingRating: templateRating({ rating: song.RATING, symbol: 'star' }),
            ratingEnergy: templateRating({ rating: song.ENERGY, symbol: 'fire' }),
            ratingMood: templateRating({ rating: song.MOOD, symbol: 'heart' }),
            lyricsClass: parseInt(song.HASLYRICS) ? "has-lyrics" : "no-lyrics",
            colors: JSON.stringify(_.filter(_.compact(_.map((song.TAGLIST || "").split(/\s+/), function(t) { return colors[t]; })), function(c) { return c.HEX; })),
        })));
    };

    if (!queryTokens.length) {
        idsToShow = _.keys(onlyStarred ? starred : songs);
        _.each(_.keys(onlyStarred ? starred : songs), _showSong);
        updatePagination();
        return true;
    }

    var matches = {};    // song id => { queryToken1 => 1, queryToken2 => 1, ... }
    _.each(queryTokens, function(queryToken) {
        var leastCommonLetter = _.min(queryToken.split(""), function(letter) {
            return letterCounts[letter];
        });

        _.each(letters[leastCommonLetter], function(searchToken) {
            if (searchToken.indexOf(queryToken) != -1) {
                _.each(tokens[searchToken], function(songID) {
                    if (!matches[songID]) {
                        matches[songID] = {};
                    }
                    matches[songID][queryToken] = 1;
                });
            }
        });
    });

    _.each(matches, function(matchTriggers, songID) {
        if (_.values(matchTriggers).length === queryTokens.length && (!onlyStarred || starred[songID])) {
            _showSong(songID);
        }
    });

    updatePagination();
    return true;
}

function closeLyricsModal() {
    var $modal = jQuery("#lyrics-detail");
    $modal.find(".modal-title").html("");
    $modal.find("textarea").val("");
    $modal.modal('hide');
}
