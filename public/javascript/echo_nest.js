jQuery(document).ready(function() {
    var $modal = jQuery("#echo-nest"),
        $table = $modal.find("table"),
        $alert = $modal.find(".alert"),
        api_key = $modal.data("api-key"),
        disambiguationTemplate = _.template(jQuery("#echo-nest-disambiguation-row").text()),
        summaryTemplate = _.template(jQuery("#echo-nest-summary-row").text());

    // Click on song table to pop up modal of EchoNest song results
    jQuery(".echo-nest-trigger").on("click", function() {
        var $row = jQuery(this).closest("tr");
        var name = $row.find(".name").text();
        var artist = $row.find(".artist").text();

        $modal.find(".modal-title").html(name + " (" + artist + ")");
        $modal.data("id", $row.data("song-id"));
        $modal.modal();
        CallRemote({
            URL: 'http://developer.echonest.com/api/v4/song/search',
            METHOD: 'GET',
            SPINNER: $modal.find(".modal-body"),
            ARGS: {
                api_key: api_key,
                format: 'json',
                artist: artist,
                title: name,
            },
            FINISH: function(data) {
                var $tbody = $table.find("tbody");
                if (data.response && data.response.songs) {
                    if (data.response.songs.length) {
                        hideError();
                        $table.removeClass("hide");
                        $tbody.html('');
                        _.each(_.sortBy(data.response.songs, function(song) {
                            return song.artist_name + "   " + song.title;
                        }), function(song) {
                            $tbody.append(disambiguationTemplate(song));
                        });
                    } else {
                        showError("No songs found");
                    }
                }
            },
        });
    });

    // Click EchoNest result to get audio summary
    var keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    jQuery("#echo-nest").on("click", "tr.disambiguation", function() {
        var echoNestID = jQuery(this).data("id"),
            songID = jQuery(this).closest(".modal").data("id");

        // Store EchoNest id to database
        CallRemote({
            SUB: 'Flavors::Data::Song::Update',
            ARGS: {
                ID: songID,
                ECHONESTID: echoNestID,
            },
        });

        // Fetch EchoNest audio attributes
        CallRemote({
            METHOD: 'GET',
            URL: 'http://developer.echonest.com/api/v4/song/profile',
            SPINNER: $modal.find(".modal-body"),
            ARGS: {
                api_key: api_key,
                format: 'json',
                bucket: 'audio_summary',
                id: echoNestID,
            },
            FINISH: function(data) {
                if (data.response && data.response.songs.length && data.response.songs[0].audio_summary) {
                    hideError();
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
                    showError("Error in EchoNest API");
                }
            },
            error: function(data) {
                showError("Error in EchoNest API");
            },
        });
    });

    function showError(text) {
        $table.addClass("hide");
        $alert.text(text).removeClass("hide");
    }

    function hideError() {
        $table.removeClass("hide");
        $alert.addClass("hide");
    }
});
