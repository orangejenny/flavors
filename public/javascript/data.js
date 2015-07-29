jQuery(document).ready(function() {
	// Generate rating charts
	// TODO: fix spinner so it diappears after all data is loaded
	jQuery(".rating-container").each(function() {
		generateRatingChart(jQuery(this).data("facet"));
	});

	// Generate initial category chart and set handler for future ones
	jQuery(".category-buttons button").click(function() {
		var args = { CATEGORY: jQuery(this).text() };
		jQuery(".rating-container").each(function() {
			args.FACET = jQuery(this).data("facet");
			generateCategoryCharts(args);
		});
	});

	// Clear anything selected
	jQuery(".clear-button").click(function() {
		d3.selectAll(".selected").classed("selected", false);
		setClearVisibility();
	});

	// Page-level export: all selected set of data
	jQuery(".export-button").click(function() {
		var selected = d3.selectAll(".selected");
		if (!selected.data().length) {
			alert("Nothing selected");
			return;
		}
		ExportPlaylist({
			FILTER: _.pluck(selected.data(), 'condition').join(" or "),
		});
		selected.classed("selected", false);
		setClearVisibility();
	});
});

// Chart aesthetics
var barTextOffset = 4;

function setClearVisibility() {
	if (jQuery(".selected").length) {
		jQuery(".clear-button").removeClass("hide");
	}
	else {
		jQuery(".clear-button").addClass("hide");
	}
}

function generateCategoryCharts(args) {
	var category = args.CATEGORY;
	var facet = args.FACET;

	jQuery(".category-buttons .active").removeClass("active");
	jQuery(".category-buttons button[data-category='" + category + "']").addClass("active");

	var containerSelector = ".category-container[data-category='" + category + "']";
	var width = jQuery(containerSelector).width();
	var barSize = 20;

	var height = 500;
	var xScale = d3.scale.linear().range([0, width]);
	var chart = d3.select(containerSelector + " svg")
						.attr("width", width)
						.attr("height", height);	// TODO: set after getting data (barSize * number of items)

	CallRemote({
		SUB: 'FlavorsData::CategoryStats',
		ARGS: args,
		FINISH: function(data) {	// arry of objects, each with TAG (string) and VALUES (array with length 5)
			debugger;
			//data = _.map(data, function(d, i) { return { 'condition': facet + '=' + i, 'value': +d } });

			/*distributionScale.domain([0, d3.max(_.pluck(data, 'value'))])
			var distributionBars = distribution.selectAll("g")
															.data(data)
															.enter().append("g")
															.attr("transform", function(d, i) { return "translate(" + i * barSize + ", 0)"; });
			distributionBars.append("rect")
									.attr("y", function(d) { return distributionScale(d.value); })
									.attr("width", barSize - 5)
									.attr("height", function(d) { return distributionHeight - distributionScale(d.value); });
			distributionBars.append("text")
									.attr("x", barSize / 2)
									.attr("y",  function(d) { return distributionScale(d.value) + barTextOffset; })
									.attr("dy", "0.75em")	// center-align text
									.text(function(d) { return d.value; });
			*/

			attachEventHandlers(containerSelector);
		},
	});
}

function generateRatingChart(facet) {
	var containerSelector = ".rating-container[data-facet='" + facet + "']";
	var width = jQuery(containerSelector).width();
	var barSize = width / 5;	// 5 bars in each distribution

	var distributionHeight = 150;
	var distributionScale = d3.scale.linear().range([distributionHeight, 0]);
	var distribution = d3.select(containerSelector + " svg.distribution")
								.attr("width", width)
								.attr("height", distributionHeight);

	var unratedScale = d3.scale.linear().range([0, width]);
	var unrated = d3.select(containerSelector + " svg.unrated")
							.attr("width", width)
							.attr("height", barSize / 2);

	CallRemote({
		SUB: 'FlavorsData::SongStats',
		ARGS: { FACET: facet },
		FINISH: function(data) {
			data = _.map(data, function(d, i) { return { 'condition': facet + '=' + i, 'value': +d } });
			// Create unrated chart: quite janky
			var unratedData = data.shift();
			unratedData.condition = facet + ' is null';
			var ratedData = {
				value: _.reduce(data, function(memo, value) { return memo + value.value; }, 0),
				condition: facet + ' is not null',
			};
			unratedScale.domain([0, ratedData.value + unratedData.value]);
			var unratedBars = unrated.selectAll("g")
												.data([ratedData, unratedData])
												.enter().append("g");
			// "rated" bar
			unratedBars.filter(":nth-child(1)").append("rect")
															.attr("x", 0)
															.attr("width", unratedScale(ratedData.value))
															.attr("height", barSize / 2);
			// "unrated" bar
			unratedBars.filter(":nth-child(2)").append("rect")
															.attr("x", unratedScale(ratedData.value))
															.attr("width", unratedScale(unratedData.value))
															.attr("height", barSize / 2);
			// text for both bars
			unratedBars.append("text")
							.attr("x", function(d, i) { return i == 0 ? barTextOffset : width - barTextOffset; })
							.attr("y", barSize / 4)
							.attr("dy", "0.35em")
							.text(function(d, i) { return i == 0 ? ratedData.value : unratedData.value; });

			// Create distribution chart
			distributionScale.domain([0, d3.max(_.pluck(data, 'value'))])
			var distributionBars = distribution.selectAll("g")
															.data(data)
															.enter().append("g")
															.attr("transform", function(d, i) { return "translate(" + i * barSize + ", 0)"; });
			distributionBars.append("rect")
									.attr("y", function(d) { return distributionScale(d.value); })
									.attr("width", barSize - 5)
									.attr("height", function(d) { return distributionHeight - distributionScale(d.value); });
			distributionBars.append("text")
									.attr("x", barSize / 2)
									.attr("y",  function(d) { return distributionScale(d.value) + barTextOffset; })
									.attr("dy", "0.75em")	// center-align text
									.text(function(d) { return d.value; });

			attachEventHandlers(containerSelector);
		},
	});
}

function attachEventHandlers(selector) {
	// Highlight on hover
	d3.selectAll(selector + " rect").on("mouseenter", function() {
		d3.select(this).classed("highlighted", true);
	});
	d3.selectAll(selector + " rect").on("mouseleave", function() {
		d3.select(this).classed("highlighted", false);
	});

	// Toggle .selected on click
	d3.selectAll(selector + " rect").on("click", function() {
		var s = d3.select(this);
		s.classed("selected", !s.classed("selected"));
		setClearVisibility();
	});

	// Export on double click
	d3.selectAll(selector + " rect").on("dblclick", function() {
		var condition = d3.select(this).data()[0].condition;
		ExportPlaylist({
			FILENAME: condition,
			FILTER: condition,
		});
	});
}
