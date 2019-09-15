package Flavors::Data::Collection;

use strict;
use Flavors::Data::Util;

my $COVER_ART_ROOT = "images/collections/";

################################################################
# AcquisitionStats
#
# Description: Get stats related to song acquisition
#
# Args:
#    FILTER
#
# Return Value: arrayref of hashrefs:
#    DATESTRING: YYYY-MM
#    COUNT
################################################################
sub AcquisitionStats {
    my ($dbh, $args) = @_;
    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});

    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });

    my $sql = sprintf(qq{
            select date_format(flavors_collection.created, '%%Y-%%m') datestring, count(distinct flavors_song.id) count
            from flavors_collection
            inner join flavors_songcollection on flavors_collection.id = flavors_songcollection.collectionid
            inner join (%s) flavors_song on flavors_songcollection.songid = flavors_song.id
            group by date_format(flavors_collection.created, '%%Y-%%m')
        },
        $songlist->{SQL},
    );

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(datestring count)],
        BINDS => $songlist->{BINDS},
    })];
}

################################################################
# Add
#
# Description: Add a new collection and set of songs
#
# Parameters
#        COLLECTION: Hashref containing
#            NAME
#            ISMIX
#        SONGS: Arrayref, each with
#            NAME
#            ARTIST
#            TIME
#
# Return Value: nothing
################################################################
sub Add {
    my ($dbh, $args) = @_;

    # TODO: Genericize
    my @songkeys = grep { $_ =~ m/^SONGS\[/ } keys %$args;
    my @songs = ();
    foreach my $key (@songkeys) {
        if ($key =~ m/^SONGS\[.*\[NAME]$/) {
            push(@songs, {});
        }
    }
    foreach my $key (@songkeys) {
        if ($key =~ m/^SONGS\[(\d+)]\[(\w+)]$/) {
            my $index = $1;
            my $attribute = $2;
            $songs[$index]->{$attribute} = $args->{$key};
        }
    }

    # TODO: Everything within a transaction
    # Add collection
    my @ids = Flavors::Data::Util::Results($dbh, {
        SQL => qq{ select max(id) id from flavors_collection },
        COLUMNS => ['id'],
    });
    my $collectionid = $ids[0]->{ID} + 1;
    my $sql = qq{
        insert into flavors_collection (id, name, ismix, created, exportcount, updated)
        values (?, ?, ?, now(), 0, now())
    };
    Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => [$collectionid, $args->{NAME}, $args->{ISMIX} ? 1 : 0],
        SKIPFETCH => 1,
    });

    # Add songs
    my @songids = Flavors::Data::Util::Results($dbh, {
        SQL => qq{ select max(id) id from flavors_song },
        COLUMNS => ['id'],
    });
    my $lastid = $songids[0]->{ID} + 1;
    my $firstid = $lastid;
    foreach my $song (@songs) {
        my $sql = qq{
            insert into flavors_song (id, name, artist, time, ispurchased, filename, created, updated)
            values (?, ?, ?, ?, 1, concat(?, '/', ?, '.mp3'), now(), now())
        };
        Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            BINDS => [$lastid, $song->{NAME}, $song->{ARTIST}, $song->{TIME}, $song->{ARTIST}, $song->{NAME}],
            SKIPFETCH => 1,
        });
        $lastid++;
    }

    # Add tracks
    my $sql = qq{
        insert into flavors_songcollection (songid, collectionid, tracknumber, created, updated)
        select id, ?, id - ?, now(), now()
        from flavors_song
        where id >= ? and id <= ?
    };
    Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => [$collectionid, $firstid - 1, $firstid, $lastid],
        SKIPFETCH => 1,
    });
}

