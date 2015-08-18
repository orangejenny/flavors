jQuery(document).ready(function() {
	generateTimeline();
});

var seasons = ['winter', 'spring', 'summer', 'autumn'];
var months = [
	['december', 'january', 'february'],
	['march', 'april', 'may'],
	['june', 'july', 'august'],
	['september', 'october', 'november'],
];
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
			data = _.map(data.YEARS, function(count, year) { return {
				year: +year,
				count: +count,
				condition: "exists (select 1 from songtag where songtag.songid = songs.id and tag = '" + year + "')",
				description: year + "\n" + count + " " + Pluralize(count, "song"),
				filename: year,
			}; }).concat(_.map(data.SEASONS, function(d) { 
				var text = seasons[d.SEASON] + ' ' + d.YEAR;
				var seasonTagString = _.map(months[d.SEASON].concat(seasons[d.SEASON]), function(t) { return "'" + t + "'"; }).join(", ");
				return {
					year: +d.YEAR,
					season: +d.SEASON,
					count: +d.COUNT,
					condition: d.SEASON ? (
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
				}; 
			}));
			var minYear = _.reduce(data, function(memo, d) { return Math.min(memo, d.year); }, Infinity);
			var maxYear = _.reduce(data, function(memo, d) { return Math.max(memo, d.year + 1); }, 0);
			xScale.domain([minYear, maxYear]);
			yScale.domain([_.reduce(data, function(memo, d) { return Math.max(memo, d.count); }, 0), 0]);

			var barSize = width / (maxYear - minYear + 1);

			var bars = chart.selectAll("g")
										.data(data)
										.enter().append("g")
										.attr("transform", function(d, i) {
											return "translate(" + xScale(d.year) + ", 0)";
										});
			bars.append("rect")
					.attr("x", function(d) { return d.season === undefined ? 0 : d.season * (barSize / 4); })
					.attr("y", function(d) { return yScale(d.count); })
					.attr("width", function(d) { return d.season === undefined ? barSize - 1 : (barSize - 4) / 4; })
					.attr("height", function(d) { return height - yScale(d.count); })
					.style("opacity", function(d) { return d.season === undefined ? 0.25 : 1; });

			attachSelectionHandlers(containerSelector + " g");
			attachTooltip(containerSelector);
		},
	});
}