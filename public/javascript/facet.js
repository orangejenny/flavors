jQuery(document).ready(function() {
	var selector = ".facet-container";
	var facet = jQuery(selector).data("facet");
	CallRemote({
		SUB: 'Flavors::Data::Song::Stats',
		ARGS: { GROUPBY: facet },
		SPINNER: selector,
		FINISH: function(data) {
			(new Histogram(".histogram-container", facet, 5)).draw(data);
			(new BinaryChart(".binary-container", facet)).draw(data);
		},
	});

	// Handler for generating category charts
	jQuery(".category-buttons button").click(function() {
		var args = { CATEGORY: jQuery(this).text() };
		jQuery(".category-container").each(function() {
			args.FACET = jQuery(this).data("facet");
			generateCategoryCharts(args);
		});
	});
});

var icons = {
	rating: 'glyphicon-star',
	energy: 'glyphicon-fire',
	mood: 'glyphicon-heart',
};

function generateCategoryCharts(args) {
	var category = args.CATEGORY;
	var facet = args.FACET;

	jQuery(".category-buttons .active").removeClass("active");
	jQuery(".category-buttons button[data-category='" + category + "']").addClass("active");

	var containerSelector = ".category-container[data-facet='" + facet + "']";
	var chartSelector = containerSelector + " svg";
	var width = jQuery(containerSelector).width();
	var barSize = 20;
	var textHeight = 13;

	jQuery(chartSelector).html("");
	var chart = d3.select(chartSelector)
						.attr("width", width);

	var xScale = d3.scale.linear().range([0, width]);

	CallRemote({
		SUB: 'Flavors::Data::Tag::CategoryStats',
		ARGS: args,
		SPINNER: containerSelector,
		FINISH: function(data) {
			data = _.map(data, function(d) { return {
				tag: d.TAG,
				rating: +d.RATING,
				count: +d.COUNT,
				description: d.COUNT + ' ' + StringMultiply("<span class='glyphicon " + icons[facet] + "'></span>", +d.RATING),
				condition: "exists (select 1 from songtag where songid = songs.id and tag = '" + d.TAG + "') and " + facet + " = " + d.RATING,
				filename: '[' + d.TAG + '] ' + facet + ' ' + d.RATING,
				samples: d.SAMPLES,
			}; });

			var tagCounts = _.map(_.groupBy(data, function(d) { return d.tag; }), function(d, tag) {
				var counts = [0, 0, 0, 0, 0];
				_.each(d, function(x) { counts[x.rating - 1] = +x.count });
				return { tag: tag, counts: counts };
			});
			xScale.domain([0, 2 * _.max(_.map(tagCounts, function(d) {
				return d.counts[2] / 2 + Math.max(d.counts[0] + d.counts[1], d.counts[3] + d.counts[4]);
			}))]);

			chart.attr("height", tagCounts.length * (barSize + textHeight));
			var bars = chart.selectAll("g")
									.data(data)
									.enter().append("g")
									.attr("transform", function(d) {
										return "translate(0, " + _.findIndex(tagCounts, function(x) { return x.tag === d.tag; }) * (barSize + textHeight) + ")";
									});

			bars.append("rect")
					.attr("height", barSize - 5)
					.attr("width", function(d) { return xScale(d.count); })
					.attr("x", function(d) {
						var counts = _.find(tagCounts, function(x) { return x.tag === d.tag; }).counts

						// Start at midpoint
						var x = width / 2;
						var direction = d.rating > 3 ? 1 : -1;
						x += direction * xScale(counts[2] / 2);
						if (d.rating === 3) {
							// Center the 3-star rating
							return x;
						}
						if (d.rating < 3) {
							// Push 1 and 2-star ratings left of center
							_.each([0, 1], function(i) {
								if (i >= d.rating - 1) {
									x -= xScale(counts[i]);
								}
							});
						}
						else {
							// Push 4 and 5-star ratings right of center
							 _.each([3, 4], function(i) {
								if (i <= d.rating - 1) {
									x += xScale(counts[i]);
								}
							});
							x -= xScale(d.count);
						}
						return x;
					})
					.attr("y", textHeight)
					.attr("class", function(d) { return "rating-" + d.rating; });

			texted = {};
			bars.each(function(d, i) {
				if (!texted[d.tag]) {
					d3.select(this).append("text")
										.attr("x", width / 2)
										.attr("y", barSize / 2)
										.text(function(d) { return d.tag; });
					texted[d.tag] = 1;
				}
			});

			attachTooltip(containerSelector + " g rect");
			attachSelectionHandlers(containerSelector + " g");
		},
	});
}

