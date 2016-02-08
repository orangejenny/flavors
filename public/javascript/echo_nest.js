jQuery(document).ready(function() {
    var $modal = jQuery("#echo-nest");
    var $table = $modal.find("table");
    var api_key = $modal.data("api-key");
    var disambiguationTemplate = _.template(jQuery("#echo-nest-disambiguation-row").text());
    var summaryTemplate = _.template(jQuery("#echo-nest-summary-row").text());

    // Click on song table to pop up modal of EchoNest song results
    jQuery(".echo-nest-trigger").on("click", function() {
        var $alert = $modal.find(".alert");
        var $row = jQuery(this).closest("tr");

        var name = $row.find(".name").text();
        var artist = $row.find(".artist").text();

        $modal.find(".modal-title").html(name + " (" + artist + ")");
        $modal.modal();
        $.ajax({
            method: 'GET',
            // TODO: do this server-side with CallRemote (and add a spinner)
            url: 'http://developer.echonest.com/api/v4/song/search?api_key=' + api_key + '&format=json&artist=' + artist + '&title=' + name,
            success: function(data) {
                var $tbody = $table.find("tbody");
                if (data.response && data.response.songs) {
                    if (data.response.songs.length) {
                        $table.removeClass("hide");
                        $tbody.html('');
                        _.each(_.sortBy(data.response.songs, function(song) {
                            return song.artist_name + "   " + song.title;
                        }), function(song) {
                            $tbody.append(disambiguationTemplate(song));
                        });
                        $alert.addClass("hide");
                    } else {
                        $table.addClass("hide");
                        $alert.text("No songs found").removeClass("hide");
                    }
                } else {
                    $table.addClass("hide");
                    $alert.text("Error in EchoNest API").removeClass("hide");
                }
            },
            error: function() {
                $alert.text("Error in EchoNest API").removeClass("hide");
            },
        });
    });

    // Click EchoNest result to get audio summary
    var keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    jQuery("#echo-nest").on("click", "tr.disambiguation", function() {
        var id = jQuery(this).data("id");
        $.ajax({
            method: 'GET',
            url: 'http://developer.echonest.com/api/v4/song/profile?api_key=' + api_key + '&format=json&bucket=audio_summary&id=' + id,
            success: function(data) {
                if (data.response && data.response.songs.length && data.response.songs[0].audio_summary) {
                    $table.removeClass("hide");
                    var summary = data.response.songs[0].audio_summary;
                    summary.key = keys[summary.key] + " " + (summary.mode ? "major" : "minor");
                    summary.loudness += " dB";
                    summary.tempo += " BPM";
                    summary.time_signature += " beats per minute";
                    summary = _.omit(summary, ['analysis_url', 'audio_md5', 'mode']);
                    $table.find("tbody").html(summaryTemplate({
                        pairs: _.sortBy(_.map(_.pairs(summary), function(pair) { return {
                            key: pair[0],
                            value: pair[1],
                        }}), function(pair) { return pair.key; }),
                    }));
                } else {
                    $alert.text("Error in EchoNest API").removeClass("hide");
                    $table.addClass("hide");
                }
            },
            error: function(data) {
                $table.addClass("hide");
                $alert.text("Error in EchoNest API").removeClass("hide");
            },
        });
    });
});
