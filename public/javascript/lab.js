jQuery(document).ready(function() {
	jQuery("#export").click(function() {
		ExportPlaylist({
			OBJECT: InitialPageData('object'),
			OBJECTIDLIST: jQuery('#objectidlist').val(),
		});
	});

	jQuery('#objectid').autocomplete({
		autoFocus: true,
		minLength: 3,
		source: function(request, response) {
			var object = InitialPageData('object');
			CallRemote({
				SUB: 'FlavorsData::' + UpperCaseFirst(object) + 'List', 
				ARGS: { NAME: request.term }, 
				FINISH: function(objects) {
					var options = new Array();
					for (var index in objects) {
						options.push({
							label: object == objects[index].NAME + (object === "song" ? " (" + objects[index].ARTIST + ")" : ""),
							value: objects[index].ID
						});
					}
					response(options);
				}
			});
		}
	});

	jQuery('.tag').css("cursor", "pointer").click(function() {
		var tag = jQuery(this).text();
		tag = tag.replace(/\\(.*/, "");
		CallRemote({
			SUB: 'FlavorsHTML::TagSongList', 
			ARGS: { TAG: tag }, 
			FINISH: function(data) {
				$modal.find('.modal-header h4').html(data.TITLE);
				$modal.find('.modal-body').html(data.CONTENT);
				$modal.modal();
			}
		});
	});
});
