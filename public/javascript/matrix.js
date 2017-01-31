jQuery(document).ready(function() {
    draw();
});

function draw() {
	var selector = ".chart-container";
	CallRemote({
        SUB: 'Flavors::Data::Util::TrySQL',
		ARGS: {
		    TRYSUB: 'Flavors::Data::Song::Stats',
            FILTER: $("textarea[name='filter']").val(),
            GROUPBY: "rating, energy, mood",
            UPDATEPLAYLIST: 1,
        },
		SPINNER: selector,
		FINISH: function(data) {
            handleComplexError(data, function(data) {
			    (new BubbleMatrixChart(selector, 5)).draw(data);
            });
		},
	});
}
