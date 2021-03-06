function addSong(focus) {
    var $modal = jQuery("#new-collection");
    var lastArtist = $modal.find(".song [name='artist']:last").val();
    var $newSong = $modal.find(".song.hide").clone().removeClass("hide");
    $modal.find("#add-song").before($newSong);
    if (lastArtist) {
        $newSong.find("[name='artist']").val(lastArtist);
    }
    var $rows = $modal.find(".song:visible");
    _.each($rows, function(row, r) {
        _.each($(row).find("input"), function(input, i) {
            if (i < 2) {
                // First two columns: name and artist
                $(input).attr("tabindex", $rows.length * i + r + 1);
            } else {
                // Time columns
                $(input).attr("tabindex", $rows.length * 2 + r + i - 1);
            }
        });
    });
    if (focus) {
        $newSong.find("input:first").focus();
    }
    numberSongs();
}

function dropCollection(id, name) {
    var $well = jQuery(".controls .well");
    if (!$well.find("li[data-id='" + id + "']").length)  {
        var $ul = $well.find("ul");
        $well.find(".subtle").addClass("hide");
        var li = "<li data-id=\"" + id + "\">";
        li += name;
        li += "</li>";
        $ul.append(li);
        jQuery(".collections .collection[data-id='" + id + "']").addClass("selected");
    }
}

function numberSongs() {
    jQuery("#new-collection .ordinal:visible").each(function(index) {
        jQuery(this).html(index + 1 + '.');
    });
}

function filterCollections(force) {
    var query = jQuery("#filter").val().toLowerCase();
    var selector = ".collections .collection";
    var queryTokens = _.without(query.split(/\s+/), "");
    if (!queryTokens.length) {
        jQuery(selector).show();
    }
    else {
        jQuery(selector).show();
        _.each(queryTokens, function(queryToken) {
            jQuery(selector + ":visible").each(function() {
                var $collection = jQuery(this);
                var haystack = _.map(["name", "artist", "artist-list", "tag-list"], function(a) {
                    return $collection.attr("data-" + a);
                }).join(" ").toLowerCase();
                if (haystack.indexOf(queryToken) === -1) {
                    $collection.hide();
                }
            });
        });
    }

    // Account for stars
    if (!jQuery("#simple-filter .far.fa-star").length) {
           jQuery(selector + "[data-starred!='1']").hide();
    }

    // Randomize order if requested
    if (!jQuery("#simple-filter .fa-random").hasClass("text-muted")) {
        var $container = $(".collections"),
            collections = $container.find(".collection").detach();
        collections = _.sortBy(collections, function() { return Math.random(); });
        $container.append(collections);
    }

    return jQuery(".collections .collection:visible").length;
}

