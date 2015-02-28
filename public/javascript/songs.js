// Globals
var selectedRow = undefined;
var oldValue = undefined;
var iconClasses = ['glyphicon-star', 'glyphicon-fire', 'glyphicon-heart'];
var dashboard, data, dataview, table = undefined;
var filters = ['Name', 'Artist', 'Collections', 'Tags'];

// Table initialization
google.load('visualization', '1', {packages: ['table', 'controls']});
google.setOnLoadCallback(drawTable);

jQuery(document).ready(function() {
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

	// Song details when hovering on names
	jQuery(".song-name").popover({
		html: true,
		placement: "right",
		trigger: "hover"
	});

	// Press enter to filter
	jQuery("textarea[name=filter]").keydown(function(evt) {
		if (evt.keyCode == 13) {
			jQuery(this).closest("form").submit();
		}
	});

	// Click to edit
	var $table = jQuery("#song-table-container");
	var selector = "td[contenteditable=true]";
	$table.on("focus", selector, function() {
		var $td = jQuery(this);
		selectedRow = table.getChart().getSelection();
		if (selectedRow && selectedRow.length) {
			selectedRow = selectedRow[0].row;
		}
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
		if (oldValue != value && selectedRow !== undefined) {
			var id = $td.closest("tr").find("td:first").text();
			var args = {
				id: id,
			}
			var index = jQuery("td", $td.closest("tr")).index($td);
			var key = jQuery("#song-table-container tr:first :nth-child(" + (index + 1) + ")").text().trim().toLowerCase();
			args[key] = value;
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
		selectedRow = undefined;
	});
	$table.on("click", ".isstarred .glyphicon", function() {
		var $star = jQuery(this);
		$star.toggleClass("glyphicon-star-empty");
		$star.toggleClass("glyphicon-star");
		var id = $star.closest("tr").find("td:first").text();
		var isstarred = $star.hasClass("glyphicon-star");
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

function drawTable() {
	var columns = [
		{ type: 'number', label: 'ID' },
		{ type: 'string', label: '' },
		{ type: 'string', label: 'Name'},
		{ type: 'string', label: 'Artist'},
		{ type: 'string', label: 'Collections'},
		{ type: 'string', label: 'Rating'},
		{ type: 'string', label: 'Energy'},
		{ type: 'string', label: 'Mood'},
		{ type: 'string', label: 'Tags'}
	];
	var rows = InitialPageData('rows');
	if (!rows) {
		return;
	}
	data = new google.visualization.DataTable({
		cols: columns,
		rows: rows,
	});
	for (var i = 0; i < rows.length; i++) {
		var starClass = data.getValue(i, 1) == 1 ? "glyphicon-star" : "glyphicon-star-empty";
		data.setValue(i, 1, "<span class='glyphicon " + starClass + "'></span>");	// TODO
		for (var j = 0; j < 3; j++) {
			data.setValue(i, j + 5, ratingHTML(iconClasses[j], (data.getValue(i, j + 5) || "").trim().length));
		}
	}

	for (var index in filters) {
		var column = filters[index];
		filters[index] = new google.visualization.ControlWrapper({
			'controlType': 'StringFilter',
			'containerId': 'simple-filter-' + column.toLowerCase(),
			'options': {
				filterColumnLabel: column,
				matchType: 'any',
				ui: {
					label: ''
				}
			}
		});
	}

	for (var i = 0; i < rows.length; i++) {
		data.setProperty(i, 1, 'className', 'google-visualization-table-td isstarred');
		data.setProperty(i, 2, 'className', 'google-visualization-table-td name');
		for (var j = 5; j < 8; j++) {
			data.setProperty(i, j, 'className', 'google-visualization-table-td rating');
		}
	}

	dataview = new google.visualization.DataView(data);
	var i = 0;
	var viewcolumns = jQuery.map(columns, function() { return i++; });
	dataview.setColumns(viewcolumns);

	table = new google.visualization.ChartWrapper({
		chartType: 'Table',
		containerId: 'song-table-container', 
		options: {
			cssClassNames: {
				selectedTableRow: 'dummy'
			},
			allowHtml: true,
		}
	});

	dashboard = new google.visualization.Dashboard(document.getElementById('dashboard'));
	for (var i = 0; i < filters.length - 1; i++) {
		dashboard.bind(filters[i], filters[i+1]);
	}
	dashboard.bind(filters[filters.length - 1], table).draw(dataview);

	google.visualization.events.addListener(table, 'ready', function() {
		jQuery("#song-count").text(parseInt(jQuery("#song-table-container tr:visible").length, 10));
		google.visualization.events.addListener(table.getChart(), 'sort', function() {
			refreshTable();
		});
		refreshTable();
	});
}

function ratingHTML(iconClass, number) {
	if (number) {
		return StringMultiply("<span class='glyphicon " + iconClass + "'></span>", number);
	}
	return StringMultiply("<span class='glyphicon blank " + iconClass + "'></span>", 5);
}

function refreshTable() {
	var $table = jQuery("#song-table-container");
	$table.find("tr:not(:first)").find("td.rating, td:last-child").attr("contenteditable", "true");

	var tableWidth = $table.width();
	var $cells = $table.find("tr:visible:first td");
	var cellWidths = [undefined, .02, .15, .15, .15, .05, .05, .05, .38];
	for (var i = 1; i < cellWidths.length; i++) {
		jQuery($cells[i]).css("width", Math.round(cellWidths[i] * tableWidth) + "px");
	}

	// Align filter input positions and widths with columns. Terrible.
	var $filters = jQuery('#simple-filters');
	var placeholders = ["name", "artist", "collections", "tags"];
	var cells = {};
	$table.find("tr:first td, tr:first th").each(function(i) {
		cells[jQuery(this).text().trim().toLowerCase()] = i + 1;
	});
	var $firstRow = $table.find("tr:visible:first");
	var $previousInput;
	if ($table.find("tr:visible").length) {
		$filters.find("input").each(function() {
			var placeholder = placeholders.shift();
			var $input = jQuery(this);
			var $cell = $firstRow.find("td:nth-child(" + cells[placeholder] + ")");
			$input.width($cell.width() - parseInt($input.css("margin-left")) - parseInt($input.css("margin-right")));
			var cellLeft = $cell.offset().left;
			var previousInputRight = $previousInput ? $previousInput.offset().left + $previousInput.outerWidth() : $filters.offset().left;
			$input.css("margin-left", cellLeft - previousInputRight);
			$input.get(0).placeholder = placeholder;
			$previousInput = $input;
		});
	}
}
