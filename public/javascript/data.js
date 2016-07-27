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
            showSongModal({
    			SUB: 'Flavors::Data::Song::List', 
                FILTER: condition,
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
