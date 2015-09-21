jQuery(document).ready(function() {
	var selector = ".chart-container";
	CallRemote({
		SUB: 'Flavors::Data::Collection::AcquisitionStats',
		SPINNER: selector,
		FINISH: function(data) {
			(new AcquisitionsChart(selector)).draw(data);
		},
	});
});

function AcquisitionsChart(selector) {
	var self = this;
	self.barMargin = 0;
	self.selector = selector;
	self.svg = d3.select(self.selector + " svg");
	self.width = jQuery(selector).width();
	self.height = 400;
	self.xAxis = d3.svg.axis();
	self.xAxisMargin = 20;
};

AcquisitionsChart.prototype.attachEvents = function() {
	var self = this;
	attachSelectionHandlers(self.selector + " g");
	attachTooltip(self.selector + " g:not(.axis)");
};

AcquisitionsChart.prototype.draw = function(data) {
	var self = this;
	var dateStrings = _.pluck(data, 'DATESTRING');
	self.setDimensions();
	self.drawBars(data, dateStrings);
	self.drawAxes(dateStrings);
	self.attachEvents();
};

AcquisitionsChart.prototype.drawAxes = function(dateStrings) {
	var self = this;
	self.formatXAxis(dateStrings);
	self.drawXAxis();
	self.drawXAxisLabels();
};

AcquisitionsChart.prototype.drawBars = function(data, dateStrings) {
	var self = this;
	var barData = self.getBarData(data, dateStrings);
	var barSize = self.getBarSize(self.getMinMonthCount(dateStrings), self.getMaxMonthCount(dateStrings));
	var bars = self.svg.selectAll("g")
							.data(barData)
							.enter().append("g")
							.attr("transform", function(d, i) {
								return "translate(" + d.monthCount * barSize + ", 0)";
							});

	var xScale = self.getXScale(barData);
	bars.append("rect")
			.attr("y", function(d) { return self.height - self.xAxisMargin - xScale(d.count); })
			.attr("width", barSize - self.barMargin)
			.attr("height", function(d) { return xScale(d.count); });
};

AcquisitionsChart.prototype.drawXAxis = function(dateStrings) {
	var self = this;
	self.svg.append("line")
			.attr("class", "axis")
			.attr("x1", 0)
			.attr("y1", self.height - self.xAxisMargin)
			.attr("x2", self.width)
			.attr("y2", self.height - self.xAxisMargin);
};

AcquisitionsChart.prototype.drawXAxisLabels = function(dateStrings) {
	var self = this;
	self.svg.append("g")
			.attr("class", "axis")
			.attr("transform", "translate(0," + (self.height - self.xAxisMargin) + ")")
			.call(self.xAxis);
	self.svg.selectAll(".axis text").attr("y", 2);
};

AcquisitionsChart.prototype.formatXAxis = function(dateStrings) {
	var self = this;
	var barSize = self.getBarSize(self.getMinMonthCount(dateStrings), self.getMaxMonthCount(dateStrings));
	self.xAxis.orient('bottom')
					.tickValues(_.map(_.range(0, self.width, barSize * 12), function(x) { return x + barSize * 6; }))
					.tickFormat(function(t) { return Math.round((t - barSize * 6) / barSize) / 12 + self.getMinYear(dateStrings); });
};

AcquisitionsChart.prototype.getBarData = function(data, dateStrings) {
	var self = this;
	var dateFormat = d3.time.format("%b %Y");
	return _.map(data, function(d) {
		var date = new Date(d.DATESTRING + "-15");
		var text = dateFormat(date);
		return {
			date: date,
			month: date.getMonth() + 1,
			year: date.getFullYear(),
			monthCount: date.getFullYear() * 12 + date.getMonth() - self.getMinMonthCount(dateStrings),
			count: +d.COUNT,
			condition: "extract(month from mindateacquired) = " + (date.getMonth() + 1) + " and extract(year from mindateacquired) = " + date.getFullYear(),
			filename: "acquired " + text,
			description: text + "\n" + d.COUNT + Pluralize(+d.COUNT, " collection"),
			samples: d.SAMPLES,
		};
	});
};

AcquisitionsChart.prototype.getBarSize = function(minMonthCount, maxMonthCount) {
	var self = this;
	return self.width / (maxMonthCount - minMonthCount + 1) - self.barMargin;
};

AcquisitionsChart.prototype.getMaxMonthCount = function(dateStrings) {
	var maxDate = new Date(d3.max(dateStrings) + "-15");
	return maxDate.getFullYear() * 12 + 12;
};

AcquisitionsChart.prototype.getMinMonthCount = function(dateStrings) {
	var minDate = new Date(d3.min(dateStrings) + "-15");
	return minDate.getFullYear() * 12;
};

AcquisitionsChart.prototype.getMinYear = function(dateStrings) {
	var minDate = new Date(d3.min(dateStrings) + "-15");
	return minDate.getFullYear();
};

AcquisitionsChart.prototype.getXScale = function(data) {
	var self = this;
	var scale = d3.scale.linear().range([0, self.height - self.xAxisMargin]);
	scale.domain([0, d3.max(_.pluck(data, 'count'))]);
	return scale;
};

AcquisitionsChart.prototype.setDimensions = function() {
	this.svg.attr("width", this.width)
			  .attr("height", this.height);
};
