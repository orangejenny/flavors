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
 * and DIXJUNCTION, which is truthy for "OR", falsy for "AND"
 */
function ExportPlaylist(args) {
	args.FILENAME = prompt("Playlist name?", args.FILENAME || "flavors");
	if (!args.FILENAME) {
		return;
	}

	var params = [];
	for (var key in args) {
		var value = args[key] ? encodeURIComponent(args[key]) : '';
		params.push(key + '=' + value);
	}

	console.log('export.pl?' + params.join('&'));
	document.location = 'export.pl?' + params.join('&');
}

/*
 * UpperCaseFirst
 *
 * Description: ucfirst
 *
 * Args
 *	String to manipulate.
 */
function UpperCaseFirst(str) {
	var first = str.substring(0, 1).toUpperCase();
	var rest = str.substring(1).toLowerCase();
	return first + rest;
}

function InitialPageData(key) {
	key = key.toUpperCase();
	var data = jQuery("#initial-page-data").html();
	data = jQuery.parseJSON(data);
	return data[key];
}

/*
 * StringMultiply
 *
 * Description: Python-style string multiplication
 *
 * Args
 *	String to manipulate and number of times to repeat it (non-negative integer)
 */
function StringMultiply(string, factor) {
	var returnValue = "";
	for (var i = 0 ; i < factor; i++) {
		returnValue += string;
	}
	return returnValue;
}
