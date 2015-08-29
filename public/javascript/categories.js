jQuery(document).ready(function() {
	jQuery('.tag').css("cursor", "move").draggable();

	jQuery('.category .header').click(function() {
		jQuery(this).next('.category-tags').toggleClass("hide");
	});

	jQuery('.category').droppable({
		hoverClass: "ui-state-active",
		drop: function(event, ui) {
			var $container = jQuery('.category-tags', this);
			jQuery(ui.draggable).remove().css('position', 'static').appendTo($container);
			var args = {
				VALUE: ui.draggable.text(),
				CATEGORY: jQuery(this).attr("category")
			};

			args.TABLE = jQuery(this).closest(".category").data("table");
			if (args.TABLE === "tagcategory") {
				args.VALUECOLUMN = "tag";
				args.CATEGORYCOLUMN = "category";
			}
			else if (args.TABLE === "artistgenre") {
				args.VALUECOLUMN = "artist";
				args.CATEGORYCOLUMN = "genre";
			}
			else {
				alert("Confused, this is neither a tag nor an artist");
				return;
			}
			CallRemote({
				SUB: 'FlavorsData::Tags::UpdateCategory',
				ARGS: args,
			});
		}
	});
});
