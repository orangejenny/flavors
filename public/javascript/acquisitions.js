jQuery(document).ready(function() {
	generateBarChart();
});

function generateBarChart() {
	var containerSelector = ".chart-container";
	var width = jQuery(containerSelector).width();
	var height = 400;
	var xAxisMargin = 20;
	var margin = 0;

	var chart = d3.select(containerSelector + " svg")
						.attr("width", width)
						.attr("height", height);
	var scale = d3.scale.linear().range([0, height - xAxisMargin]);
	var dateFormat = d3.time.format("%b %Y");

	CallRemote({
		SUB: 'FlavorsData::AcquisitionStats',
		FINISH: function(data) {
			var minDate = new Date(d3.min(_.pluck(data, 'DATESTRING')) + "-15");
			var maxDate = new Date(d3.max(_.pluck(data, 'DATESTRING')) + "-15");
			var minMonthCount = minDate.getFullYear() * 12;
			var maxMonthCount = maxDate.getFullYear() * 12 + 12;

			var xAxis = d3.svg.axis()
									.orient('bottom');

			data = _.map(data, function(d) {
				var date = new Date(d.DATESTRING + "-15");
				var text = dateFormat(date);
				return {
					date: date,
					month: date.getMonth() + 1,
					year: date.getFullYear(),
					monthCount: date.getFullYear() * 12 + date.getMonth() - minMonthCount,
					count: +d.COUNT,
					condition: "extract(month from mindateacquired) = " + (date.getMonth() + 1) + " and extract(year from mindateacquired) = " + date.getFullYear(),
					filename: "acquired " + text,
					description: text + "\n" + d.COUNT + " " + Pluralize(+d.COUNT, "song"),
				};
			});
			var barSize = width / (maxMonthCount - minMonthCount + 1) - margin;
			scale.domain([0, d3.max(_.pluck(data, 'count'))]);
			var bars = chart.selectAll("g")
									.data(data)
									.enter().append("g")
									.attr("transform", function(d, i) {
										return "translate(" + d.monthCount * barSize + ", 0)";
									});

			bars.append("rect")
					.attr("y", function(d) { return height - xAxisMargin - scale(d.count); })
					.attr("width", barSize - margin)
					.attr("height", function(d) { return scale(d.count); });

			chart.append("line")
					.attr("class", "axis")
					.attr("x1", 0)
					.attr("y1", height - xAxisMargin)
					.attr("x2", width)
					.attr("y2", height - xAxisMargin);
			xAxis.tickValues(_.map(_.range(0, width, barSize * 12), function(x) { return x + barSize * 6; }))
					.tickFormat(function(t) { return Math.round((t - barSize * 6) / barSize) / 12 + minDate.getFullYear(); });
			chart.append("g")
					.attr("class", "axis")
					.attr("transform", "translate(0," + (height - xAxisMargin) + ")")
					.call(xAxis);
			chart.selectAll(".axis text").attr("y", 2);

			attachSelectionHandlers(containerSelector + " g");
			attachTooltip(containerSelector + " g:not(.axis)");
		}
	});
}
