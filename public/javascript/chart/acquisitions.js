function AcquisitionsChart(selector) {
	var self = this;
	Chart.call(self, selector);
	self.barMargin = 0;
	self.xAxis = undefined;
	self.xAxisMargin = 20;
};
AcquisitionsChart.prototype = Object.create(Chart.prototype);

AcquisitionsChart.prototype.draw = function(data) {
	var self = this;
	data = self.reformatData(data);
	self.drawBars(data);
	self.drawAxes(data);
	self.attachEvents();
};

AcquisitionsChart.prototype.drawAxes = function(data) {
	var self = this;
	self.formatXAxis(data);
	self.drawXAxis();
	self.drawXAxisLabels();
};

AcquisitionsChart.prototype.drawBars = function(data) {
	var self = this;
	var barSize = self.getBarSize(self.getMinMonthCount(data), self.getMaxMonthCount(data));
	var bars = self.svg.selectAll("g")
							.data(data)
							.enter().append("g")
							.attr("transform", function(d, i) {
								return "translate(" + d.monthCount * barSize + ", 0)";
							});

	var yScale = self.getYScale(data);
	bars.append("rect")
			.attr("y", function(d) { return self.height - self.xAxisMargin - yScale(d.count); })
			.attr("width", barSize - self.barMargin)
			.attr("height", function(d) { return yScale(d.count); });
};

AcquisitionsChart.prototype.drawXAxis = function() {
	var self = this;
	self.svg.append("line")
			.attr("class", "axis")
			.attr("x1", 0)
			.attr("y1", self.height - self.xAxisMargin)
			.attr("x2", self.width)
			.attr("y2", self.height - self.xAxisMargin);
};

AcquisitionsChart.prototype.drawXAxisLabels = function() {
	var self = this;
	self.svg.append("g")
			.attr("class", "axis")
			.attr("transform", "translate(0," + (self.height - self.xAxisMargin) + ")")
			.call(self.xAxis);
	self.svg.selectAll(".axis text").attr("y", 2);
};

AcquisitionsChart.prototype.formatXAxis = function(data) {
	var self = this;
	var barSize = self.getBarSize(self.getMinMonthCount(data), self.getMaxMonthCount(data));
	var minYear = d3.min(_.pluck(data, "date")).getFullYear(),
        maxYear = d3.max(_.pluck(data, "date")).getFullYear(),
	    xScale = d3.scaleLinear().range([0, self.width]).domain([minYear, maxYear + 1]);
	self.xAxis = d3.axisBottom(xScale)
                    .tickValues(_.map(_.range(minYear, maxYear + 1), function(t) { return t + 0.5; }))
                    .tickFormat(function(t) { return Math.floor(t); });
					//.tickValues(_.map(_.range(0, self.width, barSize * 12), function(x) { return x + barSize * 6; }))
					//.tickFormat(function(t) { return Math.round((t - barSize * 6) / barSize) / 12 + minYear; });
};

AcquisitionsChart.prototype.reformatData = function(data) {
	var self = this;
	var dateFormat = d3.timeFormat("%b %Y");
	data = _.map(data, function(d) {
		var date = new Date(d.DATESTRING + "-15");
		var text = dateFormat(date);
		return {
			date: date,
			month: date.getMonth() + 1,
			year: date.getFullYear(),
			count: +d.COUNT,
			condition: "extract(month from mincollectioncreated) = " + (date.getMonth() + 1)
                        + " and extract(year from mincollectioncreated) = " + date.getFullYear(),
			filename: "acquired " + text,
			description: text + "\n" + d.COUNT + Pluralize(+d.COUNT, " song"),
		};
	});
	var minMonthCount = self.getMinMonthCount(data);
	return _.map(data, function(d) {
		return _.extend(d, {
			monthCount: d.date.getFullYear() * 12 + d.date.getMonth() - minMonthCount,
		});
	});
};

AcquisitionsChart.prototype.getBarSize = function(minMonthCount, maxMonthCount) {
	var self = this;
	return self.width / (maxMonthCount - minMonthCount + 1) - self.barMargin;
};

AcquisitionsChart.prototype.getMaxMonthCount = function(data) {
	return d3.max(_.pluck(data, "date")).getFullYear() * 12 + 12;
};

AcquisitionsChart.prototype.getMinMonthCount = function(data) {
	return d3.min(_.pluck(data, "date")).getFullYear() * 12;
};

AcquisitionsChart.prototype.getYScale = function(data) {
	var self = this;
	var scale = d3.scaleLinear().range([0, self.height - self.xAxisMargin]);
	scale.domain([0, d3.max(_.pluck(data, 'count'))]);
	return scale;
}; 
