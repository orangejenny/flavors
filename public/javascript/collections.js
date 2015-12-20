function FilterCollections() {
	var collectionfilter = jQuery("#collection-filter").val().toLowerCase();
	var tagfilters = jQuery("#tag-filter").val().split(/\s+/);
	var showalbums = jQuery("#is-mix input:checked[value=0]").length;
	var showmixes = jQuery("#is-mix input:checked[value=1]").length;
	jQuery(".collection").each(function() {
		var $collection = jQuery(this);
		var show = true;

		// IsMix filter
		if ($collection.attr("data-is-mix") == 1) {
			show = showmixes;
		}
		else {
			show = showalbums;
		}

		// Collection filter
		if (show && ($collection.attr("data-name") + $collection.attr("data-artist")).indexOf(collectionfilter) == -1) {
			show = false;
		}

		// Tag filter
		var tags = $collection.attr("data-tag-list");
		for (var i = 0; show && i < tagfilters.length; i++) {
			if (tags.indexOf(tagfilters[i]) == -1) {
				show = false;
			}
		}

		if (show) {
			$collection.show();
		}
		else {
			$collection.hide();
		}
	});
}

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
		jQuery(this).find(".track-list").toggle('fast');
	});

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

	// Controls: Toggle details
	jQuery("#show-details").click(function() {
		if (jQuery(this).is(":checked")) {
			jQuery(".collection").addClass("has-details");
		}
		else {
			jQuery(".collection").removeClass("has-details");
		}
	});

	// Controls: Sort collections
	jQuery(".sort-menu .dropdown-menu a").click(function() {
		var $link = jQuery(this);
		var $container = jQuery(".collections");
		var attribute = "data-" + $link.text().toLowerCase().replace(" ", "-");

		var collections = [];
		$container.find(".collection").each(function() { collections.push(jQuery(this).detach()); });

		var ascendingSort = function(a, b) {
			a = a.attr(attribute).toLowerCase();
			b = b.attr(attribute).toLowerCase();
			return a > b ? 1 : (a < b ? -1 : 0);
		}
		var descendingSort = function(a, b) {
			a = a.attr(attribute).toLowerCase();
			b = b.attr(attribute).toLowerCase();
			return b > a ? 1 : (b < a ? -1 : 0);
		}

		collections = collections.sort(attribute.match(/name|artist/) ? ascendingSort : descendingSort);
		for (var i in collections) {
			$container.append(jQuery(collections[i]));
		}

		// Change status of dropdown and re-sort links
		var $dropdown = $link.closest(".sort-menu");
		var $current = $dropdown.find(".dropdown-toggle .current");
		var temp = $current.text();
		$current.text($link.text());
		$link.text(temp);
		var $menu = $dropdown.find(".dropdown-menu");
		var links = [];
		$menu.find("li").each(function() { links.push(jQuery(this)); });
		links = links.sort(function(a, b) { return a.text() > b.text() ? 1 : (a.text() < b.text() ? -1 : 0); });
		for (var i in links) {
			$menu.append(links[i]);
		}
	});

	// Controls: Filter collections
	jQuery("#is-mix input:checkbox").click(FilterCollections);
	jQuery("#collection-filter, #tag-filter").keyup(FilterCollections);

	// Car list trigger
	jQuery('#suggestions-trigger').click(function() {
		CallRemote({
			SUB: 'Flavors::Data::Collection::Suggestions',
			FINISH: function(results) {
				// TODO: clear any collections
				_.each(results, function(collection) {
					dropCollection(collection.ID, collection.NAME);
				});
			}
		});
	});

	// Drag collections
	jQuery(".collection").draggable({
		helper: 'clone',
		opacity: 0.5,
		zIndex: 2
	});

	// Drop collections onto target
	jQuery("#export-list").droppable({
		activeClass: "export-list-active",
		hoverClass: "export-list-hover",
		drop: function(event, ui) {
			dropCollection(ui.draggable.attr("data-id"), ui.draggable.find(".name").text());
		}
	});

	// Remove collections from export list
	jQuery("#export-list").on("mouseenter", "li", function() {
		if (!jQuery(this).find(".glyphicon").length) {
			jQuery(this).append("<span class='glyphicon glyphicon-trash'></span>");
		}
	});
	jQuery("#export-list").on("mouseleave", "li", function(event) {
		jQuery(this).find(".glyphicon").remove();
	});
	jQuery("#export-list").on("click", ".glyphicon-trash", function() {
		var $trash = jQuery(this);
		if ($trash.closest("ul").children().length === 1) {
			jQuery(".controls .subtle").removeClass("hide");
		}
		var $li = $trash.closest("li");
		$(".collections .collection[data-id='" + $li.data("id") + "']").removeClass("selected");
		$li.remove();
	});

	// Export single collection
	jQuery(".export-icons span").click(function(event) {
		var $collection = jQuery(this).closest(".collection");
		var $details = $collection.find(".details");
		ExportPlaylist({
			COLLECTIONIDS: [$collection.data("id")],
			FILENAME: $details.find(".artist").text() + " - " + $details.find(".name").text(),
		});
		event.stopPropagation();
	});

	// Export set of collections
	jQuery(".export-button").click(function() {
		var $button = jQuery(this);
		var collectionids = [];
		var collections = jQuery("#export-list li");
		if (!collections.length) {
			collections = jQuery(".collection:visible");
		}
		collections.each(function() {
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
