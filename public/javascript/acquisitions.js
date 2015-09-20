jQuery(document).ready(function() {
	var chart = new AcquisitionsChart(".chart-container");
	chart.draw();
});

function AcquisitionsChart(containerSelector) {
	var self = this;
	self.containerSelector = containerSelector;
	self.width = jQuery(containerSelector).width();
	self.height = 400;
	self.xAxisMargin = 20;
	self.margin = 0;
	self.svg = d3.select(self.containerSelector + " svg");
	self.dateFormat = d3.time.format("%b %Y");
};

AcquisitionsChart.prototype.setDimensions = function() {
	this.svg.attr("width", this.width)
			  .attr("height", this.height);
};

AcquisitionsChart.prototype.draw = function() {
	var self = this;
	self.setDimensions();
	var scale = d3.scale.linear().range([0, self.height - self.xAxisMargin]);

	CallRemote({
		SUB: 'Flavors::Data::Collection::AcquisitionStats',
		SPINNER: self.containerSelector,
		FINISH: function(data) {
			var minDate = new Date(d3.min(_.pluck(data, 'DATESTRING')) + "-15");
			var maxDate = new Date(d3.max(_.pluck(data, 'DATESTRING')) + "-15");
			var minMonthCount = minDate.getFullYear() * 12;
			var maxMonthCount = maxDate.getFullYear() * 12 + 12;

			var xAxis = d3.svg.axis()
									.orient('bottom');

			data = _.map(data, function(d) {
				var date = new Date(d.DATESTRING + "-15");
				var text = self.dateFormat(date);
				return {
					date: date,
					month: date.getMonth() + 1,
					year: date.getFullYear(),
					monthCount: date.getFullYear() * 12 + date.getMonth() - minMonthCount,
					count: +d.COUNT,
					condition: "extract(month from mindateacquired) = " + (date.getMonth() + 1) + " and extract(year from mindateacquired) = " + date.getFullYear(),
					filename: "acquired " + text,
					description: text + "\n" + d.COUNT + Pluralize(+d.COUNT, " collection"),
					samples: d.SAMPLES,
				};
			});
			var barSize = self.width / (maxMonthCount - minMonthCount + 1) - self.margin;
			scale.domain([0, d3.max(_.pluck(data, 'count'))]);
			var bars = self.svg.selectAll("g")
									.data(data)
									.enter().append("g")
									.attr("transform", function(d, i) {
										return "translate(" + d.monthCount * barSize + ", 0)";
									});

			bars.append("rect")
					.attr("y", function(d) { return self.height - self.xAxisMargin - scale(d.count); })
					.attr("width", barSize - self.margin)
					.attr("height", function(d) { return scale(d.count); });

			self.svg.append("line")
					.attr("class", "axis")
					.attr("x1", 0)
					.attr("y1", self.height - self.xAxisMargin)
					.attr("x2", self.width)
					.attr("y2", self.height - self.xAxisMargin);
			xAxis.tickValues(_.map(_.range(0, self.width, barSize * 12), function(x) { return x + barSize * 6; }))
					.tickFormat(function(t) { return Math.round((t - barSize * 6) / barSize) / 12 + minDate.getFullYear(); });
			self.svg.append("g")
					.attr("class", "axis")
					.attr("transform", "translate(0," + (self.height - self.xAxisMargin) + ")")
					.call(xAxis);
			self.svg.selectAll(".axis text").attr("y", 2);

			attachSelectionHandlers(self.containerSelector + " g");
			attachTooltip(self.containerSelector + " g:not(.axis)");
		}
	});
}
