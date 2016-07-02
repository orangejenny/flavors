// Globals
var oldValue = undefined;
var iconClasses = ['glyphicon-star', 'glyphicon-fire', 'glyphicon-heart'];
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
	updateRowCount();

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

	jQuery(".playlists .glyphicon").click(function() {
		var $star = jQuery(this);
		toggleStar($star, $star.closest("li").data("id"), 'Flavors::Data::Playlist::Star');
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
	var selector = "td[contenteditable=true]";
	var columns = ['isstarred', 'name', 'artist', 'collections', 'rating', 'energy', 'mood', 'tags'];
	$table.on("focus", selector, function() {
		var $td = jQuery(this);
		if ($td.hasClass("rating")) {
			oldValue = $td.children(".glyphicon:not(.blank)").length;
			$td.html(StringMultiply("*", oldValue));
		}
		else {
			oldValue = $td.text().trim();
		}
	});
	$table.on("blur", selector, function() {
		var $td = jQuery(this);
		var value = $td.text().trim();
		if ($td.hasClass("rating")) {
			value = value.length;
			$td.html(ratingHTML(iconClasses[$td.closest("tr").find(".rating").index($td)], value));
		}
		if (oldValue != value) {
			var id = $td.closest("tr").data("song-id");
			var args = {
				id: id,
			}
			var index = jQuery("td", $td.closest("tr")).index($td);
			var key = columns[index];
			args[key] = value;

			// Update tokens and letters; don't bother with letter counts
			if (!$td.hasClass("rating")) {
				var oldTokens = oldTokens ? oldValue.split(/\s+/) : [];
				var newTokens = newTokens ? value.split(/\s+/) : [];
				var commonTokens = _.intersection(oldTokens, newTokens);
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

			// Update server
			$td.addClass("update-in-progress");
			CallRemote({
				SUB: 'Flavors::Data::Song::Update', 
				ARGS: args, 
				FINISH: function(data) {
					$td.removeClass("update-in-progress");
				}
			});
		}
		oldValue = undefined;
	});
	$table.on("click", ".is-starred .glyphicon", function() {
		var $star = jQuery(this);
		toggleStar($star, $star.closest("tr").data("song-id"), 'Flavors::Data::Song::Update');
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
                var $modal = jQuery("#lyrics-detail");
                $modal.data("song-id", id);
                $modal.find("textarea").val(data.LYRICS);
                $modal.find(".modal-title").html(name + " (" + artist + ")");
                $modal.modal();
    		}
    	});
    });

    jQuery("#lyrics-detail .btn-primary").on("click", function() {
        var $modal = jQuery("#lyrics-detail");
        CallRemote({
            SUB: 'Flavors::Data::Song::UpdateLyrics',
            ARGS: {
                ID: $modal.data("song-id"),
                LYRICS: $modal.find("textarea").val(),
            },
            FINISH: function() {
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

function ratingHTML(iconClass, number) {
	return StringMultiply("<span class='glyphicon " + (number ? "" : "blank ") + iconClass + "'></span>", number || 5);
}

function toggleStar($star, id, sub) {
	var isstarred = !$star.hasClass("glyphicon-star");

	// Update markup
	$star.toggleClass("glyphicon-star-empty");
	$star.toggleClass("glyphicon-star");

    // Update client data
    starred[id] = isstarred;

	// Update server data
	$star.addClass("update-in-progress");
	CallRemote({
		SUB: sub,
		ARGS: {
			ID: id,
			ISSTARRED: isstarred ? 1 : 0,
        },
	    FINISH: function(data) {
			$star.removeClass("update-in-progress");
		}
	});
}

function updateRowCount() {
	jQuery("#song-count").text(jQuery("#song-table-container tbody tr:visible").length);
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
    			jQuery("#song-" + songID).show();
            });
        }
        else {
            jQuery(rowselector).show();
        }
	    updateRowCount();
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

	updateRowCount();
}

function closeLyricsModal() {
    var $modal = jQuery("#lyrics-detail");
    $modal.find(".modal-title").html("");
    $modal.find("textarea").val("");
    $modal.modal('hide');
}
