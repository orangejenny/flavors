jQuery(document).ready(function() {
	generateBubbleChart();
});

function generateBubbleChart() {
	var containerSelector = ".chart-container";
	var width = jQuery(containerSelector).width();
	var bubbleSize = width / 6;
	var margin = bubbleSize / 2;

	var scale = d3.scale.linear().range([0, bubbleSize * 2]);
	var chart = d3.select(containerSelector + " svg")
						.attr("width", width)
						.attr("height", width);

	CallRemote({
		SUB: 'FlavorsData::SongStats',
		ARGS: { GROUPBY: "rating, energy, mood" },
		FINISH: function(data) {
			var bubbles = [];
			for (e = 1; e <= 5; e++) {
				for (m = 1; m <= 5; m++) {
					bubbles.push({
						energy: e,
						mood: m,
						count: _.reduce(_.filter(data, function(d) {
							return d.ENERGY == e && d.MOOD == m;
						}), function(memo, d) {
							return memo + +d.COUNT;
						}, 0),
						condition: 'mood=' + m + ' and energy=' + e,
					});
				}
			}
			bubbles = _.sortBy(bubbles, 'count').reverse();
			scale.domain([0, _.max(_.pluck(bubbles, 'count'))]);

			var bubbles = chart.selectAll("g")
										.data(bubbles)
										.enter().append("g")
										.attr("transform", function(d, i) {
											var x = bubbleSize * (d.energy - 1) + margin;
											var y = bubbleSize * (5 - d.mood) + margin;
											return "translate(" + x + ", " + y + ")";
										});

			bubbles.append("circle")
						.attr("cx", bubbleSize / 2)
						.attr("cy", bubbleSize / 2)
						.attr("r", function(d) { return scale(d.count) / 2; });

			bubbles.append("text")
						.attr("x", bubbleSize / 2)
						.attr("y", bubbleSize / 2)
						.attr("dy", "0.35em")
						.text(function(d) { return d.count; });

			attachEventHandlers(containerSelector);
		}
	});
}
