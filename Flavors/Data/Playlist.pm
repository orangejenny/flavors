package Flavors::Data::Playlist;

use strict;
use Flavors::Data::Util;

################################################################
# List
#
# Description: Get a list of playlists
#
# Args:
#   None
#
# Return Value: array of hashrefs
################################################################
sub List {
    my ($dbh, $args) = @_;

    my $sql = qq{
        select
            id,
            filter,
            isstarred,
            refreshed
        from
            playlist
        order by
            isstarred,
            updated desc
    };

    return Flavors::Data::Util::Results($dbh, {
        SQL => $sql,
        COLUMNS => [qw(id filter isstarred refreshed)],
    });
}

################################################################
# Star
#
# Description: Update playlist metadata
#
# Parameters:
#        ID
#        ISSTARRED
#
# Return Value: none
################################################################
sub Star {
    my ($dbh, $args) = @_;

    Flavors::Data::Util::Results($dbh, {
        SQL => "update playlist set isstarred = ?, updated = now() where id = ?",
        BINDS => [$args->{ISSTARRED} ? 1 : 0, $args->{ID}],
        SKIPFETCH => 1,
    });
}

################################################################
# Update
#
# Description: Update playlist metadata
#
# Parameters:
#        FILTER
#
# Return Value: none
################################################################
sub Update {
    my ($dbh, $args) = @_;

    my $filter = Flavors::Util::Sanitize($args->{FILTER});
    if (!$filter) {
        return;
    }

    my @results = Flavors::Data::Util::Results($dbh, {
        SQL => "select id from playlist where filter = ?",
        BINDS => [$filter],
        COLUMNS => ['id'],
    });
    if (@results) {
        # touch playlist
        Flavors::Data::Util::Results($dbh, {
            SQL => "update playlist set updated = now() where id = ?",
            BINDS => [$results[0]->{ID}],
            SKIPFETCH => 1,
        });
    }
    else {
        # create playlist
        @results = Flavors::Data::Util::Results($dbh, {
            SQL => "select max(id) from playlist",
            COLUMNS => ['id'],
        });
        my $sql = qq{
            insert into playlist
                (id, filter, created, updated)
            values
                (?, ?, now(), now())
        };
        Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            BINDS => [$results[0]->{ID} + 1, $filter],
            SKIPFETCH => 1,
        });

        # delete expired playlists
        my $sql = qq{
            select 
                id
            from
                playlist
            where
                isstarred = 0
            order by
                updated desc
        };
        @results = Flavors::Data::Util::Results($dbh, {
            SQL => $sql,
            COLUMNS => ['id'],
        });
        for (my $i = 5; $i < @results; $i++) {
            Flavors::Data::Util::Results($dbh, {
                SQL => "delete from playlist where id = ?",
                BINDS => [$results[$i]->{ID}],
                SKIPFETCH => 1,
            });
        }
    }
}

1;
