package Flavors::Data::Song;

use strict;
use Flavors::Data::Playlist;
use Flavors::Data::Util;

################################################################
# Count
#
# Description: Count a set of songs.
#
# Parameters (optional)
#        FILTER: where clause (limited to song table)
#
# Return Value: array/arrayref of hashrefs UNLESS ID is passed,
#        in which case, return the single hashref
################################################################
sub Count {
    my ($dbh, $args) = @_;

    my $sql = "select count(*) from flavors_song";

    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
    if ($args->{FILTER}) {
        $sql .= " where (" . $args->{FILTER} . ")";
    }

    my @rows = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => ['COUNT'],
    });

    return $rows[0]->{COUNT};
}

################################################################
# List
#
# Description: Get a list of songs
#
# Parameters (optional)
#        FILTER: additional where clause
#        ID: only this song
#        ORDERBY: order by this column (may include "desc")
#        SIMPLEFILTER: string to apply against name, artist, and 
#            collection names (disjunctive)
#       SQLONLY: if true, return sql query, not results
#       STARRED: limit to starred songs
#       UPDATEPLAYLIST: if true, update songs playlists with
#           given filter
#
# Return Value: array/arrayref of hashrefs UNLESS ID is passed,
#        in which case, return the single hashref
################################################################
sub List {
    my ($dbh, $args) = @_;

    $args->{ORDERBY} = Flavors::Util::Sanitize($args->{ORDERBY});

    my @songcolumns = Flavors::Data::Song::ColumnList();

    my $sql = sprintf(qq{
        select distinct
            %s,
            flavors_artistgenre.genre,
            flavors_songlyrics.lyrics,
            case when flavors_songlyrics.lyrics is null then 0 else 1 end as haslyrics,
            concat(' ', flavors_songtaglist.taglist, ' ') as taglist,
            group_concat(flavors_collection.name order by flavors_collection.created separator '%s') as collections,
            coalesce(flavors_songtaglist.tagcount, 0) as tagcount,
            years.minyear,
            years.maxyear,
            min(flavors_collection.created) as mincollectioncreated,
            max(flavors_collection.created) as maxcollectioncreated,
            tracks.tracknumber,
            flavors_song.exportcount,
            flavors_song.lastexport
        from 
            flavors_song
        left join flavors_songcollection on flavors_song.id = flavors_songcollection.songid
        left join flavors_collection on flavors_songcollection.collectionid = flavors_collection.id
        left join flavors_songtaglist on flavors_song.id = flavors_songtaglist.songid
        left join flavors_artistgenre on flavors_artistgenre.artist = flavors_song.artist
        left join flavors_songlyrics on flavors_songlyrics.songid = flavors_song.id
        left join (
            select
                flavors_songtag.songid,
                min(flavors_songtag.tag) minyear,
                max(flavors_songtag.tag) maxyear
            from
                flavors_songtag,
                flavors_tagcategory
            where
                flavors_songtag.tag = flavors_tagcategory.tag
                and flavors_tagcategory.category = 'years'
            group by
                flavors_songtag.songid
        ) years on years.songid = flavors_song.id
        left join (
            select songid, tracknumber 
            from flavors_songcollection outersongcollection, flavors_collection 
            where outersongcollection.collectionid = flavors_collection.id 
            and flavors_collection.created = (
                select max(flavors_collection.created) 
                from flavors_collection, flavors_songcollection innersongcollection 
                where innersongcollection.songid = outersongcollection.songid
                and flavors_collection.id = collectionid
            )
        ) tracks on tracks.songid = flavors_song.id
    }, join(", ", map { "flavors_song." . $_ } @songcolumns), $Flavors::Data::Util::SEPARATOR);

    if ($args->{ID}) {
        $sql .= " where flavors_song.id = $args->{ID}";
    }

    $sql .= " group by flavors_song.id ";

    $sql = "select * from ($sql) flavors_song where 1 = 1";
    my @binds;
    if ($args->{SIMPLEFILTER}) {
        my @tokens = grep { $_ } split(/\s+/, $args->{SIMPLEFILTER});
        my @conditions = [];
        foreach my $token (@tokens) {
            $sql .= qq{ 
                and (
                    name like concat('%', ?, '%')
                    or artist like concat('%', ?, '%')
                    or taglist like concat('%', ?, '%')
                    or exists (
                        select 1 from flavors_collection, flavors_songcollection
                        where flavors_collection.id = flavors_songcollection.collectionid
                        and flavors_song.id = flavors_songcollection.songid
                        and concat(' ', flavors_collection.name, ' ') like concat(' %', ?, '% ')
                    )
                )
            };
            push(@binds, $token, $token, $token, $token);
        }
    }

    my $filter = $args->{FILTER};
    my %replacements = (
        'quality' => 'rating > 3',
        'decent' => 'rating > 2',
        'slow' => 'energy < 3',
        'mellow' => 'energy < 3',
        'energetic' => 'energy > 3',
        'sad' => 'mood < 3',
        'angry' => 'mood < 3',
        'unhappy' => 'mood < 3',
        'happy' => 'mood > 3',
        'unrated' => 'mood is null or energy is null or rating is null',
        'before' => 'minyear < ',
        'after' => 'maxyear > ',
        'starred' => 'isstarred = 1',
    );
    foreach my $find (keys %replacements) {
        $filter =~ s/\b$find\b/$replacements{$find}/g;
    }

    $filter =~ s/\[([^]]*)]/taglist like '% $1 %'/g;

    $filter = Flavors::Util::Sanitize($filter);
    if ($filter) {
        $sql .= " and (" . $filter . ")";
    }

    if ($args->{STARRED}) {
        $sql .= " and isstarred = 1";
    }

    if ($args->{SQLONLY}) {
        return {
            SQL => $sql,
            BINDS => \@binds,
        }
    }

    $sql .= " order by " . ($args->{ORDERBY} ? $args->{ORDERBY} : "maxcollectioncreated desc, tracknumber");

    my @results = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [Flavors::Data::Song::FullColumnList()],
        GROUPCONCAT => ['collections'],
        BINDS => \@binds,
    });

    if ($args->{UPDATEPLAYLIST}) {
        Flavors::Data::Playlist::Update($dbh, {
            FILTER => $args->{FILTER},
        });
    }

    if ($args->{ID}) {
        return $results[0];
    }
    else {
        return wantarray ? @results : \@results;
    }
}

