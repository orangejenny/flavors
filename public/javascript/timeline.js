jQuery(document).ready(function() {
	generateTimeline();

	// Handler for generating category charts
	/*jQuery(".category-buttons button").click(function() {
		var args = { CATEGORY: jQuery(this).text() };
		jQuery(".category-container").each(function() {
			args.FACET = jQuery(this).data("facet");
			generateCategoryCharts(args);
		});
	});*/
});

/*function generateCategoryCharts(args) {
	var category = args.CATEGORY;
	var facet = args.FACET;

	jQuery(".category-buttons .active").removeClass("active");
	jQuery(".category-buttons button[data-category='" + category + "']").addClass("active");

	var containerSelector = ".category-container[data-facet='" + facet + "']";
	var icons = {
		rating: 'glyphicon-star',
		energy: 'glyphicon-fire',
		mood: 'glyphicon-heart',
	};
	var chartSelector = containerSelector + " svg";
	var width = jQuery(containerSelector).width();
	var barSize = 20;
	var textHeight = 13;

	jQuery(chartSelector).html("");
	var chart = d3.select(chartSelector)
						.attr("width", width);

	var xScale = d3.scale.linear().range([0, width]);

	CallRemote({
		SUB: 'FlavorsData::CategoryStats',
		ARGS: args,
		FINISH: function(data) {	// arry of objects, each with TAG (string) and VALUES (array with length 5)
			data = _.map(data, function(d) { return {
				tag: d.TAG,
				values: _.map(d.VALUES, function(v) { return +v; }),
				description: _.map(d.VALUES, function(v, i) {
					return v ? v + "\t" + StringMultiply("<span class='glyphicon " + icons[facet] + "'></span>", i+1) + "\n" : "";
				}).reverse().join(""),
				condition: "exists (select 1 from songtag where songid = songs.id and tag = '" + d.TAG + "')",
				filename: '[' + d.TAG + ']',
			}; });
			xScale.domain([0, d3.max(_.map(data, function(d) {
				return 2 * (d.values[2] / 2 + Math.max(d.values[1] + d.values[0], d.values[3] + d.values[4]));
			}))]);

			chart.attr("height", data.length * (barSize + textHeight));
			var bars = chart.selectAll("g")
									.data(data)
									.enter().append("g")
									.attr("transform", function(d, i) { return "translate(0, " + i * (barSize + textHeight) + ")"; });

			_.each(_.range(5), function(index) {
				bars.append("rect")
						.attr("height", barSize - 5)
						.attr("width", function(d) { return xScale(d.values[index]); })
						.attr("x", function(d) {
							// Start at midpoint
							var x = width / 2;
							var direction = index > 2 ? 1 : -1;
							x += direction * xScale(d.values[2] / 2);
							if (index == 2) {
								// Center the 3-star rating
								return x;
							}
							if (index < 2) {
								// Push 1 and 2-star ratings left of center
								_.each([0, 1], function(i) {
									if (i >= index) {
										x -= xScale(d.values[i]);
									}
								});
							}
							else {
								// Push 4 and 5-star ratings right of center
								_.each([3, 4], function(i) {
									if (i <= index) {
										x += xScale(d.values[i]);
									}
								});
								x -= xScale(d.values[index]);
							}
							return x;
						})
						.attr("y", textHeight);
			});
			bars.append("text")
									.attr("x", width / 2)
									.attr("y", barSize / 2)
									.text(function(d) { return d.tag; });

			attachTooltip(containerSelector);

			attachSelectionHandlers(containerSelector + " g text", function(text) {
				return d3.select(jQuery(text).closest("g").get(0));
			});

			attachSelectionHandlers(containerSelector + " g  rect");

			d3.selectAll(containerSelector + " g rect").on("dblclick", function() {
				ExportPlaylist({
					//FILENAME: data.tag + ", " + facet + " " + value,
					FILTER: getTagValueCondition(this),
				});
			});
		},
	});
}*/

function generateTimeline() {
	/*var containerSelector = ".timeline-container[data-facet='" + facet + "']";
	var width = jQuery(containerSelector).width();
	var barSize = width / 5;	// 5 bars in each distribution
	var barMargin = 10;

	var distributionHeight = 150;
	var distributionScale = d3.scale.linear().range([distributionHeight, 0]);
	var distribution = d3.select(containerSelector + " svg.distribution")
								.attr("width", width)
								.attr("height", distributionHeight);

	var unratedScale = d3.scale.linear().range([0, width - barMargin]);
	var unratedBarSize = 50;
	var unrated = d3.select(containerSelector + " svg.unrated")
							.attr("width", width)
							.attr("height", unratedBarSize);*/

	CallRemote({
		SUB: 'FlavorsData::TimelineStats',
		FINISH: function(data) {
			debugger;
			/*data = _.map(data, function(d, i) { return {
				condition: facet + '=' + i,
				value: +d.COUNT,
			} });
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
															.attr("height", unratedBarSize / 2);
			// "unrated" bar
			unratedBars.filter(":nth-child(2)").append("rect")
															.attr("x", unratedScale(ratedData.value))
															.attr("width", unratedScale(unratedData.value))
															.attr("height", unratedBarSize / 2);
			// text for both bars
			unratedBars.append("text")
							.attr("x", function(d, i) { return i == 0 ? barTextOffset : width - barTextOffset - barMargin; })
							.attr("y", unratedBarSize / 4)
							.attr("dy", "0.35em")
							.text(function(d, i) { return i == 0 ? ratedData.value + " rated" : unratedData.value + " unrated"; });

			// Create distribution chart
			distributionScale.domain([0, d3.max(_.pluck(data, 'value'))])
			var distributionBars = distribution.selectAll("g")
															.data(data)
															.enter().append("g")
															.attr("transform", function(d, i) { return "translate(" + i * barSize + ", 0)"; });
			distributionBars.append("rect")
									.attr("y", function(d) { return distributionScale(d.value); })
									.attr("width", barSize - barMargin)
									.attr("height", function(d) { return distributionHeight - distributionScale(d.value); });
			distributionBars.append("text")
									.attr("x", barSize / 2)
									.attr("y",  function(d) { return distributionScale(d.value) + barTextOffset; })
									.attr("dy", "0.75em")	// center-align text
									.text(function(d) { return d.value; });

			attachSelectionHandlers(containerSelector + " g");*/
		},
	});
}
