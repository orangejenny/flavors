jQuery(document).ready(function() {
	var selector = ".chart-container";
	CallRemote({
        SUB: 'Flavors::Data::Util::TrySQL',
        ARGS: {
		    TRYSUB: 'Flavors::Data::Collection::AcquisitionStats',
            FILTER: $("textarea[name='filter']").val(),
            UPDATEPLAYLIST: 1,
        },
		SPINNER: selector,
		FINISH: function(data) {
            handleComplexError(data, function(data) {
		    	var chart = new AcquisitionsChart(selector);
    			chart.setDimensions(jQuery(selector).width(), 400);
	    		chart.draw(data);
            });
		},
	});
}); 
