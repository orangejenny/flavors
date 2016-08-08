function BubbleMatrixChart(selector, range) {
	var self = this;
	self.selector = selector;
	self.range = range;
	self.width = jQuery(self.selector).width();
	self.height = self.width;
	self.bubbleSize = self.width / (self.range + 1);
	self.svg = d3.select(self.selector + " svg");
}

BubbleMatrixChart.prototype.attachEvents = function() {
	var self = this;
	attachSelectionHandlers(self.selector + " g");
	attachTooltip(self.selector + " g");
};

BubbleMatrixChart.prototype.draw = function(data) {
	var self = this;
	data = self.reformatData(data);
	self.setDimensions();
	self.drawAxes();
	var bubbles = self.drawBubbles(data);
	self.drawLabels(bubbles);
	self.attachEvents();
};

BubbleMatrixChart.prototype.drawAxes = function(data) {
	var self = this;
	self.svg.append("line")
			.attr("class", "axis")
			.attr("x1", 0)
			.attr("y1", self.height / 2)
			.attr("x2", self.width)
			.attr("y2", self.height / 2);
	self.svg.append("line")
			.attr("class", "axis")
			.attr("x1", self.width / 2)
			.attr("y1", 0)
			.attr("x2", self.width / 2)
			.attr("y2", self.height);
};

BubbleMatrixChart.prototype.drawBubbles = function(data) {
	var self = this;
	var scale = self.getScale(data);
	var margin = self.bubbleSize / 2;
	var bubbles = self.svg.selectAll("g")
								.data(data)
								.enter().append("g")
								.attr("transform", function(d, i) {
									var x = self.bubbleSize * (d.energy - 1) + margin;
									var y = self.bubbleSize * (self.range - d.mood) + margin;
									return "translate(" + x + ", " + y + ")";
								});

	bubbles.append("circle")
				.attr("cx", self.bubbleSize / 2)
				.attr("cy", self.bubbleSize / 2)
				.attr("r", function(d) { return scale(d.count) / 2; });
	return bubbles;
};

BubbleMatrixChart.prototype.drawLabels = function(bubbles) {
	var self = this;
	bubbles.append("text")
				.attr("x", self.bubbleSize / 2)
				.attr("y", self.bubbleSize / 2)
				.attr("dy", "0.35em")
				.text(function(d) { return d.count; });
};

BubbleMatrixChart.prototype.getScale = function(data) {
	var self = this;
	var scale = d3.scaleLinear().range([0, self.bubbleSize * 2]);
	scale.domain([0, _.max(_.pluck(data, 'count'))]);
	return scale;
};

BubbleMatrixChart.prototype.reformatData = function(data) {
	var self = this;
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
	return bubbles;
};

BubbleMatrixChart.prototype.setDimensions = function() {
	var self = this;
	self.svg.attr("width", self.width)
	self.svg.attr("height", self.height);
};
