jQuery(document).ready(function() {
    $("body").on("click", ".glyphicon-star, .glyphicon-star-empty", function() {
		var $star = jQuery(this);
        if ($star.closest(".rating").length || $star.closest("#filter-container").length) {
            return;
        }
        if ($star.closest(".playlists").length) {
            toggleStar($star, $star.closest("li").data("id"), 'Flavors::Data::Playlist::Star');
        } else {
            toggleStar($star, $star.closest("tr").data("song-id"), 'Flavors::Data::Song::Update');
        }
    });
});

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

