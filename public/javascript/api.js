/* Calling out to the EchoNest and Spotify APIs */

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

function songSearch(args) {
    AssertArgs(args, ['ARTIST', 'NAME', 'SONG_ID'], ['ON_SELECT']);
    var artist = args.ARTIST,
        name = args.NAME,
        songID = args.SONG_ID,
        $modal = jQuery("#echo-nest"),
        $table = $modal.find("table"),
        api_key = $modal.data("api-key"),
        template = _.template(jQuery("#echo-nest-disambiguation-row").text());
    console.log("searching for " + name + " by " + artist);

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
            var $tbody = $table.find("tbody");
            if (data.response && data.response.songs) {
                console.log("Found " + data.response.songs.length + " results");
                if (data.response.songs.length === 1) {
                    var echoNestID = data.response.songs[0].id;
                    saveEchoNestID({
                        SONG_ID: songID,
                        ECHO_NEST_ID: echoNestID,
                    });
                    if (args.ON_SELECT) {
                        args.ON_SELECT.call(null, echoNestID);
                    }
                }
                else if (data.response.songs.length) {
                    // Grab album names from Spotify to help distinguish between similar tracks
                    // TODO: get Spotify API key?
                    showModal(songID, name, artist);
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
                            $tbody.find("tr").on("click", function() {
                                var echoNestID = jQuery(this).data("id");
                                saveEchoNestID({
                                    SONG_ID: songID,
                                    ECHO_NEST_ID: echoNestID,
                                });
                                hideModal();
                                if (args.ON_SELECT) {
                                    args.ON_SELECT.call(null, echoNestID);
                                }
                            });
                        },
                    });
                } else {
                    showModal(songID, name, artist);
                    showError("No songs found");
                }
            } else {
                showModal(songID, name, artist);
                showError("No songs found");
            }
        },
    });
}

function saveEchoNestID(args) {
    AssertArgs(args, ['ECHO_NEST_ID', 'SONG_ID']);
    var songID = args.SONG_ID,
        echoNestID = args.ECHO_NEST_ID;
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
