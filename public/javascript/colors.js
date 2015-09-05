jQuery(document).ready(function() {
	jQuery(".white-text button").click(function() {
		var $button = jQuery(this);
		UpdateColor(this, { WHITETEXT: $button.val() });
		$button.siblings("button").removeClass("active");
		$button.addClass("active");
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
		SUB: 'FlavorsData::Tag::UpdateColor',
		ARGS: args,
		FINISH: function() {
			$color.removeClass("update-in-progress");
		}
	});
}
