jQuery(document).ready(function() {
	jQuery("#export").click(function() {
		ExportPlaylist({
			OBJECT: InitialPageData('object'),
			OBJECTIDLIST: jQuery('#objectidlist').val(),
		});
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