################################################################
# List
#
# Description: Get a list of collections
#
# Parameters (optional)
#        ID: only this collection
#        FILTER
#        SONGID: only collections that include this song
#        UPDATEPLAYLIST: if true, add filter to collection playlists
#
# Return Value: array/arrayref of hashrefs UNLESS ID is passed,
#        in which case, return that single hashref
################################################################
sub List {
    my ($dbh, $args) = @_;

    my @basecolumns = qw(
        id
        name
        ismix
        created
        lastexport
        exportcount
    );

    my @aggregationcolumns = qw(
        artist
        artistlist
        maxrating
        maxenergy
        maxmood
        minrating
        minenergy
        minmood
        avgrating
        avgenergy
        avgmood
        completion
        total
        tags
        colors
        isstarred
    );

    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });

    my $sql = sprintf(qq{
            select
                %s, collection.songcount
            from (
                select
                    %s, count(*) songcount
                from
                    flavors_collection
                inner join flavors_songcollection on flavors_collection.id = flavors_songcollection.collectionid
                inner join (%s) flavors_song on flavors_song.id = flavors_songcollection.songid
                group by %s
            ) collection
            left join (
                select
                    flavors_collection.id as collectionid,
                    case 
                        when count(distinct artist) = 1 then max(artist)
                        else 'Various Artists'
                    end artist,
                    group_concat(distinct artist separator ' ') as artistlist,
                    max(rating) as maxrating,
                    max(energy) as maxenergy,
                    max(mood) as maxmood,
                    min(rating) as minrating,
                    min(energy) as minenergy,
                    min(mood) as minmood,
                    avg(rating) as avgrating,
                    avg(energy) as avgenergy,
                    avg(mood) as avgmood,
                    (count(rating) + count(energy) + count(mood)) / (count(*) * 3) as completion,
                    count(*) as total,
                    tags,
                    colors,
                    max(isstarred) as isstarred
                from
                    flavors_song, flavors_songcollection, flavors_collection
                left join (
                    select
                        flavors_songcollection.collectionid,
                        group_concat(distinct flavors_songtag.tag order by rand() separator '%s') as tags,
                        group_concat(distinct case when category = 'colors' then flavors_songtag.tag else null end order by rand() separator '%s') as colors
                    from flavors_songcollection, flavors_songtag
                    left join flavors_tagcategory on flavors_tagcategory.tag = flavors_songtag.tag
                    where flavors_songcollection.songid = flavors_songtag.songid
                    group by flavors_songcollection.collectionid
                ) tags on tags.collectionid = flavors_collection.id
                where
                    flavors_collection.id = flavors_songcollection.collectionid
                    and flavors_songcollection.songid = flavors_song.id
                group by flavors_collection.id
            ) aggregations on aggregations.collectionid = collection.id

        },
        join(", ", @basecolumns, @aggregationcolumns),
        join(", ", map { "flavors_collection." . $_ } @basecolumns),
        $songlist->{SQL},
        join(", ", map { "flavors_collection." . $_ } @basecolumns),
        $Flavors::Data::Util::SEPARATOR,
        $Flavors::Data::Util::SEPARATOR,
    );

    if ($args->{ID}) {
        $sql .= qq{
            where id = $args->{ID}
        };
    }
    elsif ($args->{SONGID}) {
        $sql .= qq{
            where songs.id = $args->{SONGID}
        };
    }

    $sql .= qq{
        order by collection.songcount / aggregations.total desc, created desc
    };

    my @results = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [@basecolumns, @aggregationcolumns, 'songcount'],
        GROUPCONCAT => ['tags', 'colors'],
        BINDS => $songlist->{BINDS},
    });

    if ($args->{ID}) {
        return $results[0];
    }
    else {
        return wantarray ? @results : \@results;
    }
}

