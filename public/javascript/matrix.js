jQuery(document).ready(function() {
    var selector = ".chart-container",
        $simpleFilter = $("#simple-filter");

    initSimpleFilter(function() {
        CallRemote({
            SUB: 'Flavors::Data::Util::TrySQL',
            ARGS: {
                INNERSUB: 'Flavors::Data::Song::Stats',
                FILTER: $("textarea[name='filter']").val(),
                SIMPLEFILTER: $simpleFilter.find("input[type='text']").val(),
                STARRED: $simpleFilter.find(".fas.fa-star").length,
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
    });
});
