// Globals
var oldValue = undefined;
var iconClasses = ['glyphicon-star', 'glyphicon-fire', 'glyphicon-heart'];

jQuery(document).ready(function() {
	var tokens = InitialPageData('tokens');
	var letters = InitialPageData('letters');
	var letterCounts = InitialPageData('lettercounts');
	updateRowCount();

	jQuery('#filter').keyup(_.debounce(function() {
		var query = jQuery(this).val();
		var rowselector = "#song-table-container tbody tr";

		var queryTokens = _.without(query.split(/\s+/), "");
		if (!queryTokens.length) {
			jQuery(rowselector).show();
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
			if (_.values(matchTriggers).length === queryTokens.length) {
				jQuery("#song-" + songID).show();
			}
		});

		updateRowCount();
	}, 100));

	jQuery("#complex-filter button").click(function() {
		var $button = jQuery(this);
		var buttonText = $button.text();
		var $form = jQuery("#complex-filter form");
		var filter = "";
		var orderBy = $form.find('input[name="orderBy"]');
		switch ($button.closest(".group").data("category")) {
			case "popular":
				if (buttonText.match(/frequent/i)) {
					orderBy.val("exportcount desc");
				}
				else if (buttonText.match(/export/i)) {
					orderBy.val("lastexport desc");
				}
				else if (buttonText.match(/add/i)) {
					orderBy.val("dateacquired desc");
				}
				break;
			case "unpopular":
				if (buttonText.match(/rare/i)) {
					orderBy.val("exportcount");
				}
				else if (buttonText.match(/ago/i)) {
					orderBy.val("lastexport");
				}
				break;
		}
		if (!filter) {
			$form.find('input[name="placeholder"]').val("(" + buttonText.toLowerCase() + ")");
		}
		$form.find("textarea").val(filter);
		$form.submit();
	});

	// Column names hint for filter
	jQuery(".hint").tooltip({
		html: true,
		placement: "right"
	});

	var $table = jQuery("#song-table-container");

	// Highlight on hover
	// TODO: Lighten the hover colors and/or make them background colors
	$table.on("mouseover", "tr", function() {
		var $row = jQuery(this);
		var color = "fafafa";
		var colordata = $row.data("colors");
		if (colordata) {
			var colors = colordata.split(/\s+/);
			color = colors[Math.floor(Math.random() * colors.length)];
		}
		jQuery(this).css("background-color", color);
	});
	$table.on("mouseout", "tr", function() {
		jQuery(this).css("background-color", "");
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
				var oldTokens = oldValue.split(/\s+/);
				var newTokens = value.split(/\s+/);
				var commonTokens = _.intersection(oldTokens, newTokens);
				oldTokens = _.difference(oldTokens, commonTokens);
				newTokens = _.difference(newTokens, commonTokens);

				// update letter counts; don't bother deduping
				_.each(newTokens, function(token) {
					letters[token.substring(0, 1)].push(token);
				});

				// update token index
				_.each(newTokens, function(token) {
					tokens[token].push(id);
				});
				_.each(oldTokens, function(token) {
					tokens[token] = _.without(tokens[token], "" + id);
				});
			}

			// Update server
			$td.addClass("update-in-progress");
			CallRemote({
				SUB: 'FlavorsData::UpdateSong', 
				ARGS: args, 
				FINISH: function(data) {
					$td.removeClass("update-in-progress");
				}
			});
		}
		oldValue = undefined;
	});
	$table.on("click", ".isstarred .glyphicon", function() {
		var $star = jQuery(this);
		var id = $star.closest("tr").data("song-id");
		var isstarred = !$star.hasClass("glyphicon-star");

		// Update markup
		$star.toggleClass("glyphicon-star-empty");
		$star.toggleClass("glyphicon-star");

		// Update server data
		$star.addClass("update-in-progress");
		CallRemote({
			SUB: 'FlavorsData::UpdateSong', 
			ARGS: {
				ID: id,
				ISSTARRED: isstarred ? 1 : 0,
				FINISH: function(data) {
					$star.removeClass("update-in-progress");
				}
			}
		});
	});

	// Complex filter controls
	jQuery("#complex-filter form input").click(function() {
		jQuery(this).closest("form").submit();
	});
	jQuery("#complex-filter-trigger").click(function() {
		jQuery("#complex-filter").modal().find("textarea").focus();
	});

	// Export buttons
	jQuery(".export-button").click(function() {
		var options = {};
		options.OS = jQuery(this).data("os");
		options.SIMPLEFILTER = jQuery("#filter").val();
		options.FILTER = jQuery('#complex-filter textarea').val();
		options.FILENAME = options.SIMPLEFILTER || options.FILTER;
		ExportPlaylist(options);
	});
});

function ratingHTML(iconClass, number) {
	if (number) {
		return StringMultiply("<span class='glyphicon " + iconClass + "'></span>", number);
	}
	return StringMultiply("<span class='glyphicon blank " + iconClass + "'></span>", 5);
}

function starHTML(isstarred) {
	return "<span class='glyphicon glyphicon-star" + (isstarred ? "" : "-empty") + "'></span>"
}

function updateRowCount() {
	jQuery("#song-count").text(jQuery("#song-table-container tbody tr:visible").length);
}
