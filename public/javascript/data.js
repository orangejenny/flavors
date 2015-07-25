jQuery(document).ready(function() {
	jQuery(".rating-container").each(function() {
		generateRatingChart(jQuery(this).data("facet"));
	});
});

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
			data = _.map(data, function(x) { return +x; });
			// Create unrated chart
			var unratedCount = data.shift();
			var ratedCount = _.reduce(data, function(memo, value) { return memo + value; }, 0);
			unratedScale.domain([0, ratedCount + unratedCount]);
			var unratedBars = unrated.selectAll("g")
												.data([ratedCount, unratedCount])
												.enter().append("g");
			// "rated" bar
			unratedBars.filter(":nth-child(1)").append("rect")
															.attr("x", 0)
															.attr("width", unratedScale(ratedCount))
															.attr("height", barSize / 2);
			// "unrated" bar
			unratedBars.filter(":nth-child(2)").append("rect")
															.attr("x", unratedScale(ratedCount))
															.attr("width", unratedScale(unratedCount))
															.attr("height", barSize / 2);
			// text for both bars
			unratedBars.append("text")
							.attr("x", function(d, i) { return i == 0 ? barTextOffset : width - barTextOffset; })
							.attr("y", barSize / 4)
							.attr("dy", "0.35em")
							.text(function(d, i) { return i == 0 ? ratedCount : unratedCount; });

			// Create distribution chart
			distributionScale.domain([0, d3.max(data)])
			var distributionBars = distribution.selectAll("g")
															.data(data)
															.enter().append("g")
															.attr("transform", function(d, i) { return "translate(" + i * barSize + ", 0)"; });
			distributionBars.append("rect")
									.attr("y", function(d) { return distributionScale(d); })
									.attr("width", barSize - 5)
									.attr("height", function(d) { return distributionHeight - distributionScale(d); });
			distributionBars.append("text")
									.attr("x", barSize / 2)
									.attr("y",  function(d) { return distributionScale(d) + barTextOffset; })
									.attr("dy", "0.75em")	// center-align text
									.text(function(d) { return d; });
		},
	});
}
