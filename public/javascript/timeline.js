jQuery(document).ready(function() {
	generateTimeline();
});

function generateTimeline() {
	var containerSelector = ".timeline-container";
	var width = jQuery(containerSelector).width();
	var height = 300;

	var chart = d3.select(containerSelector + " svg")
						.attr("width", width)
						.attr("height", height);
	var xScale = d3.scale.linear().range([0, width]);
	var yScale = d3.scale.linear().range([0, height]);

	CallRemote({
		SUB: 'FlavorsData::TimelineStats',
		FINISH: function(data) {
			var yearData = _.map(data.YEARS, function(count, year) { return {
				year: +year,
				monthCount: year * 12 + 6,
				count: +count,
				//condition: '',
				//filename: '',
				//description: '',
			}; });
			var seasonData = _.map(data.SEASONS, function(d) { return {
				year: +d.YEAR,
				monthCount: d.YEAR * 12 + d.SEASON * 3 + 1,
				count: +d.COUNT,
				//condition: '',
				//filename: '',
				//description: '',
			}; });
			var minMonthCount = _.reduce(yearData, function(memo, d) { return Math.min(memo, d.monthCount); }, Infinity);
			var maxMonthCount = _.reduce(yearData, function(memo, d) { return Math.max(memo, d.monthCount); }, 0)
			xScale.domain([minMonthCount, maxMonthCount]);
			yScale.domain([_.reduce(yearData, function(memo, d) { return Math.max(memo, d.count); }, 0), 0]);

			var yearLine = d3.svg.line()
			    						.x(function(d) { return xScale(d.monthCount); })
				     					.y(function(d) { return yScale(d.count); });
			var yearPath = chart.append("path")
											.datum(yearData)
											.attr("d", yearLine);

			var seasonLine = d3.svg.line()
											.x(function(d) { return xScale(d.monthCount); })
											.y(function(d) { return yScale(d.count); });
			var seasonPath = chart.append("path")
											.datum(seasonData)
											.attr("d", seasonLine);

			/*attachSelectionHandlers(containerSelector + " g");*/
		},
	});
}
