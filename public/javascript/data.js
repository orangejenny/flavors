jQuery(document).ready(function() {
	jQuery(".rating-container").each(function() {
		generateRatingChart(jQuery(this).data("facet"));
	});
});

function generateRatingChart(facet) {
	var containerSelector = ".rating-container[data-facet='" + facet + "']";
	var width = jQuery(containerSelector).width();
	var height = 150;
	var yScale = d3.scale.linear()
								.range([height, 0]);
	var chart = d3.select(containerSelector + " svg.ratings")
						.attr("width", width)
						.attr("height", height);

	CallRemote({
		SUB: 'FlavorsData::SongStats',
		ARGS: { FACET: facet },
		FINISH: function(data) {
			data = _.map(data, function(x) { return +x; });
			var unrated = data.shift();
			yScale.domain([0, d3.max(data)])
			var barSize = width / data.length;
			var bar = chart.selectAll("g")
									.data(data)
								.enter().append("g")
									.attr("transform", function(d, i) { return "translate(" + i * barSize + ", 0)"; });
			bar.append("rect")
				.attr("y", function(d) { return yScale(d); })
				.attr("width", barSize - 5)
				.attr("height", function(d) { return height - yScale(d); });
			bar.append("text")
				.attr("x", barSize / 2)
				.attr("y",  function(d) { return yScale(d) + 4; })
				.attr("dy", "0.75em")
				.text(function(d) { return d; });
		},
	});
}
