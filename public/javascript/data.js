jQuery(document).ready(function() {
	// Generate rating charts
	// TODO: fix spinner so it diappears after all data is loaded
	jQuery(".rating-container").each(function() {
		generateRatingChart(jQuery(this).data("facet"));
	});

	// Generate initial category chart and set handler for future ones
	jQuery(".category-buttons button").click(function() {
		var args = { CATEGORY: jQuery(this).text() };
		jQuery(".category-container").each(function() {
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

	var containerSelector = ".category-container[data-facet='" + facet + "']";
	var chartSelector = containerSelector + " svg";
	var width = jQuery(containerSelector).width();
	var barSize = 20;

	jQuery(chartSelector).html("");
	var chart = d3.select(chartSelector)
						.attr("width", width);

	var xScale = d3.scale.linear().range([0, width]);
	var color = d3.scale.ordinal()
								.range(["#82a6b0", "#559aaf", "#31b0d5", "#18bbec", "#08c3fd"])
								.domain([0, 1, 2, 3, 4]);

	CallRemote({
		SUB: 'FlavorsData::CategoryStats',
		ARGS: args,
		FINISH: function(data) {	// arry of objects, each with TAG (string) and VALUES (array with length 5)*/
			data = _.map(data, function(d) { return {
				TAG: d.TAG,
				VALUES: _.map(d.VALUES, function(v) { return +v; }),
				SUM: _.reduce(d.VALUES, function(memo, v) { return +v + memo; }, 0),
			}; });
			xScale.domain([0, d3.max(_.map(data, function(d) {
				return 2 * (d.VALUES[2] / 2 + Math.max(d.VALUES[1] + d.VALUES[0], d.VALUES[3] + d.VALUES[4]));
			}))]);

			chart.attr("height", data.length * barSize);
			var bars = chart.selectAll("g")
									.data(data)
									.enter().append("g")
									.attr("transform", function(d, i) { return "translate(0, " + i * barSize + ")"; });

			_.each(_.range(5), function(index) {
				bars.append("rect")
						.attr("height", barSize - 5)
						.attr("width", function(d) { return xScale(d.VALUES[index]); })
						.attr("x", function(d) {
							// Start at midpoint
							var x = width / 2;
							var direction = index > 2 ? 1 : -1;
							x += direction * xScale(d.VALUES[2] / 2);
							if (index == 2) {
								// Center the 3-star rating
								return x;
							}
							if (index < 2) {
								// Push 1 and 2-star ratings left of center
								_.each([0, 1], function(i) {
									if (i >= index) {
										x -= xScale(d.VALUES[i]);
									}
								});
							}
							else {
								// Push 4 and 5-star ratings right of center
								_.each([3, 4], function(i) {
									if (i <= index) {
										x += xScale(d.VALUES[i]);
									}
								});
								x -= xScale(d.VALUES[index]);
							}
							return x;
						})
						.style("fill", color(index));
			});
			bars.append("text")
									.attr("x", width / 2)
									.attr("y", barSize / 2)
									.text(function(d) { return d.TAG; });

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
