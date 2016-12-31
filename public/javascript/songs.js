// Globals
var lastQuery = "";
var tokens;
var letters;
var letterCounts;
var starred;

jQuery(document).ready(function() {
    tokens = InitialPageData('tokens');
    letters = InitialPageData('letters');
    letterCounts = InitialPageData('lettercounts');
    starred = InitialPageData('starred');
	updateItemCount();

    simpleFilter();
	jQuery('#filter').on("keyup blur", _.throttle(function(event) {
        simpleFilter(event && event.keyCode === 13);
    }, 100, { leading: false }));
    jQuery("#simple-filter .glyphicon-remove").click(function() {
        jQuery("#filter").val("");
        simpleFilter(true);
    });
    jQuery("#simple-filter .glyphicon-star-empty, #simple-filter .glyphicon-star").click(function() {
        $(this).toggleClass("glyphicon-star-empty").toggleClass("glyphicon-star");
        simpleFilter(true);
    });

	jQuery(".playlists a").click(function() {
		var $link = jQuery(this);
		var $form = jQuery("#complex-filter form");
		$form.find("textarea").val($link.text());
		$form.submit();
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
			backgroundColor = colors.hex;
			if (parseInt(colors.whitetext)) {
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
	var selector = "[contenteditable=true][data-key]";
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

function updateItemCount() {
	jQuery("#item-count").text(jQuery("#song-table-container tbody tr:visible").length);
}

function simpleFilter(force) {
	var query = jQuery("#filter").val();
	var rowselector = "#song-table-container tbody tr";

    if (!force && (query === lastQuery || query.length < 4)) {
        return;
    }

	lastQuery = query;
    jQuery("#last-query-text").text(lastQuery);
    if (lastQuery) {
        jQuery("#simple-filter .glyphicon-remove").removeClass("hide");
    } else {
        jQuery("#simple-filter .glyphicon-remove").addClass("hide");
    }

    var queryTokens = _.without(query.split(/\s+/), "");
    var onlyStarred = !jQuery("#simple-filter .glyphicon-star-empty").length;

    // If there's no text in the filter; just check the star filter
    if (!queryTokens.length) {
        if (onlyStarred) {
            jQuery(rowselector).hide();
            _.each(_.keys(starred), function(songID) {
                if (starred[songID]) {
    			    jQuery("#song-" + songID).show();
                }
            });
        }
        else {
            jQuery(rowselector).show();
        }
	    updateItemCount();
        return;
    }

	var matches = {};	// song id => { queryToken1 => 1, queryToken2 => 1, ... }
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

	jQuery(rowselector).hide();
	_.each(matches, function(matchTriggers, songID) {
		if (_.values(matchTriggers).length === queryTokens.length && (!onlyStarred || starred[songID])) {
			jQuery("#song-" + songID).show();
		}
	});

	updateItemCount();
}

function closeLyricsModal() {
    var $modal = jQuery("#lyrics-detail");
    $modal.find(".modal-title").html("");
    $modal.find("textarea").val("");
    $modal.modal('hide');
}
