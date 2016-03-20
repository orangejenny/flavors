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
			SPINNER: ".modal-body .songs",
			FINISH: function(data) {
				console.log("done with songs, found " + data.length);
				$modal.find('.modal-body .songs').html(_.map(data, function(d) {
					// TODO: template
					return "<tr>" + _.map([
						d.ARTIST,
						d.NAME,
						"<span class='rating'>" + StringMultiply("<span class='glyphicon glyphicon-star'></span>", d.RATING) + "</span>",
						"<span class='rating'>" + StringMultiply("<span class='glyphicon glyphicon-fire'></span>", d.ENERGY) + "</span>",
						"<span class='rating'>" + StringMultiply("<span class='glyphicon glyphicon-heart'></span>", d.MOOD) + "</span>",
					], function(content) {
						return "<td>" + content + "</td>";
					}).join("") + "</tr>";
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
