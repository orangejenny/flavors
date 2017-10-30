jQuery(document).ready(function() {
    jQuery(".loading").addClass("hide");

    // Complex filter events
    var $complexFilter = jQuery("#complex-filter");
    if ($complexFilter.length) {
        // Show SQL error, if any
        if (jQuery("#sql-error").text().trim()) {
            $complexFilter.modal();
        }

        $complexFilter.find("form input").click(function() {
            jQuery(this).closest("form").submit();
        });
        jQuery("#complex-filter-trigger a").click(function() {
            $complexFilter.modal().find("textarea").focus();
        });
        jQuery("#complex-filter-trigger .glyphicon-refresh").click(function() {
            $complexFilter.find("form").submit();
        });
        jQuery("#complex-filter-trigger .glyphicon-remove").click(function() {
            var $form = $complexFilter.find("form");
            $form.find("textarea").val("");
            $form.submit();
        });

        // Complex filter autocompletes
        var hints = $complexFilter.data("hints");
        $complexFilter.find("textarea").atwho({
            at: "#",
            insertTpl: "${name}",
            limit: 100,
            data: _.sortBy(hints),
        });
        var shortcuts = $complexFilter.data("shortcuts");
        $complexFilter.find("textarea").atwho({
            at: "*",
            insertTpl: "${name}",
            displayTpl: "<li>${name} <span class='text-muted'>${expansion}</span></li>",
            limit: 100,
            data: _.sortBy(shortcuts),
        });
    }
});

/*
 * CallRemote
 *
 * Description: Execute a server call.
 * Args
 *    SUB: name of perl sub to call
 *    ARGS: args for the sub
 *    FINISH: JavaScript function to call when complete
 *  UPLOAD: true if this is a file upload rather than a standard JSON-based call
 */
function CallRemote(args) {
    if (!args.ARGS) {
        args.ARGS = {};
    }
    if (args.SUB) {
        args.ARGS.SUB = args.SUB;
    }
    var $spinner;
    var originalPosition;
    var done = false;
    if (args.SPINNER) {
        $spinner = jQuery("body .loading").clone();
        $spinner.show();
        var $container = _.isString(args.SPINNER) ? jQuery(args.SPINNER) : args.SPINNER;
        oldPosition = $container.css("position");
        $container.css("position", "relative");
        // Display if AJAX takes a perceptible amount of time
        _.delay(function() {
            if (!done) {
                $container.append($spinner);
            }
        }, 100);
    }
    var options = {
        type: args.METHOD || 'POST',
        url: args.URL || 'remote.pl',
        dataType: 'json',
        data: args.ARGS, 
        success: function(data, status, xhr) {
            if (args.FINISH) {
                if ($spinner) {
                    $spinner.remove();
                    done = true;
                    $container.css("position", oldPosition);
                }
                args.FINISH.call(this, data, status, xhr);
            }
        },
        error: function(xhr, textStatus) {
            alert("Error in CallRemote: " + textStatus);
        },
    }
    if (args.UPLOAD) {
        options.contentType = false;
        options.processData = false;
    }
    jQuery.ajax(options);
}

/*
 * AssertArgs
 *
 * Description: Verify the presence of given properties in given object.
 * Parameters
 *    args: An object to check
 *    required: An array of strings that must be truthy properties of the object
 *  optional: An array of strings that may be falsy or not present
 */
function AssertArgs(args, required, optional) {
    if (!args) {
        args = {};
    }
    _.each(required, function(r) {
        if (_.isUndefined(args[r])) {
            throw("Missing argument in AssertArgs: " + r);
        }
    });
    var unexpected = _.keys(_.omit(args, required.concat(optional)));
    if (unexpected.length) {
        throw("Unexpected arguments in AssertArgs: " + unexpected.join(", "));
    }
}

/*
 * BuildArgs
 *
 * Description: Creates an args object based on the inputs found in a given selector.
 * Parameters
 *    selector: CSS selector of container holding the inputs
 *    args: (optional) an object to add the args to
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
 *    COLLECTIONIDS: Get all tracks from this collection
 *    or
 *    (variety of filters that will be passed to Song::List) 
 */
function ExportPlaylist(args) {
    args.FILENAME = prompt("Playlist name?", args.FILENAME || "flavors");
    if (!args.FILENAME) {
        return;
    }

    args.OS = navigator.appVersion.toLowerCase().indexOf("win") != -1 ? "pc" : "mac";

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
 *    String to manipulate.
 */
function UpperCaseFirst(str) {
    var first = str.substring(0, 1).toUpperCase();
    var rest = str.substring(1).toLowerCase();
    return first + rest;
}

/*
 * InitialPageData
 *
 * Description: Fetch value from page's initial
 * server-sent data dump.
 * 
 * Args
 * Key to fetch
 */
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
 *    String to manipulate and number of times to repeat it (non-negative integer)
 */
function StringMultiply(string, factor) {
    var returnValue = "";
    for (var i = 0 ; i < factor; i++) {
        returnValue += string;
    }
    return returnValue;
}

/*
 * Pluralize
 *
 * Description: Simple pluralization: just adds "s".
 *
 * Args
 *    Word to pluralize and relevant item count.
 */
function Pluralize(count, stem) {
    return +count === 1 ? stem : stem + "s";
}

/*
 * handleComplexError
 *
 * Description: Pop up filter modal and display error
 *
 * Args
 *    data: object in format returned by Flavors::Data::Utils::TrySQL
 *  callback: will be performed on data.RESULTS
 */
function handleComplexError(data, callback) {
    if (data.ERROR) {
        $("#complex-filter-trigger a").click();
        $("#sql-error").html(data.ERROR).removeClass("hide");
    } else {
        callback(data.RESULTS);
    }
}
