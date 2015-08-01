jQuery(document).ready(function() {
	jQuery('.tag').css("cursor", "move").draggable();

	jQuery('.category .header').click(function() {
		jQuery(this).next('.category-tags').slideToggle();
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

			var $tab = jQuery(this).closest(".tab-pane");
			if ($tab.attr("id") == "tag-category") {
				args.TABLE = "tagcategory";
				args.VALUECOLUMN = "tag";
				args.CATEGORYCOLUMN = "category";
			}
			else if ($tab.attr("id") == "artist-genre") {
				args.TABLE = "artistgenre";
				args.VALUECOLUMN = "artist";
				args.CATEGORYCOLUMN = "genre";
			}
			else {
				alert("Confused, this is neither a tag nor an artist");
				return;
			}
			CallRemote({
				SUB: 'FlavorsData::UpdateCategory',
				ARGS: args,
			});
		}
	});

	jQuery(".white-text button").click(function() {
		UpdateColor(this, { WHITETEXT: jQuery(this).val() });
	});

	jQuery("input[type=minicolors]").change(function() {
		UpdateColor(this, { HEX: jQuery(this).val().replace("#", "") });
	});
});

function UpdateColor(obj, args) {
	var $color = jQuery(obj).closest(".color");
	var $input = $color.find("input:first");
	args.NAME = $color.children(".name").text();
	$color.addClass("update-in-progress");
	CallRemote({
		SUB: 'FlavorsData::UpdateColor',
		ARGS: args,
		FINISH: function() {
			$color.removeClass("update-in-progress");
		}
	});
}
