function TimelineChart(selector) {
	var self = this;
	Chart.call(self, selector);
	self.maxYear = undefined;
	self.minYear = undefined;
	self.xAxis = d3.svg.axis();
	self.xAxisMargin = 20;
};
TimelineChart.prototype = Object.create(Chart.prototype);

TimelineChart.prototype.drawAxes = function() {
	var self = this;
	self.formatXAxis(self.data);
	self.drawXAxisLabels();
};

TimelineChart.prototype.drawXAxisLabels = function() {
	var self = this;
	self.svg.append("g")
			.attr("class", "axis")
			.attr("transform", "translate(0," + (self.height - self.xAxisMargin) + ")")
			.call(self.xAxis);
	self.svg.selectAll(".axis text").attr("y", 2);
};

TimelineChart.prototype.formatXAxis = function(data) {
	var self = this;
	self.xAxis.orient('bottom')
					.scale(self.getXScale(data))
					.tickFormat(function(y) { return parseInt(y); })
					.tickValues(_.map(_.range(self.getMinYear(data), self.getMaxYear(data)), function(y) { return y + .5; }));
};

TimelineChart.prototype.drawData = function() {
	var self = this;
	var barSize = self.width / (self.getMaxYear(self.data) - self.getMinYear(self.data) + 1);
	var bars = self.svg.selectAll("g")
								.data(self.data)
								.enter().append("g")
								.attr("transform", function(d, i) {
									return "translate(" + self.getXScale(self.data).call(null, d.year) + ", 0)";
								});
	bars.append("rect")
			.attr("x", function(d) { return d.season === undefined ? 0 : d.season * (barSize / 4); })
			.attr("y", function(d) { return self.getYScale(self.data).call(null, d.count); })
			.attr("width", function(d) { return d.season === undefined ? barSize - 1 : (barSize - 4) / 4; })
			.attr("height", function(d) { return self.height - self.xAxisMargin - self.getYScale(self.data).call(null, d.count); })
			.style("opacity", function(d) { return d.season === undefined ? 0.25 : 1; });
};

TimelineChart.prototype.formatData = function(data) {
	return this.formatYearData(data).concat(this.formatSeasonData(data));
};

TimelineChart.prototype.formatSeasonData = function(data) {
	var self = this;
	var months = [
		['december', 'january', 'february'],
		['march', 'april', 'may'],
		['june', 'july', 'august'],
		['september', 'october', 'november'],
	];
	var seasons = ['winter', 'spring', 'summer', 'autumn'];
	return _.map(data.SEASONS, function(d) { 
		var text = seasons[d.SEASON] + ' ' + d.YEAR;
		var seasonTagString = _.map(months[d.SEASON].concat(seasons[d.SEASON]), function(t) { return "'" + t + "'"; }).join(", ");
		return {
			year: +d.YEAR,
			season: +d.SEASON,
			count: +d.COUNT,
			condition: +d.SEASON ? (
				"exists (select 1 from songtag where songtag.songid = songs.id and tag = '" + d.YEAR + "')"
				+ " and exists (select 1 from songtag where songtag.songid = songs.id and tag in (" + seasonTagString + "))"
			) : (
				"exists (select 1 from songtag where songtag.songid = songs.id and tag = '" + d.YEAR + "')"
				+ " and exists (select 1 from songtag where songtag.songid = songs.id and tag in ('january' 'february', 'winter'))"
				+ " or exists (select 1 from songtag where songtag.songid = songs.id and tag = '" + (d.YEAR - 1) + "')"
				+ " and exists (select 1 from songtag where songtag.songid = songs.id and tag = 'december')"
			),
			description: text + "\n" + d.COUNT + " " + Pluralize(d.COUNT, "song"),
			filename: text,
			samples: d.SAMPLES,
		}; 
	});
};

TimelineChart.prototype.formatYearData = function(data) {
	return _.map(data.YEARS, function(d) { return {
		year: +d.YEAR,
		count: +d.COUNT,
		condition: "exists (select 1 from songtag where songtag.songid = songs.id and tag = '" + d.YEAR + "')",
		description: d.YEAR + "\n" + d.COUNT + " " + Pluralize(+d.COUNT, "song"),
		filename: d.YEAR,
		samples: d.SAMPLES,
	}; });
};

TimelineChart.prototype.getMaxYear = function(data) {
	var self = this;
	if (!self.maxYear) {
		self.maxYear = _.reduce(data, function(memo, d) { return Math.max(memo, d.year + 1); }, 0);
	}
	return self.maxYear;
}

TimelineChart.prototype.getMinYear = function(data) {
	var self = this;
	if (!self.minYear) {
		self.minYear = _.reduce(data, function(memo, d) { return Math.min(memo, d.year); }, Infinity);
	}
	return self.minYear;
};

TimelineChart.prototype.getXScale = function(data) {
	var self = this;
	var scale = d3.scaleLinear().range([0, self.width]);
	scale.domain([self.getMinYear(data), self.getMaxYear(data)]);
	return scale;
};

TimelineChart.prototype.getYScale = function(data) {
	var self = this;
	var scale = d3.scaleLinear().range([0, self.height - self.xAxisMargin]);
	scale.domain([_.reduce(data, function(memo, d) { return Math.max(memo, d.count); }, 0), 0]);
	return scale;
};
