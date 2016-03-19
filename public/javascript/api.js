/* Calling out to the EchoNest and Spotify APIs */

// TODO: needs namespace desperately

function _showModal(args) {
    AssertArgs(args, ['ARTIST', 'NAME', 'SONG_ID']);
    var $modal = jQuery("#echo-nest");
    $modal.find(".modal-title").html(args.NAME + " (" + args.ARTIST + ")");
    $modal.data("id", args.SONG_ID);
    $modal.modal();
}

function _hideModal() {
    var $modal = jQuery("#echo-nest");
    $modal.modal('hide');
}

function _showError(text) {
    var $modal = jQuery("#echo-nest");
    $modal.find("table").addClass("hide");
    $modal.find(".alert").html(text).removeClass("hide");
}

function _hideError() {
    var $modal = jQuery("#echo-nest");
    $modal.find("table").removeClass("hide");
    $modal.find(".alert").addClass("hide");
}

function getAudioSummary(args) {
    AssertArgs(args, ['ECHO_NEST_ID', 'SONG_ID']);
    var keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'],
        echoNestID = args.ECHO_NEST_ID,
        songID = args.SONG_ID,
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
                _hideError();
                _showModal({
                    SONG_ID: songID,
                    NAME: data.response.songs[0].title,
                    ARTIST: data.response.songs[0].artist_name,
                });
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
                _showError("Error in EchoNest API");
            }
        },
        error: function(data) {
            _showError("Error in EchoNest API");
        },
    });
}
