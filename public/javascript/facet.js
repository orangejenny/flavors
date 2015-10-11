jQuery(document).ready(function() {
	var selector = ".facet-container";
	var facet = jQuery(selector).data("facet");
	CallRemote({
		SUB: 'Flavors::Data::Song::Stats',
		ARGS: { GROUPBY: facet },
		SPINNER: selector,
		FINISH: function(data) {
			(new Histogram(".histogram-container", facet, 5)).draw(data);
			(new BinaryHorizontalStack(".binary-container", facet)).draw(data);
		},
	});

	// Handler for generating category charts
	jQuery(".category-buttons button").click(function() {
		var selector = ".category-container";
		var category = jQuery(this).text();
		jQuery(".category-container").each(function() {
			jQuery(".category-buttons .active").removeClass("active");
			jQuery(".category-buttons button[data-category='" + category + "']").addClass("active");
			var facet = jQuery(this).data("facet");
			CallRemote({
				SUB: 'Flavors::Data::Tag::CategoryStats',
				ARGS: {
					FACET: facet,
					CATEGORY: category,
				},
				SPINNER: selector,
				FINISH: function(data) {
					(new CategoryChart(selector, facet, 5)).draw(data);
				},
			});
		});
	});
});

var icons = {
	rating: 'glyphicon-star',
	energy: 'glyphicon-fire',
	mood: 'glyphicon-heart',
};

function CategoryChart(selector, facet, range) {
	var self = this;
	self.selector = selector;
	self.facet = facet;
	self.range = range;
	self.svg = d3.select(self.selector + " svg");
	self.width = jQuery(self.selector).width();
	self.barSize = 20;
	self.textHeight = 13;
}

CategoryChart.prototype.attachEvents = function() {
	var self = this;
	attachTooltip(self.selector + " g rect");
	attachSelectionHandlers(self.selector + " g");
};

CategoryChart.prototype.draw = function(data) {
	var self = this;
	jQuery(self.selector + " svg").html("");
	data = self.reformatData(data);
	self.setDimensions(data);
	bars = self.drawBars(data);
	self.drawLabels(bars);
	self.attachEvents();
};

CategoryChart.prototype.reformatData = function(data) {
	return _.map(data, function(d) { return {
		tag: d.TAG,
		rating: +d.RATING,
		count: +d.COUNT,
		description: d.COUNT + ' ' + StringMultiply("<span class='glyphicon " + icons[self.facet] + "'></span>", +d.RATING),
		condition: "exists (select 1 from songtag where songid = songs.id and tag = '" + d.TAG + "') and " + self.facet + " = " + d.RATING,
		filename: '[' + d.TAG + '] ' + self.facet + ' ' + d.RATING,
		samples: d.SAMPLES,
	}; });
};

CategoryChart.prototype.drawBars = function(data) {
	var self = this;
	var xScale = d3.scale.linear().range([0, self.width]);
	xScale.domain([0, 2 * _.max(_.map(self.getTagCounts(data), function(d) {
		return d.counts[2] / 2 + Math.max(d.counts[0] + d.counts[1], d.counts[3] + d.counts[4]);
	}))]);

	var bars = self.svg.selectAll("g")
								.data(data)
								.enter().append("g")
								.attr("transform", function(d) {
									return "translate(0, " + 
										_.findIndex(self.getTagCounts(data), function(x) { return x.tag === d.tag; }) * (self.barSize + self.textHeight)
									+ ")";
								});

	bars.append("rect")
			.attr("height", self.barSize - 5)
			.attr("width", function(d) { return xScale(d.count); })
			.attr("x", function(d) {
				var counts = _.find(self.getTagCounts(data), function(x) { return x.tag === d.tag; }).counts

				// Start at midpoint
				var x = self.width / 2;
				var midRange = self.range / 2;
				var direction = d.rating > midRange ? 1 : -1;
				if (midRange !== parseInt(midRange)) {
					x += direction * xScale(counts[parseInt(midRange)] / 2);
				}
				if (d.rating === midRange) {
					return x;
				}
				if (d.rating < midRange) {
					// Push low ratings left of center
					_.each(_.range(parseInt(midRange)), function(i) {
						if (i >= d.rating - 1) {
							x -= xScale(counts[i]);
						}
					});
				}
				else {
					// Push high ratings right of center
					 _.each(_.map(_.range(parseInt(midRange)), function(x) { return x + Math.ceil(midRange); }), function(i) {
						if (i <= d.rating - 1) {
							x += xScale(counts[i]);
						}
					});
					x -= xScale(d.count);
				}
				return x;
			})
			.attr("y", self.textHeight)
			.attr("class", function(d) { return "rating-" + d.rating; });

	return bars;
};

CategoryChart.prototype.drawLabels = function(bars) {
	var self = this;
	texted = {};
	bars.each(function(d, i) {
		if (!texted[d.tag]) {
			d3.select(this).append("text")
								.attr("x", self.width / 2)
								.attr("y", self.barSize / 2)
								.text(function(d) { return d.tag; });
			texted[d.tag] = 1;
		}
	});
};

CategoryChart.prototype.getTagCounts = function(data) {
	var self = this;
	if (!self.tagCounts) {
		self.tagCounts = _.map(_.groupBy(data, function(d) { return d.tag; }), function(d, tag) {
			var counts = [0, 0, 0, 0, 0];
			_.each(d, function(x) { counts[x.rating - 1] = +x.count });
			return { tag: tag, counts: counts };
		});
	}
	return self.tagCounts;
};

