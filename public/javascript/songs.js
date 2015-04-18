// Globals
var oldValue = undefined;
var iconClasses = ['glyphicon-star', 'glyphicon-fire', 'glyphicon-heart'];

jQuery(document).ready(function() {
	var tokens = InitialPageData('tokens');
	var letters = InitialPageData('letters');
	var lettercounts = InitialPageData('lettercounts');
	updateRowCount();

	jQuery('#test-filter').keyup(function() {
		var query = jQuery(this).val();
		var rowselector = "#song-table-container tbody tr";

		if (!query) {
			jQuery(rowselector).show();
			updateRowCount();
			return;
		}

		var leastcommonletter = "";
		var leastcommoncount;
		for (var i = 0; i < query.length; i++) {
			if (!leastcommonletter || leastcommoncount > lettercounts[query[i]]) {
				leastcommonletter = query[i];
				leastcommoncount = lettercounts[leastcommonletter];
			}
		}

		var toshow = {};
		for (var i = 0; i < letters[leastcommonletter].length; i++) {
			var token = letters[leastcommonletter][i];
			if (token.indexOf(query) != -1) {
				for (var j = 0; j < tokens[token].length; j++) {
					toshow[tokens[token][j]] = 1;
				}
			}
		}

		jQuery(rowselector).hide();
		for (var songid in toshow) {
			jQuery("#song-" + songid).show();
		}

		updateRowCount();
	});

	jQuery("#helpers button").click(function() {
		var $button = jQuery(this);
		var buttonText = $button.text();
		var $form = jQuery("#complex-filter");
		var filter = "";
		var orderBy = $form.find('input[name="orderBy"]');
		switch ($button.closest(".group").data("category")) {
			case "random":
				$form.find('input[name="random"]').val(buttonText.replace(/random/i, '').trim());
				break;
			case "stars":
				filter = "rating = " + buttonText.replace(/stars/i, '');
				break;
			case "missing":
				filter = buttonText.replace(/missing/i, '') + " is null";
				break;
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

			// Update client
			// TODO: update index

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
	jQuery("#complex-filter input").click(function() {
		jQuery(this).closest("form").submit();
	});
	jQuery("#complex-filter .helpers-trigger").click(function() {
		jQuery("#helpers").modal();
	});
	jQuery("#complex-filter .clear-filter").click(function() {
		var $form = jQuery(this).closest("form");
		$form.find("textarea").val("");
		$form.submit();
	});

	// Export buttons
	jQuery(".export-button").click(function() {
		var options = {};
		options.OS = jQuery(this).data("os");
		var keys = ['name', 'artist', 'collections', 'tags'];
		var values = [];
		for (var i = 0; i < keys.length; i++) {
			var value = jQuery("#simple-filter-" + keys[i] + " input").val();
			if (value) {
				values.push(value);
				options[keys[i].toUpperCase()] = value;
			}
		}
		var complex = jQuery('#complex-filter textarea').val();
		if (complex) {
			options.FILTER = complex;
			values.push(complex);
		}
		values = jQuery.map(values, function(str) { return "[" + str + "]"; });
		options.FILENAME = values.join("");
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
	var className = "odd";
	jQuery("#song-table-container tbody tr").each(function() {
		var $row = jQuery(this);
		$row.removeClass("odd");
		$row.removeClass("even");
		$row.addClass(className);
		className = className === "even" ? "odd" : "even";
	});
}
