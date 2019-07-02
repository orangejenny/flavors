package Flavors::Data::Tag;

use strict;
use Flavors::Data::Util;
use Flavors::Data::Song;

################################################################
# ArtistGenreList
#
# Description: Get mapping of artists to genres
#
# Return Value: array of hashrefs
################################################################
sub ArtistGenreList {
    my ($dbh, $args) = @_;

    my $sql = qq{
        select distinct
            flavors_song.artist,
            flavors_artistgenre.genre
        from
            flavors_song
            left join flavors_artistgenre on flavors_artistgenre.artist = flavors_song.artist
        order by
            flavors_artistgenre.artist
    };

    return Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(tag category)],
    });
}

################################################################
# CategoryList
#
# Description: Get list of all tag categories
#
# Return Value: array of strings
################################################################
sub CategoryList {
    my ($dbh, $args) = @_;

    return map { $_->{CATEGORY} } Flavors::Data::Util::Results($dbh, {
        SQL => "select distinct category from flavors_tagcategory;",
        COLUMNS => [qw(category)],
    });
}

################################################################
# CategoryStats
#
# Description: Get statistics, by category
#
# Args:
#    FACET: one of qw(rating energy mood)
#    FILTER
#    CATEGORY: string, may be 'genres'
#
# Return Value: array of hashrefs, each containing
#    TAG: string
#    VALUES: arrayref of length 5, each a count mapping to index + 1
################################################################
sub CategoryStats {
    my ($dbh, $args) = @_;
    my $facet = Flavors::Util::Sanitize($args->{FACET});
    my $category = Flavors::Util::Sanitize($args->{CATEGORY});
    my $sql;
    my $isgenre = $category =~ m/genre/i;
    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});

    my $tagcolumn = $isgenre ? "flavors_artistgenre.genre" : "flavors_songtag.tag";
    my $tables = $isgenre ? "flavors_artistgenre" : "flavors_songtag, flavors_tagcategory";
    my $joins = $isgenre
        ? "flavors_song.artist = flavors_artistgenre.artist"
        : "flavors_song.id = flavors_songtag.songid and flavors_songtag.tag = flavors_tagcategory.tag and flavors_tagcategory.category = ?"
    ;
    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });
    my @binds = @{ $songlist->{BINDS} };
    $sql = sprintf(qq{
            select partials.*
            from (
                select
                    %s as tag, %s, count(*) as count
                from (%s) flavors_song, %s
                where %s and %s is not null
                %s
                group by %s, %s
            ) partials, (
                select %s, %s as tag, count(*) as count
                from flavors_song, %s
                where %s and %s is not null
                group by %s, %s
            ) totals
            where partials.tag = totals.tag
            and partials.%s = totals.%s
            order by totals.count desc, %s;
        }, 
        # partials
        $tagcolumn,
        $args->{FACET},
        $songlist->{SQL},
        $tables,
        $joins,
        $args->{FACET},
        $args->{FILTER} ? sprintf("and (%s)", $args->{FILTER}) : "",
        $tagcolumn,
        $args->{FACET},
        # totals
        $args->{FACET},
        $tagcolumn,
        $tables,
        $joins,
        $args->{FACET},
        $tagcolumn,
        $args->{FACET},
        $args->{FACET},
        $args->{FACET},
        $args->{FACET},
    );
    if (!$isgenre) {
        push(@binds, $args->{CATEGORY}, $args->{CATEGORY});
    }

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => \@binds,
        COLUMNS => [qw(tag rating count)],
    })];
}

################################################################
# ColorList
#
# Description: Get list of color tags and their details
#
# Return Value: hashref of hashrefs
################################################################
sub ColorList {
    my ($dbh, $args) = @_;

    my $sql = qq{
        select
            tag as name,
            hex,
            whitetext
        from
            flavors_tagcategory
            left join flavors_color on flavors_tagcategory.tag = flavors_color.name
        where
            category = 'colors'
        order by
            hex desc
    };

    return Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(name hex whitetext)],
    });
}