jQuery(document).ready(function() {
    jQuery(".collection").click(function() {
        var $collection = jQuery(this),
            id = $collection.data("id");
        showSongModal({
            TITLE: $collection.find(".name").text(),
            SUB: 'Flavors::Data::Collection::TrackList', 
            COLLECTIONIDS: id,
        }, function() {
            var $modal = $("#song-list");
            $modal.data("id", id);
            if ($collection.find(".cover-art.multiple").length) {
                $modal.find(".modal-body").append($collection.find(".cover-art-thumbnails").clone().removeClass("hide"));
            }

            var $backdrop = $(".modal-backdrop.in"),
                $image = $backdrop.clone(),
                $covers = $collection.find("img");
            $image.css("background-color", "transparent")
                  .css("background-size", "cover")
                  .css("background-repeat", "no-repeat")
                  .css("background-position", "center");
            if ($covers.length) {
                var src = $covers[parseInt(Math.random() * $covers.length)].src;
                $image.css("background-image", "url('" + src + "')")
            }
            $backdrop.after($image);

            $modal.one("hide.bs.modal", function() {
                $image.remove();
            });
        });
    });

    // Column names hint for filter
    jQuery(".hint").tooltip({
        html: true,
        placement: "right"
    });

    initSimpleFilter(filterCollections);

    // Controls: Add collection
    jQuery("#add-collection").click(function() {
        var $modal = jQuery("#new-collection");
        $modal.modal();
        $modal.find("input:first").focus();
        if (!$modal.find(".song:visible").length) {
            addSong(false);
        }
    });

    jQuery("#add-song input").focus(function() {
        jQuery(this).select();
    });

    jQuery("#new-collection #add-song button").click(function() {
        var count = jQuery("#add-song input").val();
        if (!parseInt(count)) {
            count = 1;
        }
        for (var i = 0; i < count; i++) {
            addSong(true);
        }
    });

    jQuery("#new-collection").on("click", ".fa-trash", function() {
        jQuery(this).closest(".song").remove();
        numberSongs();
    });

    jQuery("#cancel-add-collection").click(function() {
        var $modal = jQuery("#new-collection");
        $modal.find(".song:visible").remove();
        $modal.find("input[type='text']").val("");
        $modal.find("input[type='checkbox']").attr("checked", false);
        $modal.modal('hide');
    });

    jQuery("#save-collection").click(function() {
        var data = {};
        var $modal = jQuery("#new-collection");
        var $header = $modal.find(".modal-header");
        var $name = $header.find("[name='name']");
        if (!$name.val()) {
            alert("Missing name");
            $name.focus();
        }

        var args = {
            NAME: $name.val(),
            ISMIX: $header.find("input[type='checkbox']").attr("checked"),
            SONGS: [],
        };
        var attributes = ['name', 'artist', 'minutes', 'seconds'];
        $modal.find(".song:visible").each(function() {
            var values = {};
            for (var i = 0; i < attributes.length; i++) {
                var $obj = jQuery(this).find("[name='" + attributes[i] + "']");
                if (!$obj.val()) {
                    alert("Missing data");
                    $obj.focus();
                }
                values[attributes[i].toUpperCase()] = $obj.val();
            }
            if (values.SECONDS < 10) {
                values.SECONDS = '0' + values.SECONDS;
            }
            values.TIME = values.MINUTES + ':' + values.SECONDS;
            args.SONGS.push(values);
        });
        jQuery(this).attr("disabled", true);
        CallRemote({
            SUB: 'Flavors::Data::Collection::Add',
            ARGS: args,
            FINISH: function() {
                location.reload();
            }
        });
    });

    // Export single collection, from modal
    jQuery("#song-list .export-dropdown a").click(function(event) {
        var $collection = jQuery(".collection[data-id='" + jQuery(this).closest("#song-list").data("id") + "']");
        var $details = $collection.find(".details");
        ExportPlaylist({
            CONFIG: jQuery(this).data("name"),
            COLLECTIONIDS: [$collection.data("id")],
            FILENAME: $collection.find(".artist").text() + " - " + $collection.find(".name").text(),
        });
    });

    // Page-level export set of collections
    jQuery("nav .export-dropdown a").click(function() {
        var $button = jQuery(this);
        var collectionids = [];
        jQuery(".collection:visible").each(function() {
            collectionids.push(jQuery(this).data("id"));
        });
        if (!collectionids.length) {
            alert("No collections selected");
            return;
        }
        ExportPlaylist({
            CONFIG: jQuery(this).data("name"),
            COLLECTIONIDS: collectionids,
        });
    });

    // Upload cover art
    var div = document.createElement('div');
    if ((('draggable' in div) || ('ondragstart' in div && 'ondrop' in div)) && 'FormData' in window && 'FileReader' in window) {
        var $targets = jQuery(".collection");
        $targets.on('drag dragstart dragend dragover dragenter dragleave drop', function(e) {
            e.preventDefault();
            e.stopPropagation();
        });
        var current = undefined;
        $targets.on('dragover dragenter', function(e) {
            current = jQuery(e.currentTarget).data("id");
            jQuery('.accepting-drop').addClass('hide');
            jQuery(this).find('.accepting-drop').removeClass("hide");
        });
        $targets.on('dragleave dragend drop', function(e) {
            if (jQuery(e.currentTarget).data("id") !== current) {
                jQuery(this).find('.accepting-drop').addClass("hide");
                current = undefined;
            }
        });
        var formats = [];
        $targets.on('drop', function(e) {
            var $collection = jQuery(this),
                id = $collection.data("id"),
                data = new FormData();

            $collection.find('.accepting-drop').addClass('hide');

            if (!confirm("Upload new art for " + $collection.data("originalTitle") + "?")) {
                return;
            }
            if (e.originalEvent.dataTransfer.files.length !== 1) {
                alert("Please drag a single file.");
                return;
            }
            var file = e.originalEvent.dataTransfer.files[0];
            if (file.type !== "image/png" && file.type !== "image/jpeg") {
                alert("File must be either a PNG or JPEG.");
                return;
            }
            data.append('file', file);
            data.append('ext', file.type.replace(/.*\//, '').replace(/e/, ''));
            data.append('id', id);
            data.append('sub', 'Flavors::Data::Collection::UpdateCoverArt');

            CallRemote({
                ARGS: data,
                FINISH: function(data) {
                    if (data.FILENAME) {
                        var $art = $collection.find(".cover-art"),
                            $img = jQuery("<img />");
                        $img.attr("src", data.FILENAME + "?" + (new Date()).getTime());
                        if ($art.hasClass("missing")) {
                            $art.removeClass("missing");
                            $art.css("background-color", "");
                            $art.html("");
                        } else {
                            $art.addClass("multiple");
                        }
                        $art.append($img);
                        var $li = jQuery("<li></li>");
                        $li.append($img.clone());
                        $collection.find(".cover-art-thumbnails").append($li);
                    }
                },
                UPLOAD: true,
            });
        });
    }

    // Remove cover art
    $(document).on('click', '.cover-art-thumbnails .trash', function() {
        if (confirm('Remove image?')) {
            var $li = $(this).closest("li"),
                src = $li.find("img").attr("src"),
                id = $("#song-list").data("id");
            CallRemote({
                SUB: 'Flavors::Data::Collection::RemoveCoverArt',
                ARGS: {
                    id: id,
                    filename: src,
                },
                FINISH: function(data) {
                    if (data.FILENAME === src) {
                        $li.remove();
                        $collection = $(".collection[data-id='" + id + "']");
                        $collection.find(".cover-art img[src='" + src + "']").remove();
                        $collection.find(".cover-art-thumbnails img[src='" + src + "']").closest("li").remove();
                    } else {
                        alert("Unable to remove image");
                    }
                }
            });
        }
    });
});
