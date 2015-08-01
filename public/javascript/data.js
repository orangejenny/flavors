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
		if (condition) {
			ExportPlaylist({
				FILTER: condition,
			});
			selected.classed("selected", false);
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

function attachEventHandlers(selector) {
	var associatedRect = function(text) {
		return jQuery(text).closest("g").find("rect").get(0);
	}

	// Highlight on hover
	d3.selectAll(selector + " rect").on("mouseenter", function() {
		d3.select(this).classed("highlighted", true);
	});
	d3.selectAll(selector + " rect").on("mouseleave", function() {
		d3.select(this).classed("highlighted", false);
	});

	// Toggle .selected on click
	var _handleClick = function(rect) {
		var s = d3.select(rect);
		s.classed("selected", !s.classed("selected"));
		setClearVisibility();
	};
	d3.selectAll(selector + " rect").on("click", function() {
		_handleClick(this);
	});
	d3.selectAll(selector + " text").on("click", function() {
		_handleClick(associatedRect(this));
	});

	// Export on double click
	var _handleDblClick = function(rect) {
		var condition = d3.select(rect).data()[0].condition;
		ExportPlaylist({
			FILENAME: condition,
			FILTER: condition,
		});
	};
	d3.selectAll(selector + " rect").on("dblclick", function() {
		_handleDblClick(associatedRect(this));
	});
	d3.selectAll(selector + " text").on("dblclick", function() {
		_handleDblClick(jQuery(this).closest("g").find("rect").get(0));
	});
}

function getSelectionCondition() {
	var selected = d3.selectAll(".selected");
	if (!selected.data().length) {
		alert("Nothing selected");
		return '';
	}
	return _.pluck(selected.data(), 'condition').join(" or ");
};
