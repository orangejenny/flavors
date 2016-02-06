package Flavors::Data::Tag;

use strict;
use Flavors::Data::Util;

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
            song.artist,
            artistgenre.genre
        from
            song
            left join artistgenre on artistgenre.artist = song.artist
        order by
            artistgenre.artist
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
        SQL => "select distinct category from tagcategory;",
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
    my @binds = ();
    my $isgenre = $category =~ m/genre/i;

    my $tagcolumn = $isgenre ? "artistgenre.genre" : "songtag.tag";
    my $tables = $isgenre ? "artistgenre" : "songtag, tagcategory";
    my $joins = $isgenre
        ? "song.artist = artistgenre.artist"
        : "song.id = songtag.songid and songtag.tag = tagcategory.tag and tagcategory.category = ?"
    ;
    $sql = sprintf(qq{
            select partials.*
            from (
                select
                    %s as tag, %s, count(*) as count, group_concat(concat(song.artist, ' - ', song.name) separator '%s') as samples
                from song, %s
                where %s and %s is not null
                group by %s, %s
            ) partials, (
                select %s, %s as tag, count(*) as count
                from song, %s
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
        $Flavors::Data::Util::SEPARATOR,
        $tables,
        $joins,
        $args->{FACET},
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
    warn $sql;

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => \@binds,
        COLUMNS => [qw(tag rating count samples)],
        GROUPCONCAT => ['samples'],
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
            tagcategory
            left join color on tagcategory.tag = color.name
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
#        RELATED: only tags that appear in a song with this tag
#
# Return Value: array of hashrefs
################################################################
sub List {
    my ($dbh, $args) = @_;

    my $sql = qq{
        select
            songtag.tag,
            tagcategory.category,
            metacategory.metacategory,
            count(*) count
        from
            songtag
        left join tagcategory on tagcategory.tag = songtag.tag
        left join metacategory on tagcategory.category = metacategory.category
    };

    if ($args->{RELATED}) {
        $sql .= qq{
            where 
                songtag.tag <> '$args->{RELATED}'
                and exists (
                    select 
                        1
                    from 
                        songtag original
                    where 
                        original.songid = songtag.songid
                        and original.tag = '$args->{RELATED}'
                )
        };
    }

    $sql .= qq{
        group by
            songtag.tag, 
            tagcategory.category
        order by
            count(*) desc,
            tag
    };

    my @results = Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(tag category metacategory count)],
    });
    return wantarray ? @results : \@results;
}

################################################################
# SeasonStats
#
# Description: Get season-based song counts
#
# Args:
#    None
#
# Return Value: hashref with keys years, values hashrefs of form
#    { 'winter' => number, 'spring' => number, ... }
################################################################
sub SeasonStats {
    my ($dbh) = @_;

    my $sql = sprintf(qq{
        select count(distinct id), year, season, group_concat(name separator'%s') from (
            select 
                seasons.name,
                years.id, 
                case
                    when seasons.tag = 'december' then years.year + 1
                    else years.year
                end as year,
                seasons.season from (
                    select song.id, tagcategory.tag as year
                    from song, songtag, tagcategory
                    where song.id = songtag.songid
                    and songtag.tag = tagcategory.tag
                    and category = 'years'
                ) years, (
                    select 
                        song.id, 
                        tagcategory.tag,
                        concat(song.artist, ' - ', song.name) as name,
                        case
                            when tagcategory.tag in ('winter', 'december', 'january', 'february') then 0
                            when tagcategory.tag in ('spring', 'march', 'april', 'may') then 1
                            when tagcategory.tag in ('summer', 'june', 'july', 'august') then 2
                            when tagcategory.tag in ('autumn', 'september', 'october', 'november') then 3
                            else tagcategory.tag 
                        end as season
                    from song, songtag, tagcategory
                    where song.id = songtag.songid
                    and songtag.tag = tagcategory.tag
                    and category in ('seasons', 'months')
                ) seasons
            where years.id = seasons.id
        ) stats
        group by year, season
        order by year, season;
    }, $Flavors::Data::Util::SEPARATOR);

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(count year season samples)],
        GROUPCONCAT => ['samples'],
    })];
}

################################################################
# TimelineStats
#
# Description: Get year-based and season-based counts
#
# Args:
#    None
#
# Return Value: hashref with keys YEARS and SEASONS, values the
#    return values of YearStats and SeasonStats, respectively
################################################################
sub TimelineStats {
    my ($dbh) = @_;

    return {
        YEARS => YearStats($dbh),
        SEASONS => SeasonStats($dbh),
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
# UpdateColor
#
# Description: Update color row
#
# Args:
#    NAME (required)
#    HEX (optional)
#    WHITETEXT (optional)
#
# Return value: none
################################################################
sub UpdateColor {
    my ($dbh, $args) = @_;

    my @colors = Flavors::Data::Util::Results($dbh, {
        SQL => qq{ select * from color where name = ? },
        BINDS => [$args->{NAME}],
        COLUMNS => [qw(name, hex, whitetext)],
    });

    my $sql;
    my @binds;
    if (scalar(@colors)) {
        my @clauses;
        foreach my $column(qw(HEX WHITETEXT)) {
            if (exists $args->{$column}) {
                push(@clauses, "$column = ?");
                push(@binds, $args->{$column});
            }
        }
        $sql .= "update color set " . join(", ", @clauses) . ", updated = now() where name = ?";
    }
    else {
        push(@binds, $args->{HEX} || "000000");
        push(@binds, $args->{WHITETEXT} || 0);
        $sql .= "insert into color (hex, whitetext, name, created, updated) values (?, ?, ?, now(), now());";
    }
    push (@binds, $args->{NAME});

    Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        BINDS => \@binds,
        SKIPFETCH => 1,
    });
}

################################################################
# YearStats
#
# Description: Get year-based song counts
#
# Args:
#    None
#
# Return Value: hashref with keys years, values counts
################################################################
sub YearStats {
    my ($dbh) = @_;

    my $sql = sprintf(qq{
        select
            tagcategory.tag,
            count(*) count,
            group_concat(concat(song.artist, ' - ', song.name) separator '%s')
        from song, songtag, tagcategory
        where song.id = songtag.songid
        and songtag.tag = tagcategory.tag
        and category = 'years'
        group by tagcategory.tag
        order by tagcategory.tag;
    }, $Flavors::Data::Util::SEPARATOR);

    return [Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(year count samples)],
        GROUPCONCAT => ['samples'],
    })];
}

1;
