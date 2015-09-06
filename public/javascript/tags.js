jQuery(document).ready(function() {
	jQuery('.tag').css("cursor", "pointer").click(function() {
		var tag = jQuery(this).text();
		tag = tag.replace(/\(.*/, "");
		CallRemote({
			SUB: 'Flavors::HTML::TagDetails', 
			ARGS: { TAG: tag }, 
			FINISH: function(data) {
				var $modal = jQuery("#item-detail");
				$modal.find('.modal-header h4').html(data.TITLE);
				$modal.find('.modal-body').html(data.CONTENT);
				$modal.modal();
			}
		});
	});
});
