var iconClasses = {
    'rating': 'glyphicon-star',
    'energy': 'glyphicon-fire',
    'mood': 'glyphicon-heart',
};
jQuery(document).ready(function() {
	var selector = "[contenteditable=true][data-key]",
        $body = $("body"),
        oldValue = undefined;

	$body.on("focus", selector, function() {
		var $editable = jQuery(this);
		if ($editable.hasClass("rating")) {
			oldValue = $editable.children(".glyphicon:not(.blank)").length;
			$editable.html(StringMultiply("*", oldValue));
		}
		else {
			oldValue = $editable.text().trim();
		}
	});

	$body.on("blur", selector, function() {
		var $editable = jQuery(this),
            key = $editable.data("key"),
            $container = $editable.closest("[data-song-id]"),
		    value = $editable.text().trim();
		if ($editable.hasClass("rating")) {
			value = value.length;
			$editable.html(ratingHTML(iconClasses[key], value));
		}
		if (oldValue != value) {
			var id = $container.data("song-id");
			var args = {
				id: id,
			}
			args[key] = value;
            $body.trigger('song-update', {
                id: id,
                value: value,
                oldValue: oldValue,
                key: key,
            });

			// Update server
			$editable.addClass("update-in-progress");
			CallRemote({
				SUB: 'Flavors::Data::Song::Update', 
				ARGS: args, 
				FINISH: function(data) {
					$editable.removeClass("update-in-progress");
				}
			});
		}
		oldValue = undefined;
	});
});

function ratingHTML(iconClass, number) {
	return StringMultiply("<span class='glyphicon " + (number ? "" : "blank ") + iconClass + "'></span>", number || 5);
}
