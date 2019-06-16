jQuery(document).ready(function() {
    var selector = ".chart-container",
        $simpleFilter = $("#simple-filter");

    initSimpleFilter(function() {
        CallRemote({
            SUB: 'Flavors::Data::Util::TrySQL',
            ARGS: {
                INNERSUB: 'Flavors::Data::Collection::AcquisitionStats',
                FILTER: $("textarea[name='filter']").val(),
                SIMPLEFILTER: $simpleFilter.find("input[type='text']").val(),
                STARRED: $simpleFilter.find(".fas.fa-star").length,
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
}); 
