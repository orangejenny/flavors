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

function songSearch(args) {
    AssertArgs(args, ['ARTIST', 'NAME', 'SONG_ID', 'COLLECTIONS'], ['BACKGROUND', 'ELEMENT']);
    var artist = args.ARTIST,
        name = args.NAME,
        songID = args.SONG_ID,
        collections = args.COLLECTIONS,
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
                        ELEMENT: args.ELEMENT,
                    });
                    if (!args.BACKGROUND) {
                        getAudioSummary({
                            SONG_ID: songID,
                            ECHO_NEST_ID: echoNestID,
                        });
                    }
                }
                else if (data.response.songs.length) {
                    // Grab album names from Spotify to help distinguish between similar tracks
                    _showModal({
                        SONG_ID: songID,
                        NAME: name,
                        ARTIST: artist,
                    });
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
                            _hideError();
                            $table.removeClass("hide");
                            $tbody.html('');
                            _.each(_.sortBy(data.response.songs, function(song) {
                                return song.artist_name + "   " + song.title;
                            }), function(song) {
                                // EchoNest's foreign_ids look like "spotify:track:foo"
                                var albums = _.map(_.pluck(song.tracks, 'foreign_id'), function(id) { return tracksToAlbums[id.replace(/.*:/, "")]; });
                                albums = _.sortBy(_.compact(_.flatten(albums))),
                                albums = _.map(albums, function(a) {
                                    _.each(collections, function(c) {
                                        c = c.replace(/\w+[([][^\]\)]*[\]\)]/, "").trim();
                                        a = a.replace(new RegExp(c, "i"), "<span class='highlight'>" + c + "</span>");
                                    });
                                    return a;
                                });
                                $tbody.append(template(_.extend({}, song, {
                                    albums: albums,
                                })));
                            });
                            $tbody.find("tr").on("click", function() {
                                var echoNestID = jQuery(this).data("id");
                                saveEchoNestID({
                                    SONG_ID: songID,
                                    ECHO_NEST_ID: echoNestID,
                                    ELEMENT: args.ELEMENT,
                                });
                                _hideModal();
                                if (!args.BACKGROUND) {
                                    getAudioSummary({
                                        SONG_ID: songID,
                                        ECHO_NEST_ID: echoNestID,
                                    });
                                }
                            });
                            var highlighted = [];
                            _.each($("#echo-nest .disambiguation"), function(row) {
                                if ($(row).find(".highlight").length) {
                                    highlighted.push(row);
                                }
                            });
                            if (highlighted.length === 1) {
                                $(highlighted[0]).click();
                            }
                        },
                    });
                } else {
                    saveEchoNestID({
                        SONG_ID: songID,
                        ECHO_NEST_ID: 0,
                        ELEMENT: args.ELEMENT,
                    });
                    if (!args.BACKGROUND) {
               	     _showModal({
            	            SONG_ID: songID,
         	               NAME: name,
      	                  ARTIST: artist,
   	                 });
	                    _showError("No songs found");
						}
                }
            } else {
                if (!args.BACKGROUND) {
                    _showModal({
                        SONG_ID: songID,
                        NAME: name,
                        ARTIST: artist,
                    });
                    _showError("No songs found");
                }
            }
        },
    });
}

function saveEchoNestID(args) {
    AssertArgs(args, ['ECHO_NEST_ID', 'SONG_ID'], ['ELEMENT']);
    var songID = args.SONG_ID,
        echoNestID = args.ECHO_NEST_ID;
    if (args.ELEMENT && args.ELEMENT.length) {
        // Set in markup so CSS recognizes
        args.ELEMENT.attr("data-echo-nest-id", args.ECHO_NEST_ID);
    }
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
