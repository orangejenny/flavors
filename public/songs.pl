#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsUtils;
use FlavorsData;
use JSON qw(to_json);

my $dbh = FlavorsData::DBH();
my $fdat = FlavorsUtils::Fdat();

my $cgi = CGI->new;
print $cgi->header();

FlavorsHTML::Header({
	TITLE => "Songs",
});

if ($fdat->{RANDOM}) {
	my $column = $fdat->{RANDOM};
	my $item = FlavorsData::RandomItem($dbh, $column);
	$item = FlavorsUtils::EscapeSQL($item);
	if ($column =~ m/collection/i) {
		$fdat->{FILTER} = sprintf("collectionlist like '%%%s%%'", $item);
	}
	elsif ($column =~ m/tag/i) {
		$fdat->{FILTER} = sprintf("taglist like '%%%s%%'", $item);
	}
	else {
		$fdat->{FILTER} = sprintf("%s = '%s'", $column, $item);
	}
	$fdat->{PLACEHOLDER} = "";
}

print q{
	<div id="helpers" class="modal">
		<div class="modal-dialog">
			<div class="modal-content">
				<div class="modal-header">
					<h4>Songs</h4>
				</div>
				<div class="modal-body">
					<div class="group" data-category="random">
						<button class="btn btn-default">Random collection</button>
						<button class="btn btn-default">Random artist</button>
						<button class="btn btn-default">Random tag</button>
					</div>
					<div class="group" data-category="stars">
						<button class="btn btn-default">5 stars</button>
						<button class="btn btn-default">4 stars</button>
						<button class="btn btn-default">3 stars</button>
					</div>
					<div class="group" data-category="missing">
						<button class="btn btn-default">Missing rating</button>
						<button class="btn btn-default">Missing mood</button>
						<button class="btn btn-default">Missing energy</button>
					</div>
					<div class="group" data-category="popular">
						<button class="btn btn-default">Recently added</button>
						<button class="btn btn-default">Recently exported</button>
						<button class="btn btn-default">Frequently exported</button>
					</div>
					<div class="group" data-category="unpopular">
						<button class="btn btn-default">Rarely exported</button>
						<button class="btn btn-default btn-primary">All songs</button>
						<button class="btn btn-default">Exported long ago</button>
					</div>
				</div>
			</div>
		</div>
	</div>
	<script type="application/javascript">
		jQuery(document).ready(function() {
			jQuery("#helpers button").click(function() {
				var $button = jQuery(this);
				var buttonText = $button.text();
				var $form = jQuery("#complexfilter");
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
		});
	</script>
};

print sprintf(qq{
		<div class="complex-filter-container">
			<form method=POST id="complexfilter">
				<textarea name=filter rows=3 style="width: 400px;" placeholder="%s">%s</textarea>
				<span class="glyphicon glyphicon-remove clear-filter" style="position: absolute; cursor: pointer;" title="Clear filter"></span>
				<span class="glyphicon glyphicon-question-sign hint" style="position: absolute; top: 20px;" title="%s"></span>
				<span class="glyphicon glyphicon-heart helpers-trigger" style="position: absolute; top: 40px; cursor: pointer;" title="Common filters"></span>
				<br>
				<input type="button" value="Filter" class="btn btn-default btn-lg" style="width: 400px;" />
				<input type="hidden" name="random" value="" />
				<input type="hidden" name="orderBy" value="" />
				<input type="hidden" name="placeholder" value="" />
			</form>
		</div>
	},
	$fdat->{PLACEHOLDER},
	$fdat->{FILTER},
	q{
		id, name, artist,
		<br>rating, energy, mood,
		<br>time, filename,
		<br>ismix, dateacquired,
		<br>taglist, tagcount, collectionlist,
		<br>minyear, maxyear
	},
);


if (!exists $fdat->{FILTER}) {
	print qq{
		<script type="application/javascript">
			jQuery(document).ready(function() {
				jQuery("#helpers").modal({
					backdrop: "static",
					keyboard: false,
				});
			});
		</script>
	};
	print FlavorsHTML::Footer();
	exit;
}

my @songs = FlavorsData::SongList($dbh, {
	FILTER => $fdat->{FILTER},
	ORDERBY => $fdat->{ORDERBY},
});

print sprintf(q{
	<script type='text/javascript' src='https://www.google.com/jsapi'></script>
	<script type="application/javascript">
		// Globals
		var selectedrow = undefined;
		var oldvalue = undefined;
		var dashboard, data, dataview, table = undefined;
		var filters = ['Name', 'Artist', 'Tags'];

		function correlateFilter(rowIndex) {
			var newRowIndex = rowIndex;
			for (var i = filters.length - 1; i >= 0; i--) {
				newRowIndex = filters[i].getControl().applyFilter().getTableRowIndex(newRowIndex);
			}
			return newRowIndex;
      }

		// Column names hint for filter
		jQuery(document).ready(function() {
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
			var $table = jQuery("#songdata");
			var selector = "td[contenteditable=true]";
			$table.on("focus", selector, function() {
				oldvalue = trim(jQuery(this).text());
				selectedrow = table.getChart().getSelection();
				if (selectedrow && selectedrow.length) {
					selectedrow = selectedrow[0].row;
				}
			});
			$table.on("blur", selector, function() {
				var $td = jQuery(this);
				var value = trim($td.text());
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
					var key = trim(jQuery("#songdata tr:first :nth-child(" + (index + 1) + ")").text()).toLowerCase();
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
			jQuery("#complexfilter input").click(function() {
				jQuery(this).closest("form").submit();
			});
			jQuery("#complexfilter .helpers-trigger").click(function() {
				jQuery("#helpers").modal();
			});
			jQuery("#complex-filter .clear-filter").click(function() {
				var $form = jQuery(this).closest("form");
				$form.find("textarea").val("");
				$form.submit();
			});

			// Export buttons
			jQuery(".export-button").click(function() {
				var options = BuildArgs('#complexfilter', options);
				options.NAME = jQuery("#simple-filter-name input").val();
				options.ARTIST = jQuery("#simple-filter-artist input").val();
				options.TAGS = jQuery("#simple-filter-tags input").val();
				options.OS = jQuery(this).data("os");
				ExportPlaylist(options);
			});
		});

		function trim(text) {
			text = text.replace(/^\s+/, "");
			text = text.replace(/\s+$/, "");
			return text;
		}

		google.load('visualization', '1', {packages: ['table', 'controls']});
		google.setOnLoadCallback(drawTable);

		function drawTable() {
			var columns = [
				{ type: 'number', label: 'ID' },
				{ type: 'string', label: 'Name'},
				{ type: 'string', label: 'Artist'},
				{ type: 'string', label: 'Rating'},
				{ type: 'string', label: 'Energy'},
				{ type: 'string', label: 'Mood'},
				{ type: 'string', label: 'Tags'}
			];
			var rows = [%s];
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
				data.setProperty(i, 3, 'className', 'google-visualization-table-td rating');
				data.setProperty(i, 4, 'className', 'google-visualization-table-td rating');
				data.setProperty(i, 5, 'className', 'google-visualization-table-td rating');
			}

			dataview = new google.visualization.DataView(data);
			var viewcolumns = [];
			for (var i = 1; i < columns.length; i++) {
				viewcolumns.push(i);
			}
			dataview.setColumns(viewcolumns);

			table = new google.visualization.ChartWrapper({
				chartType: 'Table',
				containerId: 'songdata', 
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
				jQuery("#song-count").text(parseInt(jQuery("#songdata tr:visible").length, 10) - 1);
				google.visualization.events.addListener(table.getChart(), 'sort', function() {
					refreshTable();
				});
				refreshTable();
			});
		}

		function refreshTable() {
			var $table = jQuery("#songdata");
			var $cells = $table.find("tr:not(:first) td");
			$cells.attr("contenteditable", "true");
			var $headercells = $table.find("tr:first td");
			jQuery($headercells[0]).css("width", "20%");
			jQuery($headercells[1]).css("width", "20%");
			jQuery($headercells[2]).css("width", "5%");
			jQuery($headercells[3]).css("width", "5%");
			jQuery($headercells[4]).css("width", "5%");
			jQuery($headercells[5]).css("width", "45%");

			var $filters = jQuery('#simple-filters');
			var placeholders = ["name", "artist", "tags"];
			$filters.find("input").each(function() {
				jQuery(this).get(0).placeholder = placeholders.shift();
			});
		}
	</script>
},
join(", ", map {
	sprintf(
		"{ c: [{v: %s}, {v: '%s'}, {v: '%s'}, {v: '%s'}, {v: '%s'}, {v: '%s'}, {v: '%s'}] }",
		$_->{ID},
		FlavorsUtils::EscapeJS($_->{NAME}),
		FlavorsUtils::EscapeJS($_->{ARTIST}),
		FlavorsHTML::Rating($_->{RATING}),
		FlavorsHTML::Rating($_->{ENERGY}),
		FlavorsHTML::Rating($_->{MOOD}),
		FlavorsUtils::EscapeJS($_->{TAGS}),
	)
} @songs));

print qq{ <div id="dashboard"> };

print qq{
	<div id="simple-filters" class="clearfix">
		<div id="simple-filter-name" style="width: 20%; float: left;"></div>
		<div id="simple-filter-artist" style="width: 20%; float: left;"></div>
		<div id="simple-filter-tags" style="width: 45%; float: left; margin-left: 15%;"></div>
	</div>
};

print qq{ <div id="top-veil"></div> };
print qq{ <div id="songdata"></div> };
print qq{ </div> };

print "</tbody></table>";

print qq{
	<div id="song-count-container">
		<div id="bottom-veil"></div>
		<span id="song-count-span" class="ui-corner-all">
			<span id="song-count"></span> songs
		</span>
	</div>
};

print FlavorsHTML::Footer();
