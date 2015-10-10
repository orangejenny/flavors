jQuery(document).ready(function() {
	var selector = ".chart-container";
	CallRemote({
		SUB: 'Flavors::Data::Song::Stats',
		ARGS: { GROUPBY: "rating, energy, mood" },
		SPINNER: selector,
		FINISH: function(data) {
			(new BubbleMatrixChart(selector, 5)).draw(data);
		}
	});
});

function BubbleMatrixChart(selector, range) {
	var self = this;
	self.selector = selector;
	self.range = range;
	self.width = jQuery(self.selector).width();
	self.height = self.width;
}

BubbleMatrixChart.prototype.draw = function(data) {
	var self = this;
	var bubbleSize = self.width / (self.range + 1);
	var margin = bubbleSize / 2;

	var scale = d3.scale.linear().range([0, bubbleSize * 2]);
	var chart = d3.select(self.selector + " svg")
						.attr("width", self.width)
						.attr("height", self.height);
	chart.append("line")
			.attr("class", "axis")
			.attr("x1", 0)
			.attr("y1", self.height / 2)
			.attr("x2", self.width)
			.attr("y2", self.height / 2);
	chart.append("line")
			.attr("class", "axis")
			.attr("x1", self.width / 2)
			.attr("y1", 0)
			.attr("x2", self.width / 2)
			.attr("y2", self.height);

	var moodDescriptions = ['very unhappy', 'unhappy', 'neutral', 'happy', 'very happy'];
	var energyDescriptions = ['very slow', 'slow', 'medium tempo', 'energetic', 'very energetic'];
			var bubbles = [];
			for (e = 1; e <= self.range; e++) {
				for (m = 1; m <= self.range; m++) {
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
					bubble.samples = _.flatten(_.pluck(relevant, 'SAMPLES'));
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
											var y = bubbleSize * (self.range - d.mood) + margin;
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

			attachSelectionHandlers(self.selector + " g");
			attachTooltip(self.selector + " g");
};
