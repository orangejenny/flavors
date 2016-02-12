jQuery(document).ready(function() {
    var $button = jQuery("#populate-ids");

    $button.on("click", function() {
        CallRemote({
            SUB: 'Flavors::Data::Song::List',
            ARGS: {
                FILTER: "echonestid is null",
            },
            SPINNER: $button,
            FINISH: function(data) {
                var count = data.length - 1;
                setInterval(function() {
                    songSearch(data[count].ID, data[count].NAME, data[count].ARTIST);
                    count--;
                    $button.find(".count").html(count);
                    if (!count) {
                        clearInterval();
                    }
                }, 3000);
            },
        });
    });
});

