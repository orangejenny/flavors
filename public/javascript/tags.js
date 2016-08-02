jQuery(document).ready(function() {
	jQuery(document).on('click', '.tag', function() {
		var tag = jQuery(this).text();
		tag = tag.replace(/\s*\(.*/, "");
		var $modal = jQuery("#item-detail");
		$modal.data("tag", tag);
		$modal.find('.modal-header h4 .modal-title').html(tag);
		$modal.modal();
		CallRemote({
			SUB: 'Flavors::Data::Tag::List', 
			ARGS: { RELATED: tag }, 
			SPINNER: ".modal-body .tags",
			FINISH: function(data) {
				$modal.find('.modal-body ul').html(_.map(data, function(d) {
					return "<li class='tag'>" + d.TAG + " <span class='tag-count'>(" + d.COUNT + ")</span></li>";
				}).join(""));
			}
		});
	});

	jQuery(".export-dropdown a").click(function() {
		var tag = jQuery("#item-detail").data("tag");
		ExportPlaylist({
		    PATH: jQuery(this).text(),
			FILENAME: tag,
			FILTER: "taglist like concat('% ', '" + tag + "', ' %')",
		});
	});
});
