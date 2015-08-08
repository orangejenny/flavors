jQuery(document).ready(function() {
	generateBarChart();
});

function generateBarChart() {
	var containerSelector = ".chart-container";
	var width = jQuery(containerSelector).width();
	var height = 400;
	var margin = 0;

	var chart = d3.select(containerSelector + " svg")
						.attr("width", width)
						.attr("height", height);
	var scale = d3.scale.linear().range([0, height]);

	CallRemote({
		SUB: 'FlavorsData::AcquisitionStats',
		FINISH: function(data) {
			var minDate = new Date(d3.min(_.pluck(data, 'DATESTRING')) + "-15");
			var maxDate = new Date(d3.max(_.pluck(data, 'DATESTRING')) + "-15");
			var minMonthCount = minDate.getFullYear() * 12 + minDate.getMonth();
			var maxMonthCount = maxDate.getFullYear() * 12 + maxDate.getMonth();
			data = _.map(data, function(d) {
				var date = new Date(d.DATESTRING + "-15");
				return {
					date: date,
					month: date.getMonth() + 1,
					year: date.getFullYear(),
					monthCount: date.getFullYear() * 12 + date.getMonth() - minMonthCount,
					count: +d.COUNT,
					condition: "extract(month from mindateacquired) = " + (date.getMonth() + 1) + " and extract(year from mindateacquired) = " + date.getFullYear(),
					filename: "acquired " + date.getFullYear() + "-" + (date.getMonth < 10 ? "0" : "") + (date.getMonth() + 1),
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
					.attr("y", function(d) { return height - scale(d.count); })
					.attr("width", barSize - margin)
					.attr("height", function(d) { return scale(d.count); });

			attachEventHandlers(containerSelector);
		}
	});
}
