// Globals
var tokens;
var letters;
var letterCounts;
var colors;
var starred;
var allSongs;       // { id: song }
var visibleSongs;   // [ id ]
var currentPage;
var songsPerPage = 100;

jQuery(document).ready(function() {
    tokens = InitialPageData('tokens');
    letters = InitialPageData('letters');
    letterCounts = InitialPageData('lettercounts');
    colors = InitialPageData('colors');
    starred = InitialPageData('starred');
    allSongs = InitialPageData('songs');

    initSimpleFilter(filterSongs);

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
        options.CONFIG = jQuery(this).data("name");
        options.SIMPLEFILTER = jQuery("#filter").val();
        options.FILTER = jQuery('#complex-filter textarea').val();
        options.STARRED = jQuery("#simple-filter .fas.fa-star").length;
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
    jQuery(".see-more .fas").on("click", function() {
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

function filterSongs(force) {
    var query = jQuery("#filter").val().toLowerCase(),
        queryTokens = _.without(query.split(/\s+/), ""),
        onlyStarred = jQuery("#simple-filter .fas.fa-star").length;
    currentPage = 1;

    // If there's no text in the filter; just check the star filter
    if (!queryTokens.length) {
        visibleSongs = _.keys(onlyStarred ? starred : allSongs);
    } else {
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
    
        visibleSongs = [];
        _.each(matches, function(matchTriggers, songID) {
            if (_.values(matchTriggers).length === queryTokens.length && (!onlyStarred || starred[songID])) {
                visibleSongs.push(songID);
            }
        });
    }

    // Randomize
    if (!jQuery("#simple-filter .fa-random").hasClass("text-muted")) {
        visibleSongs = _.sortBy(visibleSongs, function() { return Math.random(); })
    }

    showSongs();

    return visibleSongs.length;
}

function showPage() {
    var $tbody = $("#song-table-container tbody"),
        templateSong = _.template($("#template-song-row").text()),
        templateRating = _.template($("#template-rating").text());

    $tbody.empty();
    _.each(visibleSongs.slice(songsPerPage * (currentPage - 1), songsPerPage * currentPage), function(id) {
        var song = allSongs[id];
        $tbody.append(templateSong(_.extend({}, song, {
            // TODO: parseInt somewhere better (same below)
            ratingStar: "<i class='" + (parseInt(song.ISSTARRED) ? "fas" : "far") + " fa-star'></i>",
            ratingRating: templateRating({ rating: song.RATING, symbol: 'star' }),
            ratingEnergy: templateRating({ rating: song.ENERGY, symbol: 'fire' }),
            ratingMood: templateRating({ rating: song.MOOD, symbol: 'heart' }),
            lyricsClass: parseInt(song.HASLYRICS) ? "has-lyrics" : "no-lyrics",
            colors: JSON.stringify(_.filter(_.compact(_.map((song.TAGLIST || "").split(/\s+/), function(t) { return colors[t]; })), function(c) { return c.HEX; })),
        })));
    });
}

function showSongs() {
    var count = visibleSongs.length,
        $container = jQuery("#item-pagination .pagination"),
        totalPages = Math.ceil(count / songsPerPage);

    showPage();
    $container.empty();
    if (count === 0) {
        return;
    }

    var template = _.template("<li data-<%= dataName %>='<%= dataValue %>'><a href='#'><%= content %></a></li>");
    $container.append(template({ content: "&laquo;", dataName: 'increment', dataValue: '-1' }));

    var maxWidgetPages = 5,
        halfWidgetPages = Math.floor(maxWidgetPages / 2);
    _.each(_.range(Math.min(totalPages / 2, halfWidgetPages)), function(p) {
        $container.append(template({ content: p + 1, dataName: 'page', dataValue: p + 1 }));
    });
    if (totalPages > maxWidgetPages) {
        $container.append(template({ content: "...", dataName: 'disabled', dataValue: '1'}));
        $container.find("li:last").addClass("disabled");
    }
    _.each(_.range(Math.floor(Math.min(totalPages / 2, halfWidgetPages))).reverse(), function(p) {
        $container.append(template({ content: totalPages - p, dataName: 'page', dataValue: totalPages - p }));
    });
    $container.append(template({ content: "&raquo;", dataName: 'increment', dataValue: '1' }));
}

jQuery(document).ready(function() {
    $(document).on('click', '#item-pagination li:not(.disabled)', function() {
        var $item = $(this),
            $list = $item.closest(".pagination"),
            data = $item.data();
        if (data.page) {
            currentPage = data.page;
        } else if (data.increment) {
            currentPage = currentPage + parseInt(data.increment);
        }
        $list.find(".active").removeClass("active");
        $list.find(".disabled").removeClass("disabled");
        var $ellipsis = $list.find("[data-disabled='1']");
        $list.find("[data-page='" + currentPage + "']").addClass("active");
        if ($ellipsis.length) {
            $ellipsis.addClass("disabled");
            var text = $list.find(".active").length ? "..." : "... " + currentPage + " ...";
            $ellipsis.find("a").text(text);
        }
        if (currentPage == 1) {
            $list.find("li:first").addClass("disabled");
        }
        if (currentPage == Math.ceil(visibleSongs.length / songsPerPage)) {
            $list.find("li:last").addClass("disabled");
        }
        showPage();
    });
});

function closeLyricsModal() {
    var $modal = jQuery("#lyrics-detail");
    $modal.find(".modal-title").html("");
    $modal.find("textarea").val("");
    $modal.modal('hide');
}