################################################################
# List
#
# Description: Get a list of tags
#
# Parameters (optional)
#        FILTER
#        RELATED: only tags that appear in a song with this tag
#        UPDATEPLAYLIST
#
# Return Value: array of hashrefs
################################################################
sub List {
    my ($dbh, $args) = @_;
    $args ||= {};

    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });
    my $sql = sprintf(qq{
            select
                flavors_songtag.tag,
                flavors_tagcategory.category,
                flavors_metacategory.metacategory,
                count(*) count
            from
                flavors_songtag
            inner join (%s) flavors_song on flavors_songtag.songid = flavors_song.id
            left join flavors_tagcategory on flavors_tagcategory.tag = flavors_songtag.tag
            left join flavors_metacategory on flavors_tagcategory.category = flavors_metacategory.category
            where 1=1
        },
        $songlist->{SQL},
    );

    if ($args->{RELATED}) {
        $sql .= qq{
            and
                flavors_songtag.tag <> '$args->{RELATED}'
                and exists (
                    select 
                        1
                    from 
                        flavors_songtag original
                    where 
                        original.songid = flavors_songtag.songid
                        and original.tag = '$args->{RELATED}'
                )
        };
    }

    if ($args->{FILTER}) {
        $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
        $sql .= sprintf("and (%s)", $args->{FILTER});
    }

    $sql .= qq{
        group by
            flavors_songtag.tag, 
            flavors_tagcategory.category
        order by
            count(*) desc,
            tag
    };

    my @results = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(tag category metacategory count)],
        BINDS => $songlist->{BINDS},
    });
    return wantarray ? @results : \@results;
}

################################################################
# NetworkStats
#
# Description: Get statistics on tag network
#
# Args (optional):
#    STRENGTH: minimum number of co-occurence to include link
#    CATEGORY: string
#    FILTER
#    UPDATEPLAYLIST
#
# Return Value: hashref containing
#    NODES: arrayref of hashrefs, each containing
#           source: a tag
#           target: another tag
#           value: number of times source and target occur in the same song
#    LINKS: arrayref of hashrefs, each containing
#           id: tag
#           count: total number of songs containing tag
#           group: integer id, mapping to a category
################################################################
sub NetworkStats {
    my ($dbh, $args) = @_;

    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
    my $strength = $args->{STRENGTH} || 1;
    my $categorywhere = "";
    if ($args->{CATEGORY}) {
        $categorywhere = "and flavors_tagcategory.category = ?";
    }
    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });
    my $sql = sprintf(qq{
            select flavors_songtag.songid, group_concat(flavors_songtag.tag separator '%s') tags
            from (%s) flavors_song, flavors_songtag, flavors_tagcategory
            where flavors_song.id = flavors_songtag.songid
            and flavors_songtag.tag = flavors_tagcategory.tag
            %s
            group by songid
        },
        $Flavors::Data::Util::SEPARATOR,
        $songlist->{SQL},
        $categorywhere,
    );

    my @binds = @{ $songlist->{BINDS} };
    if ($categorywhere) {
        push(@binds, $args->{CATEGORY});
    }
    my @rows = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(songid tags)],
        BINDS => \@binds,
        GROUPCONCAT => ['tags'],
    });
    my %pairs = {};
    foreach my $row (@rows) {
        my @tags = @{ $row->{TAGS} };
        while (scalar(@tags)) {
            my $source = pop @tags;
            foreach my $tag (@tags) {
                my $key = $tag < $source ? "$tag+$source" : "$source+$tag";
                if (!$pairs{$key}) {
                    $pairs{$key} = 0;
                }
                $pairs{$key}++;
            }
        }
    }
    my @links = ();
    my %tagstokeep = ();
    foreach my $key (keys %pairs) {
        if ($pairs{$key} >= $strength) {
            my @tags = split(/\+/, $key);
            $tagstokeep{$tags[0]} = 1;
            $tagstokeep{$tags[1]} = 1;
            push(@links, {
                source => $tags[0],
                target => $tags[1],
                value => $pairs{$key},
            });
        }
    }
    
    my @nodebinds = ();
    if ($categorywhere) {
        push(@nodebinds, $args->{CATEGORY});
    }
    my @nodes = Flavors::Data::Util::Results($dbh, {
        SQL => sprintf(qq{
            select flavors_tagcategory.tag, flavors_tagcategory.category, count(*) as songcount
            from flavors_tagcategory, flavors_songtag
            where flavors_songtag.tag = flavors_tagcategory.tag
            %s
            group by flavors_tagcategory.tag, flavors_tagcategory.category
        }, $categorywhere),
        COLUMNS => [qw(tag category count)],
        BINDS => \@nodebinds,
    });
    my $id = 1;
    @nodes = grep { $tagstokeep{$_->{TAG}} } @nodes;
    @nodes = map { { group => $id++, id => $_->{TAG}, count => $_->{COUNT} } } @nodes;
    
    return {
        nodes => \@nodes,
        links => \@links,
    };
}