sub FullColumnList {
    my @columns = Flavors::Data::Song::ColumnList();
    push(@columns, qw(
        genre
        lyrics
        haslyrics
        taglist
        collections
        tagcount
        minyear
        maxyear
        mincollectioncreated
        maxcollectioncreated
        tracknumber
        exportcount
        lastexport
    ));
    return @columns;
}

sub ColumnList {
    return qw(
        id
        name
        artist
        rating
        energy
        mood
        language
        year
        time
        ispurchased
        isstarred
        filename
        echonestid
    );
}

################################################################
# Stats
#
# Description: Get statistics, by song
#
# Args:
#    FILTER
#    GROUPBY: CSV of strings, each one of qw(rating energy mood)
#    UPDATEPLAYLIST
#
# Return Value: arrayref of hashrefs, each with a count and
#    a value for each grouped-by attribute
################################################################
sub Stats {
    my ($dbh, $args) = @_;
    my @groupby = map { uc $_ } split(/\s*,\s*/, Flavors::Util::Sanitize($args->{GROUPBY}));
    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});

    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });

    my $sql = sprintf(qq{
            select 
                %s, 
                count(*)
            from
                (%s) flavors_song
            where 1 = 1
            group by %s
            order by %s;
        },
        join(", ", map { sprintf("coalesce(%s, 0)", $_) } @groupby),
        $songlist->{SQL},
        join(", ", @groupby),
        join(", ", @groupby),
    );
    my @results = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [@groupby, 'count'],
        BINDS => $songlist->{BINDS},
    });

    # Fill in zeroes: expand query into data structure that has a place for every rating (0-5)
    my @allresults = ({ COUNT => 0 });
    foreach my $column (@groupby) {
        my @expandedresults = ();
        foreach my $rating (0..5) {
            foreach my $result (@allresults) {
                push(@expandedresults, {
                    %$result,
                    $column => $rating,
                });
            }
        }
        @allresults = @expandedresults;
    }

    foreach my $result (@results) {
        foreach my $allresult (@allresults) {
            if (!scalar(grep { $allresult->{$_} != $result->{$_} } @groupby)) {
                $allresult->{COUNT} = $result->{COUNT};
            }
        }
    }

    return wantarray ? @allresults : \@allresults;
}