CategoryChart.prototype.setDimensions = function(data) {
	var self = this;
	self.svg.attr("width", self.width);
	self.svg.attr("height", self.getTagCounts(data).length * (self.barSize + self.textHeight));
};

function BinaryHorizontalStack(selector, facet) {
	var self = this;
	self.selector = selector;
	self.facet = facet;
	self.height = 50;
	self.width = jQuery(self.selector).width();
	self.barMargin = 10;
	self.barTextOffset = 4;
	self.svg = d3.select(self.selector + " svg");
}

BinaryHorizontalStack.prototype.attachEvents = function() {
	var self = this;
	attachSelectionHandlers(self.selector + " g");
	attachTooltip(self.selector + " g");
}

BinaryHorizontalStack.prototype.draw = function(data) {
	var self = this;
	self.setDimensions();

	data = _.map(data, function(d, i) { return {
		condition: self.facet + '=' + i,
		value: +d.COUNT,
		description: +d.COUNT + " " + StringMultiply("<span class='glyphicon " + icons[self.facet] + "'></span>", i),
		samples: d.SAMPLES,
	} });
	var unratedData = data[0];
	unratedData.condition = self.facet + ' is null';
	unratedData.description = unratedData.value + " unrated " + Pluralize(unratedData.value, "song");
	var ratedData = {
		value: _.reduce(_.rest(data), function(memo, value) { return memo + value.value; }, 0),
		condition: self.facet + ' is not null',
	};
	ratedData.description = ratedData.value + " rated " + Pluralize(ratedData.value, "song");
	ratedData.samples = _.reduce(_.rest(data), function(memo, value) { return memo.concat(value.samples); }, []);
	var bars = self.drawBars(ratedData, unratedData);
	self.drawBarLabels(ratedData, unratedData, bars);
	self.attachEvents();
};

BinaryHorizontalStack.prototype.drawBarLabels = function(ratedData, unratedData, bars) {
	var self = this;
	bars.append("text")
			.attr("x", function(d, i) { return i == 0 ? self.barTextOffset : self.width - self.barTextOffset - self.barMargin; })
			.attr("y", self.height / 4)
			.attr("dy", "0.35em")
			.text(function(d, i) { return i == 0 ? ratedData.value + " rated" : unratedData.value + " unrated"; });
};

BinaryHorizontalStack.prototype.drawBars = function(ratedData, unratedData) {
	var self = this;
	var bars = self.svg.selectAll("g")
								.data([ratedData, unratedData])
								.enter().append("g");
	var scale = self.getScale(ratedData.value + unratedData.value);
	bars.filter(":nth-child(1)").append("rect")
											.attr("x", 0)
											.attr("width", scale(ratedData.value))
											.attr("height", self.height / 2);
	bars.filter(":nth-child(2)").append("rect")
											.attr("x", scale(ratedData.value))
											.attr("width", scale(unratedData.value))
											.attr("height", self.height / 2);
	return bars;
};

BinaryHorizontalStack.prototype.getScale = function(total) {
	var self = this;
	var scale = d3.scale.linear();
	scale.range([0, self.width - self.barMargin]);
	scale.domain([0, total]);
	return scale;
};

BinaryHorizontalStack.prototype.setDimensions = function() {
	this.svg.attr("width", this.width)
			  .attr("height", this.height);
};

function Histogram(selector, facet, range) {
	var self = this;
	self.selector = selector;
	self.facet = facet;
	self.range = range;	// number of bars
	self.height = 150;
	self.width = jQuery(self.selector).width();
	self.barMargin = 10;
	self.barSize = self.width / range;
	self.barTextOffset = 4;
	self.svg = d3.select(self.selector + " svg");
}

Histogram.prototype.attachEvents = function() {
	var self = this;
	attachSelectionHandlers(self.selector + " g");
	attachTooltip(self.selector + " g");
};

Histogram.prototype.draw = function(data) {
	var self = this;
	data = _.rest(_.map(data, function(d, i) { return {
		condition: self.facet + '=' + i,
		value: +d.COUNT,
		description: +d.COUNT + " " + StringMultiply("<span class='glyphicon " + icons[self.facet] + "'></span>", i),
		samples: d.SAMPLES,
	} }));
	self.setDimensions();
	var bars = self.drawBars(data);
	self.drawBarLabels(data, bars);
	self.attachEvents();
};

Histogram.prototype.drawBarLabels = function(data, bars) {
	var self = this;
	bars.append("text")
			.attr("x", self.barSize / 2)
			.attr("y",  function(d) { return self.getYScale(data).call(null, d.value) + self.barTextOffset; })
			.attr("dy", "0.75em")	// center-align text
			.text(function(d) { return d.value; });
};

Histogram.prototype.drawBars = function(data) {
	var self = this;
	var bars = self.svg.selectAll("g")
								.data(data)
								.enter().append("g")
								.attr("transform", function(d, i) { return "translate(" + i * self.barSize + ", 0)"; });
	var yScale = self.getYScale(data);
	bars.append("rect")
			.attr("y", function(d) { return yScale(d.value); })
			.attr("width", self.barSize - self.barMargin)
			.attr("height", function(d) { return self.height - yScale(d.value); });
	return bars;
};

Histogram.prototype.getYScale = function(data) {
	var self = this;
	var scale = d3.scale.linear().range([self.height, 0]);
	scale.domain([0, d3.max(_.pluck(data, 'value'))])
	return scale;
};

Histogram.prototype.setDimensions = function() {
	this.svg.attr("width", this.width)
			  .attr("height", this.height);
};