function Histogram(selector, facet, range) {
	var self = this;
	self.selector = selector;
	self.facet = facet;
	self.range = range;	// number of bars
	self.height = 150;
	self.width = jQuery(self.selector).width();
	self.barMargin = 10;
	self.barSize = self.width / range;
}

function BinaryChart(selector, facet) {
	var self = this;
	self.selector = selector;
	self.facet = facet;
	self.width = jQuery(self.selector).width();
	self.barMargin = 10;
}

Histogram.prototype.draw = function(data) {
	var self = this;

	var distributionHeight = 150;
	var distributionScale = d3.scale.linear().range([distributionHeight, 0]);
	var distribution = d3.select(self.selector + " svg")
								.attr("width", self.width)
								.attr("height", distributionHeight);

			data.shift();	// pop off unrated data
			data = _.map(data, function(d, i) { return {
				condition: self.facet + '=' + i,
				value: +d.COUNT,
				description: +d.COUNT + " " + StringMultiply("<span class='glyphicon " + icons[self.facet] + "'></span>", i),
				samples: d.SAMPLES,
			} });

			// Create distribution chart
			distributionScale.domain([0, d3.max(_.pluck(data, 'value'))])
			var distributionBars = distribution.selectAll("g")
															.data(data)
															.enter().append("g")
															.attr("transform", function(d, i) { return "translate(" + i * self.barSize + ", 0)"; });
			distributionBars.append("rect")
									.attr("y", function(d) { return distributionScale(d.value); })
									.attr("width", self.barSize - self.barMargin)
									.attr("height", function(d) { return distributionHeight - distributionScale(d.value); });
			distributionBars.append("text")
									.attr("x", self.barSize / 2)
									.attr("y",  function(d) { return distributionScale(d.value) + barTextOffset; })
									.attr("dy", "0.75em")	// center-align text
									.text(function(d) { return d.value; });

			attachSelectionHandlers(self.selector + " g");
			attachTooltip(self.selector + " g");
}

BinaryChart.prototype.draw = function(data) {
	var self = this;

	var unratedScale = d3.scale.linear().range([0, self.width - self.barMargin]);
	var unratedBarSize = 50;
	var unrated = d3.select(self.selector + " svg")
							.attr("width", self.width)
							.attr("height", unratedBarSize);

			data = _.map(data, function(d, i) { return {
				condition: self.facet + '=' + i,
				value: +d.COUNT,
				description: +d.COUNT + " " + StringMultiply("<span class='glyphicon " + icons[self.facet] + "'></span>", i),
				samples: d.SAMPLES,
			} });
			// Create unrated chart: quite janky
			var unratedData = data.shift();
			unratedData.condition = self.facet + ' is null';
			unratedData.description = unratedData.value + " unrated " + Pluralize(unratedData.value, "song");
			var ratedData = {
				value: _.reduce(data, function(memo, value) { return memo + value.value; }, 0),
				condition: self.facet + ' is not null',
			};
			ratedData.description = ratedData.value + " rated " + Pluralize(ratedData.value, "song");
			ratedData.samples = _.reduce(data, function(memo, value) { return memo.concat(value.samples); }, []);
			unratedScale.domain([0, ratedData.value + unratedData.value]);
			var unratedBars = unrated.selectAll("g")
												.data([ratedData, unratedData])
												.enter().append("g");
			// "rated" bar
			unratedBars.filter(":nth-child(1)").append("rect")
															.attr("x", 0)
															.attr("width", unratedScale(ratedData.value))
															.attr("height", unratedBarSize / 2);
			// "unrated" bar
			unratedBars.filter(":nth-child(2)").append("rect")
															.attr("x", unratedScale(ratedData.value))
															.attr("width", unratedScale(unratedData.value))
															.attr("height", unratedBarSize / 2);
			// text for both bars
			unratedBars.append("text")
							.attr("x", function(d, i) { return i == 0 ? barTextOffset : self.width - barTextOffset - self.barMargin; })
							.attr("y", unratedBarSize / 4)
							.attr("dy", "0.35em")
							.text(function(d, i) { return i == 0 ? ratedData.value + " rated" : unratedData.value + " unrated"; });

			attachSelectionHandlers(self.selector + " g");
			attachTooltip(self.selector + " g");
}