################################################################
# Update
#
# Description: Update given song
#
# Parameters (optional except for ID)
#        ID
#        NAME, ARTIST, RATING, ENERGY, MOOD, ISSTARRED, ECHONESTID
#        TAGS
#
# Return Value: array of hashrefs
################################################################
sub Update {
    my ($dbh, $newsong) = @_;

    my $id = delete $newsong->{ID};
    my $oldsong = List($dbh, { ID => $id });

    # song table
    my @updatefields = qw(NAME ARTIST RATING ENERGY MOOD YEAR ISSTARRED ECHONESTID);
    my @updates;
    my @binds;
    foreach my $key (@updatefields) {
        if (exists $newsong->{$key}) {
            push @updates, "$key = ?";
            push @binds, $newsong->{$key};
        }
    }

    if (@updates) {
        my $sql = sprintf(qq{
            update
                flavors_song
            set
                %s, updated = now()
            where
                id = %s
        }, join(", ", @updates), $id);
        Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            BINDS => \@binds,
            SKIPFETCH => 1,
        });
    }

    # genre
    if (exists $newsong->{GENRE} && $newsong->{GENRE} ne $oldsong->{GENRE}) {
        my $sql = $oldsong->{GENRE}
            ? "update flavors_artistgenre set genre = ?, updated = now() where artist = ?"
            : "insert into flavors_artistgenre (genre, artist, created) values (?, ?, now())"
        ;
        Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            BINDS => [$newsong->{GENRE}, $oldsong->{ARTIST}],
            SKIPFETCH => 1,
        });
    }

    # tag table
    if (exists $newsong->{TAGS}) {
        my @oldtags = Flavors::Data::Util::Results($dbh, {
            SQL => qq{ select tag from flavors_songtag where songid = $id },
            COLUMNS => [qw(tag)],
        });
        @oldtags = map { $_->{TAG} } @oldtags;
        my @newtags = split(/\s+/, $newsong->{TAGS});
        my @tagstoadd = Flavors::Util::ArrayDifference(\@newtags, \@oldtags);
        my @tagstoremove = Flavors::Util::ArrayDifference(\@oldtags, \@newtags);

        foreach my $tag (@tagstoadd) {
            Flavors::Data::Util::Results($dbh, {
                SQL => qq{
                    insert into flavors_songtag (songid, tag, created, updated) values (?, ?, now(), now())
                },
                BINDS => [$id, $tag],
                SKIPFETCH => 1,
            });
        }

        if (@tagstoremove) {
            Flavors::Data::Util::Results($dbh, {
                SQL => sprintf(qq{
                    delete from flavors_songtag where songid = ? and tag in (%s)
                }, join(", ", map { '?' } @tagstoremove)),
                BINDS => [$id, @tagstoremove],
                SKIPFETCH => 1,
            });
        }
    }

    return { ID => $id };
}

################################################################
# UpdateExport
#
# Description: Update exportcount and lastexport
#
# Parameters (optional):
#    SONGIDS: arrayref
#    COLLECTIONIDS: arrayref
#
# Return Value: none
################################################################
sub UpdateExport {
    my ($dbh, $args) = @_;

    if ($args->{SONGIDS}) {
        my $sql = sprintf(qq{
            update flavors_song
            set
                lastexport = now(),
                exportcount = exportcount + 1,
                updated = now()
            where id in (%s)
        }, join(", ", map { '?' } @{ $args->{SONGIDS} }));
        Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            BINDS => $args->{SONGIDS},
            SKIPFETCH => 1,
        });
    }

    if ($args->{COLLECTIONIDS}) {
        my $sql = sprintf(qq{
            update flavors_collection
            set
                lastexport = now(),
                exportcount = exportcount + 1,
                updated = now()
            where id in (%s)
        }, join(", ", map { '?' } @{ $args->{COLLECTIONIDS} }));
        Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            BINDS => $args->{COLLECTIONIDS},
            SKIPFETCH => 1,
        });
    }

    return;
}

################################################################
# Lyrics
#
# Description: Get song's lyrics
#
# Parameters:
#    ID: int
#
# Return Value: none
################################################################
sub Lyrics {
    my ($dbh, $args) = @_;

    my @rows = Flavors::Data::Util::Results($dbh, {
        SQL => "select lyrics from flavors_songlyrics where songid = ?",
        BINDS => [$args->{ID}],
        COLUMNS => ['LYRICS'],
    });
    return { LYRICS => scalar(@rows) ? $rows[0]->{LYRICS} : "" };
}

################################################################
# UpdateLyrics
#
# Description: Update song's lyrics
#
# Parameters:
#    ID: int
#    LYRICS: string
#
# Return Value: none
################################################################
sub UpdateLyrics {
    my ($dbh, $args) = @_;
    $args->{LYRICS} = Flavors::Util::Sanitize($args->{LYRICS});

    my @rows  = Flavors::Data::Util::Results($dbh, {
        SQL => "select count(*) as count from flavors_songlyrics where songid = ?",
        BINDS => [$args->{ID}],
        COLUMNS => ['COUNT'],
    });
    my $count = $rows[0]->{COUNT};

    my $sql = $count
        ? "update flavors_songlyrics set lyrics = ? where songid = ?"
        : "insert into flavors_songlyrics (lyrics, songid) values (?, ?)"
    ;

    Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => [$args->{LYRICS}, $args->{ID}],
        SKIPFETCH => 1,
    });

    return {};
}

1;
