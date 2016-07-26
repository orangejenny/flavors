package Flavors::Data::Collection;

use strict;
use Flavors::Data::Util;

my $COVER_ART_ROOT = "images/collections/";

################################################################
# AcquisitionStats
#
# Description: Get stats related to song acquisition
#
# Args: None
#
# Return Value: arrayref of hashrefs:
#    DATESTRING: YYYY-MM
#    COUNT
################################################################
sub AcquisitionStats {
    my ($dbh) = @_;

    my $sql = sprintf(qq{
        select date_format(created, '%%Y-%%m') datestring, count(*) count,
        group_concat(concat(artist, ' - ', collection.name) separator '%s') samples
        from (
            select collection.name, collection.created, case when count(distinct artist) = 1 then min(artist) else 'Various' end artist
            from collection, songcollection, song
            where songcollection.collectionid = collection.id
            and songcollection.songid = song.id
            group by collection.id, collection.created
        ) collection
        group by date_format(created, '%%Y-%%m')
    }, $Flavors::Data::Util::SEPARATOR);

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(datestring count samples)],
        GROUPCONCAT => ['samples'],
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
        SQL => qq{ select max(id) id from collection },
        COLUMNS => ['id'],
    });
    my $collectionid = $ids[0]->{ID} + 1;
    my $sql = qq{
        insert into collection (id, name, ismix, created, exportcount, updated)
        values (?, ?, ?, now(), 0, now())
    };
    Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => [$collectionid, $args->{NAME}, $args->{ISMIX} ? 1 : 0],
        SKIPFETCH => 1,
    });

    # Add songs
    my @songids = Flavors::Data::Util::Results($dbh, {
        SQL => qq{ select max(id) id from song },
        COLUMNS => ['id'],
    });
    my $lastid = $songids[0]->{ID} + 1;
    my $firstid = $lastid;
    foreach my $song (@songs) {
        my $sql = qq{
            insert into song (id, name, artist, time, ispurchased, filename, created, updated)
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
        insert into songcollection (songid, collectionid, tracknumber, created, updated)
        select id, ?, id - ?, now(), now()
        from song
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
#        SONGID: only collections that include this song
#
# Return Value: array/arrayref of hashrefs UNLESS ID is passed,
#        in which case, return that single hashref
################################################################
sub List {
    my ($dbh, $args) = @_;

    my @collectioncolumns = ListColumns();

    my $sql = sprintf(qq{
        select
            %s
        from
            collection
        inner join (
            select 
                collectionid, 
                max(rating) maxrating, 
                max(energy) maxenergy, 
                max(mood) maxmood,
                min(rating) minrating, 
                min(energy) minenergy, 
                min(mood) minmood,
                avg(rating) avgrating, 
                avg(energy) avgenergy, 
                avg(mood) avgmood,
                min(year) minyear,
                max(year) maxyear,
                (count(rating) + count(energy) + count(mood)) / (count(*) * 3) completion,
                max(isstarred) isstarred
            from 
                songcollection
                inner join song on song.id = songcollection.songid
                inner join collection on collection.id = songcollection.collectionid
            group by 
                songcollection.collectionid
        ) ratings on ratings.collectionid = collection.id
        inner join (
            select 
                collectionid,
                group_concat(distinct artist separator ' ') as artistlist,
                case 
                    when count(distinct artist) = 1 then max(artist)
                    else 'Various Artists'
                end artist
            from 
                songcollection
                inner join song on song.id = songcollection.songid
            group by 
                collectionid
        ) artist on artist.collectionid = collection.id
        left join (
            select 
                collectionid, 
                substring_index(group_concat(genre order by num desc separator ','), ',', 1) as genre
            from (
                select 
                    collectionid, 
                    genre, 
                    count(*) num
                from 
                    songcollection
                    inner join song on song.id = songcollection.songid
                    inner join artistgenre on artistgenre.artist = song.artist
                group by 
                    collectionid, 
                    genre
            ) genre
            group by 
                collectionid
        ) genre on genre.collectionid = collection.id
        left join (
            select
                collectionid,
                group_concat(distinct tag order by rand() separator '%s') as tags
            from
                songcollection
                inner join songtag on songcollection.songid = songtag.songid
            group by
                collectionid
        ) tags on tags.collectionid = collection.id
        left join (
            select 
                collectionid, 
                substring_index(group_concat(tag order by num desc separator ' '), ' ', 1) as color
            from (
                select 
                    collectionid, 
                    songtag.tag, 
                    count(*) num
                from 
                    songcollection
                    inner join song on song.id = songcollection.songid
                    inner join songtag on songtag.songid = song.id
                    inner join tagcategory on songtag.tag = tagcategory.tag
                where
                    category = 'colors'
                group by 
                    collectionid, tag
            ) color
            group by collectionid
        ) color on color.collectionid = collection.id
    }, join(", ", @collectioncolumns), $Flavors::Data::Util::SEPARATOR);

    if ($args->{ID}) {
        $sql .= qq{
            where id = $args->{ID}
        };
    }
    elsif ($args->{SONGID}) {
        $sql .= qq{
            where
                exists (
                    select
                        1
                    from
                        songcollection
                    where
                        songcollection.collectionid = collection.id
                        and songcollection.songid = $args->{SONGID}
                )
        };
    } elsif ($args->{FILTER}) {
        $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
        $sql .= " where (" . $args->{FILTER} . ")";
    }

    $sql .= qq{
        order by created desc
    };

    my @results = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => \@collectioncolumns,
        GROUPCONCAT => ['tags'],
    });

    if ($args->{ID}) {
        return $results[0];
    }
    else {
        return wantarray ? @results : \@results;
    }
}

