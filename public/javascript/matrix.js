jQuery(document).ready(function() {
    draw();
});

function draw() {
	var selector = ".chart-container";
	CallRemote({
		SUB: 'Flavors::Data::Song::Stats',
		ARGS: {
            FILTER: $("textarea[name='filter']").val(),
            GROUPBY: "rating, energy, mood",
        },
		SPINNER: selector,
		FINISH: function(data) {
			(new BubbleMatrixChart(selector, 5)).draw(data);
		}
	});
}
