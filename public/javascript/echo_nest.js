jQuery(document).ready(function() {
    // Click on song table to pop up modal of EchoNest song results
    jQuery(".echo-nest-trigger").on("click", function() {
        var $row = jQuery(this).closest("tr"),
            songID = $row.data("song-id"),
            echoNestID = $row.data("echo-nest-id"),
            name = $row.find(".name").text(),
            artist = $row.find(".artist").text();
        showModal(songID, name, artist);
        if (echoNestID) {
            getAudioSummary(echoNestID);
        } else {
            songSearch(songID, name, artist);
        }
    });

    // Click EchoNest result to get audio summary
    jQuery("#echo-nest").on("click", "tr.disambiguation", function() {
        var echoNestID = jQuery(this).data("id"),
            songID = jQuery(this).closest(".modal").data("id");

        storeEchoNestID(songID, echoNestID);
        getAudioSummary(echoNestID);
    });
});

function showModal(songID, name, artist) {
    var $modal = jQuery("#echo-nest");
    $modal.find(".modal-title").html(name + " (" + artist + ")");
    $modal.data("id", songID);
    $modal.modal();
}

function showError(text) {
    var $modal = jQuery("#echo-nest");
    $modal.find("table").addClass("hide");
    $modal.find(".alert").html(text).removeClass("hide");
}

function hideError() {
    var $modal = jQuery("#echo-nest");
    $modal.find("table").removeClass("hide");
    $modal.find(".alert").addClass("hide");
}

function songSearch(songID, name, artist) {
    var $modal = jQuery("#echo-nest"),
        $table = $modal.find("table"),
        api_key = $modal.data("api-key"),
        template = _.template(jQuery("#echo-nest-disambiguation-row").text());

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
                        $tbody.append(template(song));
                    });
                } else {
                    showError("No songs found");
                }
            } else {
                showError("No songs found");
            }
        },
    });
}

function storeEchoNestID(songID, echoNestID) {
    CallRemote({
        SUB: 'Flavors::Data::Song::Update',
        ARGS: {
            ID: songID,
            ECHONESTID: echoNestID,
        },
        FINISH: function() {
            jQuery("#song-table-container tr[data-song-id='" + songID + "']").data("echo-nest-id", echoNestID);
        },
    });
}

function getAudioSummary(echoNestID) {
    var keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'],
        $modal = jQuery("#echo-nest"),
        $table = $modal.find("table"),
        api_key = $modal.data("api-key"),
        template = _.template(jQuery("#echo-nest-summary-row").text());

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
                $table.find("tbody").html(template({
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
}
