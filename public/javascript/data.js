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
				//FILENAME: condition,	// TODO: store in data
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

function attachEventHandlers(selector) {
	// Highlight on hover
	d3.selectAll(selector + " g").on("mouseenter", function() {
		d3.select(this).selectAll("rect, circle").classed("highlighted", true);
	});
	d3.selectAll(selector + " g").on("mouseleave", function() {
		d3.select(this).selectAll(".highlighted").classed("highlighted", false);
	});

	// Toggle .selected on click
	d3.selectAll(selector + " g").on("click", function() {
		var g = d3.select(this);
		var isSelected = g.selectAll(".selected")[0].length;
		g.selectAll("rect, circle").classed("selected", !isSelected);
		setClearVisibility();
	});

	// Export on double click
	d3.selectAll(selector + " g").on("dblclick", function() {
		var data = d3.select(this).data()[0];
		var condition = data.condition;
		ExportPlaylist({
			FILENAME: data.filename || data.condition,
			FILTER: data.condition,
		});
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
