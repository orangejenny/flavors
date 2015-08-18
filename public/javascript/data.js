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
			window.open("songs.pl?FILTER=" + condition);
		}
	});

	// Controls: export selections
	jQuery(".export-button").click(function() {
		var condition = getSelectionCondition();
		console.log(condition);
		if (condition) {
			ExportPlaylist({
				FILTER: condition,
			});
			d3.selectAll('.selected').classed("selected", false);
			setClearVisibility();
		}
	});
});

// Global chart aesthetics
// TODO: get out of global namespace
var barTextOffset = 4;

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
		if (data.description) {
			var $tooltip = jQuery("#tooltip");
			$tooltip.html(data.description);
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

	// Highlight on hover
	d3.selectAll(selector).on("mouseenter.highlight", function() {
		actsOn(this).classed("highlighted", true);
		actsOn(this).selectAll("rect, circle").classed("highlighted", true);
	});
	d3.selectAll(selector).on("mouseleave.highlight", function() {
		actsOn(this).classed("highlighted", false);
		actsOn(this).selectAll(".highlighted").classed("highlighted", false);
	});

	// Toggle .selected on click
	d3.selectAll(selector).on("click", function() {
		var obj = actsOn(this);
		var isSelected = obj.classed("selected") || obj.selectAll(".selected")[0].length;
		obj.classed("selected", !isSelected);
		obj.selectAll("rect, circle").classed("selected", !isSelected);
		setClearVisibility();
	});

	// Export on double click
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
