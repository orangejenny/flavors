// Globals
var selectedrow = undefined;
var oldvalue = undefined;
var dashboard, data, dataview, table = undefined;
var filters = ['Name', 'Artist', 'Collections', 'Tags'];

// Table initialization
google.load('visualization', '1', {packages: ['table', 'controls']});
google.setOnLoadCallback(drawTable);

function correlateFilter(rowIndex) {
	var newRowIndex = rowIndex;
	for (var i = filters.length - 1; i >= 0; i--) {
		newRowIndex = filters[i].getControl().applyFilter().getTableRowIndex(newRowIndex);
	}
	return newRowIndex;
}

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

	if (!InitialPageData('reload')) {
		jQuery("#helpers").modal({
			backdrop: "static",
			keyboard: false,
		}).find(".btn-info").focus();
		return;
	}

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
		oldvalue = jQuery(this).text().trim();
		selectedrow = table.getChart().getSelection();
		if (selectedrow && selectedrow.length) {
			selectedrow = selectedrow[0].row;
		}
	});
	$table.on("blur", selector, function() {
		var $td = jQuery(this);
		var value = $td.text().trim();
		if (oldvalue != value && selectedrow !== undefined) {
			var datarow;
			while (!datarow) {
				try {
					datarow = correlateFilter(selectedrow);
				}
				catch (error) {
					if (!confirm("Failed to find row. Retry?")) {
						$td.text(oldvalue);
						$td.focus();
						return;
					}
				}
			}
			var args = {
				id: data.getValue(datarow, 0),
			}
			var index = jQuery("td", $td.closest("tr")).index($td);
			var key = jQuery("#song-table-container tr:first :nth-child(" + (index + 1) + ")").text().trim().toLowerCase();
			if ($td.hasClass("rating")) {
				value = value.length;
			}
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
		oldvalue = undefined;
		selectedrow = undefined;
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
		var options = BuildArgs('#complex-filter', options);
		options.NAME = jQuery("#simple-filter-name input").val();
		options.ARTIST = jQuery("#simple-filter-artist input").val();
		options.COLLECTIONS = jQuery("#simple-filter-collections input").val();
		options.TAGS = jQuery("#simple-filter-tags input").val();
		options.OS = jQuery(this).data("os");
		ExportPlaylist(options);
	});
});

function drawTable() {
	var columns = [
		{ type: 'number', label: 'ID' },
		{ type: 'string', label: 'Name'},
		{ type: 'string', label: 'Artist'},
		{ type: 'string', label: 'Collections'},
		{ type: 'string', label: 'Rating'},
		{ type: 'string', label: 'Energy'},
		{ type: 'string', label: 'Mood'},
		{ type: 'string', label: 'Tags'}
	];
	var rows = InitialPageData('rows');
	data = new google.visualization.DataTable({
		cols: columns,
		rows: rows,
	});

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
		data.setProperty(i, 4, 'className', 'google-visualization-table-td rating');
		data.setProperty(i, 5, 'className', 'google-visualization-table-td rating');
		data.setProperty(i, 6, 'className', 'google-visualization-table-td rating');
	}

	dataview = new google.visualization.DataView(data);
	var viewcolumns = [];
	for (var i = 1; i < columns.length; i++) {
		viewcolumns.push(i);
	}
	dataview.setColumns(viewcolumns);

	table = new google.visualization.ChartWrapper({
		chartType: 'Table',
		containerId: 'song-table-container', 
		options: {
			cssClassNames: {
				selectedTableRow: 'dummy'
			}
		}
	});

	dashboard = new google.visualization.Dashboard(document.getElementById('dashboard'));
	for (var i = 0; i < filters.length - 1; i++) {
		dashboard.bind(filters[i], filters[i+1]);
	}
	dashboard.bind(filters[filters.length - 1], table).draw(dataview);

	google.visualization.events.addListener(table, 'ready', function() {
		jQuery("#song-count").text(parseInt(jQuery("#song-table-container tr:visible").length, 10) - 1);
		google.visualization.events.addListener(table.getChart(), 'sort', function() {
			refreshTable();
		});
		refreshTable();
	});
}

function refreshTable() {
	var $table = jQuery("#song-table-container");
	var $cells = $table.find("tr:not(:first)").find("td.rating, td:last-child");
	$cells.attr("contenteditable", "true");

	var $headercells = $table.find("tr:first td");
	jQuery($headercells[0]).css("width", "15%");
	jQuery($headercells[1]).css("width", "15%");
	jQuery($headercells[2]).css("width", "15%");
	jQuery($headercells[3]).css("width", "5%");
	jQuery($headercells[4]).css("width", "5%");
	jQuery($headercells[5]).css("width", "5%");
	jQuery($headercells[6]).css("width", "40%");

	var $filters = jQuery('#simple-filters');
	var placeholders = ["name", "artist", "collections", "tags"];
	$filters.find("input").each(function() {
		jQuery(this).get(0).placeholder = placeholders.shift();
	});
}