################################################################
# ListColumns
#
# Description: Get the column list used by the List method.
#
# Return Value: array/arrayref of strings
################################################################
sub ListColumns {
    my @columns = qw(
        id
        name
        artist
        artistlist
        ismix
        created
        minrating
        minenergy
        minmood
        maxrating
        maxenergy
        maxmood
        avgrating
        avgenergy
        avgmood
        minyear
        maxyear
        completion
        isstarred
        genre
        color
        tags
        lastexport
        exportcount
    );
    return wantarray ? @columns : \@columns;
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
                from song, songcollection
                where song.id = songcollection.songid
                and collection.id = songcollection.collectionid
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
            from song, songcollection, songtag
            where song.id = songcollection.songid
            and collection.id = songcollection.collectionid
            and songtag.songid = song.id
            and songtag.tag in ('%s')
        )
        and exists (
        select 1
            from song, songcollection, songtag
            where song.id = songcollection.songid
            and collection.id = songcollection.collectionid
            and songtag.songid = song.id
            and songtag.tag in ('winter', 'january', 'february', 'march')
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
                collection.id,
                collection.name
            from
                collection
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
            songcollection.collectionid,
            song.id, 
            song.name, 
            song.artist,
            songcollection.tracknumber,
            song.filename,
            song.rating,
            song.energy,
            song.mood,
            songtaglist.taglist as tags
        from 
            songcollection
        inner join song on song.id = songcollection.songid
        left join songtaglist on songtaglist.songid = song.id
    };

    if ($args->{COLLECTIONIDS}) {
        $sql .= qq{
            where 
                songcollection.collectionid in ($args->{COLLECTIONIDS})
        };
    }

    $sql .= qq{
        order by 
            songcollection.collectionid,
            songcollection.tracknumber
    };

    my @rows = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(collectionid id name artist tracknumber filename rating energy mood tags)],
    });
    return wantarray ? @rows : \@rows;
}

################################################################
# CoverArtFiles
#
# Description: Get filenames for cover art images.
#
# Parameters
#       ID: collection
#
# Return Value: string
################################################################
sub CoverArtFiles {
    my ($id) = @_;
    my @files = ();
    my $dir = $COVER_ART_ROOT . $id;
    if (opendir my $handle, $dir) {
        @files = grep { /^[^.]/ && -e "$dir/$_" } readdir $handle;
        closedir $handle;
    }
    @files = map { $COVER_ART_ROOT . $id . "/" . $_ } @files;
    return @files;
}

################################################################
# RemoveCoverArt
#
# Description: Remove a given image ad cover art.
#
# Parameters
#       ID: collection to update
#       FILENAME: file to remove
#
# Return Value: none
################################################################
sub RemoveCoverArt {
    my ($dbh, $args) = @_;
    my @files = CoverArtFiles($args->{ID});
    foreach my $file (@files) {
        if ($file eq $args->{FILENAME}) {
            if (unlink $file) {
                return { FILENAME => $args->{FILENAME} };
            }
        }
    }
    return { FILENAME => ''};
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

    my $dir = $COVER_ART_ROOT . $args->{ID};
    if (opendir my $handle, $dir) {
        closedir $handle;
    } else {
        mkdir $dir;
    }

    my $fh = $args->{FILE};
    my @files = CoverArtFiles($args->{ID});
    my $filename = sprintf("%s/%s.%s", $dir, @files + 1, $args->{EXT});

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
