jQuery(document).ready(function() {
    $("body").on("click", ".fa-star", function() {
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

function initSimpleFilter(callback, options) {
    var originalCount = callback();
    updateCount(originalCount);

    var $simpleFilter = $("#simple-filter");
    jQuery('#filter').on("keyup blur", _.throttle(function(event) {
        simpleFilter(event && event.keyCode === 13, callback, options);
    }, 100, { leading: false }));
    jQuery("#simple-filter .fa-times").click(function() {
        jQuery("#filter").val("");
        simpleFilter(true, callback, options);
    });
    jQuery("#simple-filter .fa-random").click(function() {
        $(this).removeClass("text-muted");
        simpleFilter(true, callback, options);
    });
    jQuery("#simple-filter .fa-star").click(function() {
        $(this).toggleClass("far").toggleClass("fas");
        simpleFilter(true, callback, options);
    });
}

function simpleFilter(force, callback, options) {
    var query = jQuery("#filter").val().toLowerCase();
    options = options || {};

    var lastQuery = jQuery("#last-query input").val();
    if (!force && query === lastQuery) {
        return;
    }

    lastQuery = query;
    jQuery("#last-query input").val(lastQuery);
    if (lastQuery) {
        jQuery("#simple-filter .fa-times").removeClass("hide");
    } else {
        jQuery("#simple-filter .fa-times").addClass("hide");
    }

    var count = parseInt(callback());
    updateCount(count);
}

function updateCount(count) {
    count = parseInt(count);
    if (count || count === 0) {
        jQuery("#simple-filter .item-count").text(count.toLocaleString());
    }
}

// Add complex filter to given condition
function augmentFilter(condition) {
    return _.map(_.compact([condition, $("#complex-filter textarea").val()]), function(x) { return "(" + x + ")"; }).join(" and ");
}

function toggleStar($star, id, sub) {
    var isstarred = $star.hasClass("fas") ? 0 : 1;

    // Update markup
    $star.toggleClass("far");
    $star.toggleClass("fas");

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

