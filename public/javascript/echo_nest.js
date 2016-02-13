// TODO: needs namespace desperately

function showModal(songID, name, artist) {
    var $modal = jQuery("#echo-nest");
    $modal.find(".modal-title").html(name + " (" + artist + ")");
    $modal.data("id", songID);
    $modal.modal();
}

function hideModal() {
    var $modal = jQuery("#echo-nest");
    $modal.modal('hide');
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
    console.log("searching for " + name + " by " + artist);
    var $modal = jQuery("#echo-nest"),
        $table = $modal.find("table"),
        api_key = $modal.data("api-key"),
        template = _.template(jQuery("#echo-nest-disambiguation-row").text());

    CallRemote({
        URL: 'http://developer.echonest.com/api/v4/song/search?bucket=tracks&bucket=id:spotify',
        METHOD: 'GET',
        SPINNER: $modal.find(".modal-body"),
        ARGS: {
            api_key: api_key,
            format: 'json',
            artist: artist,
            title: name,
        },
        FINISH: function(data) {
            showModal(songID, name, artist);
            var $tbody = $table.find("tbody");
            if (data.response && data.response.songs) {
                console.log("Found " + data.response.songs.length + " results");
                if (data.response.songs.length === 1) {
                    var echoNestID = data.response.songs[0].id;
                    saveEchoNestID(songID, echoNestID);
                    getAudioSummary(songID, echoNestID);
                }
                else if (data.response.songs.length) {
                    // Grab album names from Spotify to help distinguish between similar tracks
                    // TODO: get Spotify API key?
                    var indexToTrackIDs = _.map(data.response.songs, function(song) { return _.pluck(song.tracks, 'id'); });
                    CallRemote({
                        URL: 'https://api.spotify.com/v1/search',
                        METHOD: 'GET',
                        SPINNER: $modal.find(".modal-body"),
                        ARGS: {
                            query: 'track:' + name + ' artist:' + artist,
                            type: 'track',
                        },
                        FINISH: function(spotifyData) {
                            var tracksToAlbums = _.object(_.map(spotifyData.tracks.items, function(item) { return [item.id, item.album.name]; }));
                            hideError();
                            $table.removeClass("hide");
                            $tbody.html('');
                            _.each(_.sortBy(data.response.songs, function(song) {
                                return song.artist_name + "   " + song.title;
                            }), function(song) {
                                // EchoNest's foreign_id look like "spotify:track:foo"
                                var albums = _.map(_.pluck(song.tracks, 'foreign_id'), function(id) { return tracksToAlbums[id.replace(/.*:/, "")]; });
                                $tbody.append(template(_.extend({}, song, {
                                    albums: _.sortBy(_.compact(_.flatten(albums))),
                                })));
                            });
                        },
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

function saveEchoNestID(songID, echoNestID) {
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

function getAudioSummary(songID, echoNestID) {
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
                showModal(songID, data.response.songs[0].title, data.response.songs[0].artist_name);
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
