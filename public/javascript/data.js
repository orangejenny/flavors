jQuery(document).ready(function() {
	// Generate charts
	// TODO: fix spinner so it diappears after all data is loaded
	jQuery(".rating-container").each(function() {
		generateRatingChart(jQuery(this).data("facet"));
	});

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

function setClearVisibility() {
	if (jQuery(".selected").length) {
		jQuery(".clear-button").removeClass("hide");
	}
	else {
		jQuery(".clear-button").addClass("hide");
	}
}

function generateRatingChart(facet) {
	var containerSelector = ".rating-container[data-facet='" + facet + "']";
	var width = jQuery(containerSelector).width();
	var barSize = width / 5;	// 5 bars in each distribution
	var barTextOffset = 4;

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
			// Create unrated chart
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
															.attr("value", facet + " is not null")
															.attr("x", 0)
															.attr("width", unratedScale(ratedData.value))
															.attr("height", barSize / 2);
			// "unrated" bar
			unratedBars.filter(":nth-child(2)").append("rect")
															.attr("value", facet + " is null")
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
									.attr("value", function(d, i) { return facet + " = " + (i + 1); })
									.attr("y", function(d) { return distributionScale(d.value); })
									.attr("width", barSize - 5)
									.attr("height", function(d) { return distributionHeight - distributionScale(d.value); });
			distributionBars.append("text")
									.attr("x", barSize / 2)
									.attr("y",  function(d) { return distributionScale(d.value) + barTextOffset; })
									.attr("dy", "0.75em")	// center-align text
									.text(function(d) { return d.value; });

			// Event handlers: highlight on hover
			d3.selectAll("rect").on("mouseenter", function() {
				d3.select(this).classed("highlighted", true);
			});
			d3.selectAll("rect").on("mouseleave", function() {
				d3.select(this).classed("highlighted", false);
			});

			// Event handlers: toggle .selected on click
			d3.selectAll("rect").on("click", function() {
				var s = d3.select(this);
				s.classed("selected", !s.classed("selected"));
				setClearVisibility();
			});

			// Event handlers: export on double click
			d3.selectAll("rect").on("dblclick", function() {
				var condition = d3.select(this).data()[0].condition;
				ExportPlaylist({
					FILENAME: condition,
					FILTER: condition,
				});
			});
		},
	});
}

