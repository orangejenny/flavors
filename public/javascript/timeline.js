jQuery(document).ready(function() {
	var selector = ".timeline-container";
	CallRemote({
		SUB: 'Flavors::Data::Tag::TimelineStats',
		SPINNER: selector,
		FINISH: function(data) {
			var chart = new TimelineChart(selector);
			chart.setDimensions(jQuery(selector).width(), 300);
			chart.draw(data);
		},
	});
});
