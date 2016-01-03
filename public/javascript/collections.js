function addSong(focus) {
	var $modal = jQuery("#new-collection");
	var lastArtist = $modal.find(".song [name='artist']:last").val();
	var $newSong = $modal.find(".song.hide").clone().removeClass("hide");
	$modal.find("#add-song").before($newSong);
	if (lastArtist) {
		$newSong.find("[name='artist']").val(lastArtist);
	}
	if (focus) {
		$newSong.find("input:first").focus();
	}
	numberSongs();
}

function dropCollection(id, name) {
	var $well = jQuery(".controls .well");
	if (!$well.find("li[data-id='" + id + "']").length)  {
		var $ul = $well.find("ul");
		$well.find(".subtle").addClass("hide");
		var li = "<li data-id=\"" + id + "\">";
		li += name;
		li += "</li>";
		$ul.append(li);
		jQuery(".collections .collection[data-id='" + id + "']").addClass("selected");
	}
}

function numberSongs() {
	jQuery("#new-collection .ordinal:visible").each(function(index) {
		jQuery(this).html(index + 1 + '.');
	});
}

jQuery(document).ready(function() {
	jQuery(".collection").click(function() {
        var $collection = jQuery(this);
        var $modal = jQuery("#track-list");
        $modal.find(".modal-title").html($collection.find(".name").text());
        $modal.find(".modal-body").html($collection.find(".track-list").clone().removeClass("hide"));
        $modal.modal();
	});

	// Column names hint for filter
	jQuery(".hint").tooltip({
		html: true,
		placement: "right"
	});

    // Simple filter
    var lastQuery = "";
	jQuery('#filter').keyup(_.throttle(function() {
		var query = jQuery(this).val().toLowerCase();
		var selector = ".collections .collection";

		if (query === lastQuery) {
			return;
		}
		lastQuery = query;

		var queryTokens = _.without(query.split(/\s+/), "");
		if (!queryTokens.length) {
			jQuery(selector).show();
			return;
		}

        jQuery(selector).show();
		_.each(queryTokens, function(queryToken) {
            jQuery(selector + ":visible").each(function() {
                var $collection = jQuery(this);
                var haystack = _.map(["name", "artist", "artist-list", "tag-list"], function(a) {
                    return $collection.attr("data-" + a);
                }).join(" ").toLowerCase();
                if (haystack.indexOf(queryToken) === -1) {
                    $collection.hide();
                }
            });
		});
	}, 100, { leading: false }));

	// Controls: Add collection
	jQuery("#add-collection").click(function() {
		var $modal = jQuery("#new-collection");
		$modal.modal();
		$modal.find("input:first").focus();
		if (!$modal.find(".song:visible").length) {
			addSong(false);
		}
	});

	jQuery("#add-song input").focus(function() {
		jQuery(this).select();
	});

	jQuery("#new-collection #add-song button").click(function() {
		var count = jQuery("#add-song input").val();
		if (!parseInt(count)) {
			count = 1;
		}
		for (var i = 0; i < count; i++) {
			addSong(true);
		}
	});

	jQuery("#new-collection").on("click", ".glyphicon-trash", function() {
		jQuery(this).closest(".song").remove();
		numberSongs();
	});

	jQuery("#cancel-add-collection").click(function() {
		var $modal = jQuery("#new-collection");
		$modal.find(".song:visible").remove();
		$modal.find("input[type='text']").val("");
		$modal.find("input[type='checkbox']").attr("checked", false);
		$modal.modal('hide');
	});

	jQuery("#save-collection").click(function() {
		var data = {};
		var $modal = jQuery("#new-collection");
		var $header = $modal.find(".modal-header");
		var $name = $header.find("[name='name']");
		if (!$name.val()) {
			alert("Missing name");
			$name.focus();
		}

		var args = {
			NAME: $name.val(),
			ISMIX: $header.find("input[type='checkbox']").attr("checked"),
			SONGS: [],
		};
		var attributes = ['name', 'artist', 'minutes', 'seconds'];
		$modal.find(".song:visible").each(function() {
			var values = {};
			for (var i = 0; i < attributes.length; i++) {
				var $obj = jQuery(this).find("[name='" + attributes[i] + "']");
				if (!$obj.val()) {
					alert("Missing data");
					$obj.focus();
				}
				values[attributes[i].toUpperCase()] = $obj.val();
			}
			if (values.SECONDS < 10) {
				values.SECONDS = '0' + values.SECONDS;
			}
			values.TIME = values.MINUTES + ':' + values.SECONDS;
			args.SONGS.push(values);
		});
		jQuery(this).attr("disabled", true);
		CallRemote({
			SUB: 'Flavors::Data::Collection::Add',
			ARGS: args,
			FINISH: function() {
				location.reload();
			}
		});
	});

	// Export single collection
	jQuery(".export-icons span").click(function(event) {
		var $collection = jQuery(this).closest(".collection");
		var $details = $collection.find(".details");
		ExportPlaylist({
			COLLECTIONIDS: [$collection.data("id")],
			FILENAME: $collection.find(".artist").text() + " - " + $collection.find(".name").text(),
		});
		event.stopPropagation();
	});

	// Export set of collections
	jQuery(".export-button").click(function() {
		var $button = jQuery(this);
		var collectionids = [];
        jQuery(".collection:visible").each(function() {
			collectionids.push(jQuery(this).data("id"));
		});
		if (!collectionids.length) {
			alert("No collections selected");
			return;
		}
		ExportPlaylist({
			COLLECTIONIDS: collectionids,
			OS: $button.data("os"),
		});
	});
});
