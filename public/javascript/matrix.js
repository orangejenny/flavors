jQuery(document).ready(function() {
	generateBubbleChart();
});

function generateBubbleChart() {
	var containerSelector = ".chart-container";
	var width = jQuery(containerSelector).width();
	var height = width;
	var bubbleSize = width / 6;
	var margin = bubbleSize / 2;

	var scale = d3.scale.linear().range([0, bubbleSize * 2]);
	var chart = d3.select(containerSelector + " svg")
						.attr("width", width)
						.attr("height", height);
	chart.append("line")
			.attr("class", "axis")
			.attr("x1", 0)
			.attr("y1", height / 2)
			.attr("x2", width)
			.attr("y2", height / 2);
	chart.append("line")
			.attr("class", "axis")
			.attr("x1", width / 2)
			.attr("y1", 0)
			.attr("x2", width / 2)
			.attr("y2", height);

	var moodDescriptions = ['very unhappy', 'unhappy', 'neutral', 'happy', 'very happy'];
	var energyDescriptions = ['very slow', 'slow', 'medium tempo', 'energetic', 'very energetic'];
	CallRemote({
		SUB: 'FlavorsData::Songs::Stats',
		ARGS: { GROUPBY: "rating, energy, mood" },
		FINISH: function(data) {
			var bubbles = [];
			for (e = 1; e <= 5; e++) {
				for (m = 1; m <= 5; m++) {
					var relevant = _.filter(data, function(d) {
						return d.ENERGY == e && d.MOOD == m;
					});
					var bubble = {
						energy: e,
						mood: m,
						count: _.reduce(relevant, function(memo, d) {
							return memo + +d.COUNT;
						}, 0),
						condition: 'mood=' + m + ' and energy=' + e,
						filename: [moodDescriptions[m - 1], energyDescriptions[e - 1]].join(" "),
					};
					bubble.description = bubble.count + " " + bubble.filename + " " + Pluralize(bubble.count, "song"),
					bubble.samples = _.flatten(_.map(relevant, function(d) {
						return _.initial(d.SAMPLES.split("\n"));
					}));
					bubbles.push(bubble);
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

			attachSelectionHandlers(containerSelector + " g");
			attachTooltip(containerSelector + " g");
		}
	});
}
