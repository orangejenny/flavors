jQuery(document).ready(function() {
    jQuery(".tag-select").keyup(_.debounce(draw, 500));
    draw();
});

function draw() {
	var selector = ".chart-container";
	CallRemote({
		SUB: 'Flavors::Data::Song::Stats',
		ARGS: {
            FILTER: $("textarea[name='filter']").val(),
            GROUPBY: "rating, energy, mood",
            TAG: $(".tag-select").val(),
        },
		SPINNER: selector,
		FINISH: function(data) {
			(new BubbleMatrixChart(selector, 5)).draw(data);
		}
	});
}