################################################################
# Suggestions
#
# Description: Get a list of suggested collections
#
# Parameters
#        None
#
# Return Value: arrayref of hashrefs
################################################################
sub Suggestions {
    my ($dbh, $args) = @_;

    my $maxcollections = 24;
    my ($sec, $min, $hour, $monthday, $month, $year) = localtime();
    $year += 1900;

    my @clauses = ();

    # Collections with a starred song
    push(@clauses, qq{
            exists (
                select 1
                from flavors_song, flavors_songcollection
                where flavors_song.id = flavors_songcollection.songid
                and flavors_collection.id = flavors_songcollection.collectionid
                and song.isstarred = 1
            )
    });

    # Collections with a song tagged with the current season
    my @seasons = qw(winter spring summer autumn);
    my @months = qw(january february march april may june july august september october november december);
    my $seasonindex = $seasons[$month / 3];
    push(@clauses, sprintf(qq{
        exists (
            select 1
            from flavors_song, flavors_songcollection, flavors_songtag
            where flavors_song.id = flavors_songcollection.songid
            and flavors_collection.id = flavors_songcollection.collectionid
            and flavors_songtag.songid = flavors_song.id
            and flavors_songtag.tag in ('%s')
        )
        and exists (
        select 1
            from flavors_song, flavors_songcollection, flavors_songtag
            where flavors_song.id = flavors_songcollection.songid
            and flavors_collection.id = flavors_songcollection.collectionid
            and flavors_songtag.songid = flavors_song.id
            and flavors_songtag.tag in ('winter', 'january', 'february', 'march')
        )
        },
        $year,
        $seasons[$seasonindex],
        join(", ", map { sprintf("'%s'", $_) } $months[($seasonindex * 3) .. (($seasonindex + 1) * 3)]),
    ));

    # Recently acquired collections
    push(@clauses, "1 = 1");

    my $collections = {};
    while (@clauses && scalar(keys %$collections) < $maxcollections) {
        my $sql = sprintf(qq{
            select 
                flavors_collection.id,
                flavors_collection.name
            from
                flavors_collection
            where
                %s
            order by created desc
            limit %s
            },
            pop(@clauses),
            $maxcollections,
        );

        my @newcollections = Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            COLUMNS => [qw(id name)],
        });
        foreach my $new (@newcollections) {
            $collections->{$new->{NAME}} = $new->{ID};
        }
    }

    # Sort alphabetically
    my @collections = ();
    foreach my $name (sort keys %$collections) {
        push(@collections, {
            ID => $collections->{$name},
            NAME => $name,
        });
    }

    return \@collections;
}

################################################################
# TrackList
#
# Description: Get a list of songs in a given collection(s)
#
# Parameters
#        COLLECTIONIDS: comma-separated string
#
# Return Value: array of hashrefs
################################################################
sub TrackList {
    my ($dbh, $args) = @_;

    my $sql = qq{
        select 
            flavors_songcollection.collectionid,
            flavors_song.id, 
            flavors_song.name, 
            flavors_song.artist,
            flavors_songcollection.tracknumber,
            flavors_song.filename,
            flavors_song.rating,
            flavors_song.energy,
            flavors_song.mood,
            flavors_song.isstarred,
            flavors_songtaglist.taglist
        from 
            flavors_songcollection
        inner join flavors_song on flavors_song.id = flavors_songcollection.songid
        left join flavors_songtaglist on flavors_songtaglist.songid = flavors_song.id
    };

    if ($args->{COLLECTIONIDS}) {
        $sql .= qq{
            where 
                flavors_songcollection.collectionid in ($args->{COLLECTIONIDS})
        };
    }

    $sql .= qq{
        order by 
            flavors_songcollection.collectionid,
            flavors_songcollection.tracknumber
    };

    my @rows = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(collectionid id name artist tracknumber filename rating energy mood isstarred taglist)],
    });
    return wantarray ? @rows : \@rows;
}

################################################################
# CoverArtFilename
#
# Description: Get filename for cover art image.
#
# Parameters
#       ID: collection
#       EXT: filetype extension (defaults to png)
#
# Return Value: string
################################################################
sub CoverArtFilename {
    my ($args) = @_;
    $args->{EXT} ||= "png";
    return "images/collections/" . $args->{ID} . "." . lc($args->{EXT});
}

################################################################
# UpdateCoverArt
#
# Description: Save a new image file as a collections' cover art.
#
# Parameters
#       ID: collection to update
#       FILE: file handle
#       EXT: file extension
#
# Return Value: none
################################################################
sub UpdateCoverArt {
    my ($dbh, $args) = @_;

    my $fh = $args->{FILE};
    my $filename = CoverArtFilename({ ID => $args->{ID}, EXT => $args->{EXT} });

    my $buffer;
    open(OUTPUT, ">" . $filename) || die "Can't create local file $filename: $!";

    binmode($fh);
    binmode(OUTPUT);

    while (read($fh, $buffer, 16384)) {
        print OUTPUT $buffer;
    }

    return { FILENAME => $filename };
}

1;
