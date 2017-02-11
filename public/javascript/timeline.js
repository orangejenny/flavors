jQuery(document).ready(function() {
    var lastQuery = "",
        selector = ".timeline-container",
        $simpleFilter = $("#simple-filter");

    draw();

    var $simpleFilter = $("#simple-filter");
	jQuery('#filter').on("keyup blur", _.throttle(function(event) {
        simpleFilter(event && event.keyCode === 13);
    }, 100, { leading: false }));
    jQuery("#simple-filter .glyphicon-remove").click(function() {
        jQuery("#filter").val("");
        simpleFilter(true);
    });
    jQuery("#simple-filter .glyphicon-star-empty, #simple-filter .glyphicon-star").click(function() {
        $(this).toggleClass("glyphicon-star-empty").toggleClass("glyphicon-star");
        simpleFilter(true);
    });

    function simpleFilter(force) {
    	var query = jQuery("#filter").val();
    
        if (!force && query === lastQuery) {
            return;
        }
    
    	lastQuery = query;
        if (lastQuery) {
            jQuery("#simple-filter .glyphicon-remove").removeClass("hide");
        } else {
            jQuery("#simple-filter .glyphicon-remove").addClass("hide");
        }
    
        draw();
    }

    function draw() {
    	CallRemote({
            SUB: 'Flavors::Data::Util::TrySQL',
            ARGS: {
    		    INNERSUB: 'Flavors::Data::Tag::TimelineStats',
                FILTER: $("textarea[name='filter']").val(),
                SIMPLEFILTER: $simpleFilter.find("input[type='text']").val(),
                STARRED: $simpleFilter.find(".glyphicon-star").length,
                UPDATEPLAYLIST: 1,
            },
    		SPINNER: selector,
    		FINISH: function(data) {
                handleComplexError(data, function(data) {
        			var chart = new TimelineChart(selector);
    	    		chart.setDimensions(jQuery(selector).width(), 300);
    		    	chart.draw(data);
                });
    		},
    	});
    }
});
