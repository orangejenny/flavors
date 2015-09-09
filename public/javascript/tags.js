jQuery(document).ready(function() {
	jQuery(document).on('click', '.tag', function() {
		var tag = jQuery(this).text();
		tag = tag.replace(/\(.*/, "");
		var $modal = jQuery("#item-detail");
		$modal.data("tag", tag);
		$modal.find('.modal-header h4').html(tag);
		$modal.modal();
		CallRemote({
			SUB: 'Flavors::Data::Tag::List', 
			ARGS: { RELATED: tag }, 
			SPINNER: ".tags",
			FINISH: function(data) {
				$modal.find('.modal-body .tags').html(_.map(data, function(d) {
					// TODO: template
					return "<li class='tag'>" + d.TAG + " <span class='tag-count'>(" + d.COUNT + ")</span></li>";
				}).join(""));
			}
		});
		CallRemote({
			SUB: 'Flavors::Data::Song::List', 
			ARGS: {
				FILTER: "taglist like concat('% ', '" + tag + "', ' %')",
				ORDERBY: "artist, name",
			}, 
			SPINNER: ".songs",
			FINISH: function(data) {
				$modal.find('.modal-body .songs').html(_.map(data, function(d) {
					return "<li>" + d.ARTIST + " - " + d.NAME + "</li>";
				}).join(""));
			}
		});
	});

	jQuery(".export-button").click(function() {
		var tag = jQuery("#item-detail").data("tag");
		ExportPlaylist({
			FILENAME: tag,
			FILTER: "taglist like concat('% ', '" + tag + "', ' %')",
		});
	});
});
