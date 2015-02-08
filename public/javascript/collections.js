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

jQuery(document).ready(function() {
	jQuery(".collection").click(function() {
		jQuery(this).find(".track-list").toggle('fast');
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
			var $this = jQuery(this);
			var id = ui.draggable.attr("data-id");
			if (!$this.find("li[data-id='" + id + "']").length)  {
				var $ul = $this.find("ul");
				$this.find(".subtle").addClass("hide");
				var li = "<li data-id=\"" + id + "\">";
				li += ui.draggable.find(".name").text();
				li += "</li>";
				$ul.append(li);
			}
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
		$trash.closest("li").remove();
	});

	// Export single collection
	jQuery(".export-icons span").click(function(event) {
		var $icon = jQuery(this);
		var $collectiondiv = $icon.closest(".collection");
		ExportPlaylist({
			COLLECTIONIDS: [$collectiondiv.data("id")],
			FILENAME: $collectiondiv.find(".details .name").text(),
			OS: $icon.data("os"),
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