################################################################
# SeasonStats
#
# Description: Get season-based song counts
#
# Args:
#    FILTER
#    SIMPLEFILTER
#    STARRED
#    UPDATEPLAYLIST
#
# Return Value: hashref with keys years, values hashrefs of form
#    { 'winter' => number, 'spring' => number, ... }
################################################################
sub SeasonStats {
    my ($dbh, $args) = @_;

    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });

    my $sql = sprintf(qq{
        select count(distinct id), year, season from(
            select 
                seasons.name,
                years.id, 
                case
                    when seasons.tag = 'december' then years.year + 1
                    else years.year
                end as year,
                seasons.season from (
                    select flavors_song.id, flavors_tagcategory.tag as year
                    from flavors_song, flavors_songtag, flavors_tagcategory
                    where flavors_song.id = flavors_songtag.songid
                    and flavors_songtag.tag = flavors_tagcategory.tag
                    and category = 'years'
                ) years, (
                    select 
                        flavors_song.id, 
                        flavors_tagcategory.tag,
                        concat(flavors_song.artist, ' - ', flavors_song.name) as name,
                        case
                            when flavors_tagcategory.tag in ('winter', 'december', 'january', 'february') then 0
                            when flavors_tagcategory.tag in ('spring', 'march', 'april', 'may') then 1
                            when flavors_tagcategory.tag in ('summer', 'june', 'july', 'august') then 2
                            when flavors_tagcategory.tag in ('autumn', 'september', 'october', 'november') then 3
                            else flavors_tagcategory.tag 
                        end as season
                    from flavors_song, flavors_songtag, flavors_tagcategory
                    where flavors_song.id = flavors_songtag.songid
                    and flavors_songtag.tag = flavors_tagcategory.tag
                    and category in ('seasons', 'months')
                ) seasons, (
                    %s
                ) flavors_song
            where years.id = seasons.id
            and flavors_song.id = years.id
        ) stats
        group by year, season
        order by year, season;
    }, $songlist->{SQL});

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(count year season)],
        BINDS => $songlist->{BINDS},
    })];
}

################################################################
# TimelineStats
#
# Description: Get year-based and season-based counts
#
# Args:
#    FILTER
#    SIMPLEFILTER
#    STARRED
#    UPDATEPLAYLIST
#
# Return Value: hashref with keys YEARS and SEASONS, values the
#    return values of YearStats and SeasonStats, respectively
################################################################
sub TimelineStats {
    my ($dbh, $args) = @_;

    return {
        YEARS => YearStats($dbh, $args),
        SEASONS => SeasonStats($dbh, $args),
    };
}

################################################################
# UpdateCategory
#
# Description: Update category for item
#
# Parameters:
#        VALUE
#        CATEGORY
#        TABLE
#        VALUECOLUMN
#        CATEGORYCOLUMN
#
# Return Value: none
################################################################
sub UpdateCategory {
    my ($dbh, $args) = @_;

    my $sql = "select $args->{CATEGORYCOLUMN} from $args->{TABLE} where $args->{VALUECOLUMN} = ?";
    my $currentrow = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => [$args->{VALUE}],
    });

    my $message;
    if ($currentrow) {
        $sql = "update $args->{TABLE} set $args->{CATEGORYCOLUMN} = ?, updated = now() where $args->{VALUECOLUMN} = ?";
        $message = "Moved";
    }
    else {
        $sql = "insert into $args->{TABLE} ($args->{CATEGORYCOLUMN}, $args->{VALUECOLUMN}, created, updated) values (?, ?, now(), now())";
        $message = "Added";
    }
    $message .= " $args->{VALUE} to $args->{CATEGORY}.";

    Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => [$args->{CATEGORY}, $args->{VALUE}],
        SKIPFETCH => 1,
    });

    return {
        MESSAGE => $message,
    };
}

################################################################
# YearStats
#
# Description: Get year-based song counts
#
# Args:
#    FILTER
#    SIMPLEFILTER
#    STARRED
#    UPDATEPLAYLIST
#
# Return Value: hashref with keys years, values counts
################################################################
sub YearStats {
    my ($dbh, $args) = @_;

    $args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
    my $songlist = Flavors::Data::Song::List($dbh, {
        %$args,
        SQLONLY => 1,
    });

    my $sql = sprintf(qq{
            select
                flavors_tagcategory.tag,
                count(*) count
            from (%s) flavors_song, flavors_songtag, flavors_tagcategory
            where flavors_song.id = flavors_songtag.songid
            and flavors_songtag.tag = flavors_tagcategory.tag
            and category = 'years'
            group by flavors_tagcategory.tag
            order by flavors_tagcategory.tag;
        },
        $songlist->{SQL},
    );

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(year count)],
        BINDS => $songlist->{BINDS},
    })];
}

1;
