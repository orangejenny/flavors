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

function showSongModal(args, callback) {
    var $modal = jQuery("#song-list"),
        $body = $modal.find(".modal-body");
    $body.html(jQuery("body .loading").clone().removeClass("hide"));
    $modal.find(".modal-title").text(args.TITLE || "Songs");
    $modal.modal();
	CallRemote({
		ARGS: args || {},
		FINISH: function(songs) {
            var $body = $("#song-list .modal-body"),
                $table = $("<table class='song-table'></table>"),
                count = 0,
                songTemplate = _.template("<tr data-song-id='<%= ID %>'>"
                                            + "<td class='icon-cell is-starred'><%= ISSTARREDHTML %></td>"
                                            + "<td><div class='pull-right'><%= TRACKNUMBER %>.</div></td>"
                                            + "<td><%= NAME %></td>"
                                            + "<td><%= ARTIST %></td>"
                                            + "<td><% if (typeof COLLECTIONS !== 'undefined') { %><%= COLLECTIONS.join('<br>') %><% } %></td>"
                                            + "<td class='rating' contenteditable='true' data-key='rating'><%= RATINGHTML %></td>"
                                            + "<td class='rating' contenteditable='true' data-key='energy'><%= ENERGYHTML %></td>"
                                            + "<td class='rating' contenteditable='true' data-key='mood'><%= MOODHTML %></td>"
                                            + "<td contenteditable='true' data-key='tags'><%= TAGS %></td>"
                                            + "</tr>");
        
            _.each(songs, function(song) {
                $table.append(songTemplate(_.extend(song, {
                    TRACKNUMBER: ++count,
                    ISSTARREDHTML: ratingHTML(parseInt(song.ISSTARRED) ? 'glyphicon-star' : 'glyphicon-star-empty', 1),
                    RATINGHTML: ratingHTML(iconClasses['rating'], song.RATING),
                    ENERGYHTML: ratingHTML(iconClasses['energy'], song.ENERGY),
                    MOODHTML: ratingHTML(iconClasses['mood'], song.MOOD),
                })));
            });
            $body.html($table);
            if (callback && _.isFunction(callback)) {
                callback.apply();
            }
		}
	});
}
