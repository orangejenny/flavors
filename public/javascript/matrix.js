jQuery(document).ready(function() {
	var selector = ".chart-container";
	CallRemote({
		SUB: 'Flavors::Data::Song::Stats',
		ARGS: { GROUPBY: "rating, energy, mood" },
		SPINNER: selector,
		FINISH: function(data) {
			(new BubbleMatrixChart(selector, 5)).draw(data);
		}
	});
});
