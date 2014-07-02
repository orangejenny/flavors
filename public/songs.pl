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

my @playlists = FlavorsData::PlaylistList($dbh);
my $playlist;
if (!exists $fdat->{FILTER}) {
	$playlist = $playlists[int(rand(scalar(@playlists)))];
	$fdat->{FILTER} = $playlist->{FILTER};
}

my @songs = FlavorsData::SongList($dbh, {
	FILTER => $fdat->{FILTER},
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

			// Complex filter buttons
			jQuery("#complexfilter input").click(function() {
				var $button = jQuery(this);
				var $form = $button.closest("form");
				if ($button.val().toLowerCase() === "clear") {
					$form.find("textarea").val("");
				}
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
			var placeholders = ["tags", "name", "artist"];
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

print sprintf(qq{
	<div id="dashboard">

		<div style="text-align: center;">
			<form method=POST id="complexfilter">
				<textarea name=filter rows=3 style="width: 410px;">%s</textarea>
				<i class="icon icon-question-sign hint" style="position: absolute;" title="%s"></i>
				<br>
				<input type="button" value="Filter" class="btn btn-large" style="width: 300px;" />
				<input type="button" value="Clear" class="btn btn-large" style="width: 100px; margin-left: 10px;" />
			</form>
		</div>
	},
	$fdat->{FILTER},
	q{
		id, name, artist,
		<br>rating, energy, mood,
		<br>time, filename,
		<br>ismix, dateacquired,
		<br>taglist, tagcount, searchtext,
		<br>minyear, maxyear
	},
);

print qq{
	<div id="simple-filters" style="width: 100%;" class="clearfix">
		<div id="simple-filter-tags" style="width: 45%; float: right;"></div>
		<div id="simple-filter-name" style="width: 20%; float: left;"></div>
		<div id="simple-filter-artist" style="width: 20%; float: left;"></div>
	</div>
};

print qq{ <div id="songdata"></div> };
print qq{ </div> };

print "</tbody></table>";

print qq{ <div id="song-count-container"><span id="song-count"></span> songs</div> };

print FlavorsHTML::Footer();
