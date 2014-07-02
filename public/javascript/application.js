jQuery(document).ready(function() {
	// Set up sliders with their hidden inputs
	jQuery('.slider').slider({
		animate: true,
		change: function(event, ui) {
			jQuery(this).next('input').val(ui.value);
		}
	});
	jQuery('.slider').each(function() {
		jQuery(this).slider('option', 'value', jQuery(this).next("input").val());
	});

});

/*
 * CallRemote
 *
 * Description: Execute a server call.
 * Args
 *	SUB: name of perl sub to call
 *	ARGS: args for the sub
 *	FINISH: JavaScript function to call when complete
 */
function CallRemote(args) {
	if (!args.ARGS) {
		args.ARGS = {};
	}
	args.ARGS.SUB = args.SUB;
	jQuery.ajax({
		type: 'POST',
		url: 'remote.pl',
		dataType: 'json',
		data: args.ARGS, 
		success: args.FINISH,
		error: function() {
			alert("Error in CallRemote");
		}
	});
}

/*
 * BuildArgs
 *
 * Description: Creates an args object based on the inputs found in a given selector.
 * Parameters
 *	selector: CSS selector of container holding the inputs
 *	args: (optional) an object to add the args to
 */
function BuildArgs(selector, args) {
	if (!args) {
		args = {};
	}

	jQuery(selector + ' select, ' + selector + ' input, ' + selector + ' textarea').each(function() {
		var name = jQuery(this).attr('name');
		if (name) {
			var value;
			if (jQuery(this).is(':checkbox')) {
				value = jQuery(this).is(':checked') ? 1 : 0;
			}
			else {
				value = jQuery(this).val();
			}
			args[name] = value;
		}
	});

	return args;
}

/*
 * ExportPlaylist
 *
 * Description: Presents user with M3U file of songs to download.
 *
 * Args
 *	COLLECTIONIDS: Get all tracks from this collection
 *	or
 *	(variety of filters that will be passed to FlavorsData::SongList)
 */
function ExportPlaylist(args) {
	var params = [];
	for (var key in args) {
		var value = args[key] ? encodeURIComponent(args[key]) : '';
		params.push(key + '=' + value);
	}

	document.location = 'export.pl?' + params.join('&');
}
