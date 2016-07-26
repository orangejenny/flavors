jQuery(document).ready(function() {
	// Controls: clear anything selected
	jQuery(".clear-button").click(function() {
		d3.selectAll(".selected").classed("selected", false);
		setClearVisibility();
	});

	// Controls: open selection in songs.pl
	jQuery(".songs-button").click(function() {
		var condition = getSelectionCondition();
		if (condition) {
            var $modal = jQuery("#song-list"),
                $body = $modal.find(".modal-body");
            $body.html(jQuery("body .loading").clone().show());
            $modal.modal();
    		CallRemote({
    			SUB: 'Flavors::Data::Song::List', 
    			ARGS: {
                    FILTER: condition,
                },
    			FINISH: function(songs) {
                    var songTemplate = _.template("<tr data-song-id='<%= ID %>'>"
                                                    + "<td class='icon-cell is-starred'><%= ISSTARREDHTML %></td>"
                                                    + "<td><%= NAME %></td>"
                                                    + "<td><%= ARTIST %></td>"
                                                    + "<td class='rating' contenteditable='true' data-key='rating'><%= RATINGHTML %></td>"
                                                    + "<td class='rating' contenteditable='true' data-key='energy'><%= ENERGYHTML %></td>"
                                                    + "<td class='rating' contenteditable='true' data-key='mood'><%= MOODHTML %></td>"
                                                    + "<td contenteditable='true' data-key='tags'><%= TAGS %></td>"
                                                    + "</tr>"),
                        $table = $("<table class='song-table'></table>");
                    _.each(songs, function(song) {
                        $table.append(songTemplate(_.extend(song, {
                            ISSTARREDHTML: ratingHTML(parseInt(song.ISSTARRED) ? 'glyphicon-star' : 'glyphicon-star-empty', 1),
                            RATINGHTML: ratingHTML(iconClasses['rating'], song.RATING),
                            ENERGYHTML: ratingHTML(iconClasses['energy'], song.ENERGY),
                            MOODHTML: ratingHTML(iconClasses['mood'], song.MOOD),
                        })));
                    });
                    $body.html($table);
    			}
    		});
		}
	});

	// Controls: export selections
	jQuery(".export-dropdown a").click(function() {
		var condition = getSelectionCondition();
		console.log(condition);
		if (condition) {
			ExportPlaylist({
		        PATH: jQuery(this).text(),
				FILTER: condition,
			});
			d3.selectAll('.selected').classed("selected", false);
			setClearVisibility();
		}
	});
});

function setClearVisibility() {
	if (jQuery(".selected").length) {
		jQuery(".selection-buttons").removeClass("hide");
	}
	else {
		jQuery(".selection-buttons").addClass("hide");
	}
}

function attachTooltip(selector) {
	var positionTooltip = function() {
		var $tooltip = jQuery("#tooltip");
		if (!$tooltip.is(":visible")) {
			return;
		}
		if (d3.event.pageX + 10 + $tooltip.width() > jQuery("body").width()) {
			$tooltip.css("left", d3.event.pageX - $tooltip.width() - 10);
		}
		else {
			$tooltip.css("left", d3.event.pageX + 10);
		}
		if (d3.event.pageY + $tooltip.height() > jQuery("body").height() - jQuery(".post-nav").scrollTop()) {
			$tooltip.css("top", d3.event.pageY - $tooltip.height());
		}
		else {
			$tooltip.css("top", d3.event.pageY);
		}
	};

	d3.selectAll(selector).on("mouseenter.tooltip", function() {
		var data = d3.select(this).data()[0];
		var $tooltip = jQuery("#tooltip");
		var show = false;

		var $title = $tooltip.children("div");
		$title.html("");
		if (data.description) {
			show = true;
			var description = data.description;
			$title.html(description);
			$title.removeClass("hide");
		}
		else {
			$title.addClass("hide");
		}

		var $list = $tooltip.find("ul");
		$list.html("");
		if (data.samples) {
			show = true;
			var displayMax = 5;
			$list.html(_.map(_.sample(data.samples, displayMax), function(s) { return "<li>" + s + "</li>"; }).join(""));
			if (data.samples.length > displayMax) {
				$list.append("<li>...</li>");
			}
			$list.removeClass("hide");
		}
		else {
			$list.addClass("hide");
		}

		if (show) {
			$tooltip.removeClass("hide");
			positionTooltip();
		}
	});
	d3.selectAll(selector).on("mouseleave.tooltip", function() {
		jQuery("#tooltip").addClass("hide");
	});
	d3.selectAll(selector).on("mousemove.tooltip", function() {
		positionTooltip();
	});
}

function attachSelectionHandlers(selector, actsOn) {
	if (!actsOn) {
		actsOn = function(obj) {
			return d3.select(obj);
		};
	}

	highlightOnHover(selector, actsOn);
	selectOnClick(selector, actsOn);
	exportOnDoubleClick(selector, actsOn);
}

function highlightOnHover(selector, actsOn) {
	d3.selectAll(selector).on("mouseenter.highlight", function() {
		actsOn(this).classed("highlighted", true);
		actsOn(this).selectAll("rect, circle").classed("highlighted", true);
	});
	d3.selectAll(selector).on("mouseleave.highlight", function() {
		actsOn(this).classed("highlighted", false);
		actsOn(this).selectAll(".highlighted").classed("highlighted", false);
	});
}

function selectOnClick(selector, actsOn) {
	d3.selectAll(selector).on("click", function() {
		var obj = actsOn(this);
		var isSelected = obj.classed("selected") || obj.selectAll(".selected")[0].length;
		obj.classed("selected", !isSelected);
		obj.selectAll("rect, circle").classed("selected", !isSelected);
		setClearVisibility();
	});
}

function exportOnDoubleClick(selector, actsOn) {
	d3.selectAll(selector).on("dblclick", function() {
		var data = actsOn(this).data()[0];
		var condition = data.condition;
		ExportPlaylist({
			FILENAME: data.filename || data.condition,
			FILTER: data.condition,
		});
	});
}

function getSelectionCondition() {
	var selected = d3.selectAll("g.selected");
	if (!selected.data().length) {
		alert("Nothing selected");
		return '';
	}
	return _.map(_.pluck(selected.data(), 'condition'), function(c) { return "(" + c + ")"; }).join(" or ");
};
