jQuery(document).ready(function() {
    $("body").on("click", ".glyphicon-star, .glyphicon-star-empty", function() {
        var $star = jQuery(this);
        if ($star.closest(".rating").length || $star.closest("#filter-container").length || $star.closest("nav").length) {
            return;
        }
        if ($star.closest(".playlists").length) {
            toggleStar($star, $star.closest("li").data("id"), 'Flavors::Data::Playlist::Star');
        } else {
            toggleStar($star, $star.closest("tr").data("song-id"), 'Flavors::Data::Song::Update');
        }
    });
});

function initSimpleFilter(callback) {
    callback();

    var $simpleFilter = $("#simple-filter");
    jQuery('#filter').on("keyup blur", _.throttle(function(event) {
        simpleFilter(event && event.keyCode === 13, callback);
    }, 100, { leading: false }));
    jQuery("#simple-filter .glyphicon-remove").click(function() {
        jQuery("#filter").val("");
        simpleFilter(true, callback);
    });
    jQuery("#simple-filter .glyphicon-star-empty, #simple-filter .glyphicon-star").click(function() {
        $(this).toggleClass("glyphicon-star-empty").toggleClass("glyphicon-star");
        simpleFilter(true, callback);
    });
}

function simpleFilter(force, callback) {
    var query = jQuery("#filter").val();

    var lastQuery = jQuery("#last-query input").val();
    if (!force && query === lastQuery) {
        return;
    }

    lastQuery = query;
    jQuery("#last-query-text").text(lastQuery);
    jQuery("#last-query input").val(lastQuery);
    if (lastQuery) {
        jQuery("#simple-filter .glyphicon-remove").removeClass("hide");
    } else {
        jQuery("#simple-filter .glyphicon-remove").addClass("hide");
    }

    callback();
}

// Add complex filter to given condition
function augmentFilter(condition) {
    return _.map(_.compact([condition, $("#complex-filter textarea").val()]), function(x) { return "(" + x + ")"; }).join(" and ");
}

function toggleStar($star, id, sub) {
    var isstarred = $star.hasClass("glyphicon-star") ? 0 : 1;

    // Update markup
    $star.toggleClass("glyphicon-star-empty");
    $star.toggleClass("glyphicon-star");

    $("body").trigger('song-update', {
        id: id,
        value: isstarred,
        key: 'isstarred',
    });

    // Update server data
    $star.addClass("update-in-progress");
    CallRemote({
        SUB: sub,
        ARGS: {
            ID: id,
            ISSTARRED: isstarred,
        },
        FINISH: function(data) {
            $star.removeClass("update-in-progress");
        }
    });
}

