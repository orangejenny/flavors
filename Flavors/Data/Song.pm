package Flavors::Data::Song;

use strict;
use Flavors::Data::Util;

################################################################
# List
#
# Description: Get a list of songs
#
# Parameters (optional)
#		FILTER: additional where clause
#		ID: only this song
#		ORDERBY: order by this column (may include "desc")
#		SIMPLEFILTER: string to apply against name, artist, and 
#			collection names (disjunctive)
#
# Return Value: array/arrayref of hashrefs UNLESS ID is passed,
#		in which case, return the single hashref
################################################################
sub List {
	my ($dbh, $args) = @_;

	$args->{ORDERBY} = Flavors::Util::Sanitize($args->{ORDERBY});

	my @songcolumns = qw(
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
	);

	my $songcolumnstring = join(", ", map { "song.$_" } @songcolumns);
	my $sql = sprintf(qq{
		select distinct
			$songcolumnstring,
			artistgenre.genre,
			concat(' ', songtaglist.taglist, ' ') as taglist,
			group_concat(collection.name order by dateacquired separator '%s') as collections,
			songtaglist.tagcount,
			years.minyear,
			years.maxyear,
			min(collection.dateacquired) as mindateacquired,
			max(collection.dateacquired) as maxdateacquired,
			tracks.tracknumber,
			song.exportcount,
			song.lastexport
		from 
			song
		left join songcollection on song.id = songcollection.songid
		left join collection on songcollection.collectionid = collection.id
		left join songtaglist on song.id = songtaglist.songid
		left join artistgenre on artistgenre.artist = song.artist
		left join (
			select
				songtag.songid,
				min(songtag.tag) minyear,
				max(songtag.tag) maxyear
			from
				songtag,
				tagcategory
			where
				songtag.tag = tagcategory.tag
				and tagcategory.category = 'years'
			group by
				songtag.songid
		) years on years.songid = song.id
		left join (
			select songid, tracknumber 
			from songcollection outersongcollection, collection 
			where outersongcollection.collectionid = collection.id 
			and collection.dateacquired = (
				select max(dateacquired) 
				from collection, songcollection innersongcollection 
				where innersongcollection.songid = outersongcollection.songid
				and collection.id = collectionid
			)
		) tracks on tracks.songid = song.id
	}, $Flavors::Data::Util::SEPARATOR);

	if ($args->{ID}) {
		$sql .= " where song.id = $args->{ID}";
	}

	$sql .= " group by song.id ";

	$sql = "select * from ($sql) songs where 1 = 1";
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
						select 1 from collection, songcollection
						where collection.id = songcollection.collectionid
						and songs.id = songcollection.songid
						and concat(' ', collection.name, ' ') like concat(' %', ?, '% ')
					)
				)
			};
			push(@binds, $token, $token, $token, $token);
		}
	}

	$args->{FILTER} = Flavors::Util::Sanitize($args->{FILTER});
	if ($args->{FILTER}) {
		$sql .= " and (" . $args->{FILTER} . ")";
	}

	$sql .= " order by " . ($args->{ORDERBY} ? $args->{ORDERBY} : "maxdateacquired desc, tracknumber");

	my @results = Flavors::Data::Util::Results($dbh, {
		SQL => $sql,
		COLUMNS => [@songcolumns, 'genre', 'tags', 'collections'],
		GROUPCONCAT => ['collections'],
		BINDS => \@binds,
	});

	if ($args->{ID}) {
		return $results[0];
	}
	else {
		return wantarray ? @results : \@results;
	}
}

################################################################
# Stats
#
# Description: Get statistics, by song
#
# Args:
#	GROUPBY: CSV of strings, each one of qw(rating energy mood)
#
# Return Value: arrayref of hashrefs, each with a count and
#	a value for each grouped-by attribute
################################################################
sub Stats {
	my ($dbh, $args) = @_;
	my @groupby = split(/\s*,\s*/, Flavors::Util::Sanitize($args->{GROUPBY}));

	my $sql = sprintf(qq{
			select 
				%s, 
				group_concat(concat(song.artist, ' - ', song.name) separator '%s') samples,
				count(*)
			from
				song
			group by %s
			order by %s;
		},
		join(", ", map { sprintf("coalesce(%s, 0)", $_) } @groupby),
		$Flavors::Data::Util::SEPARATOR,
		join(", ", @groupby),
		join(", ", @groupby),
	);
	return [Flavors::Data::Util::Results($dbh, {
		SQL => $sql,
		COLUMNS => [@groupby, 'samples', 'count'],
		GROUPCONCAT => ['samples'],
	})];
}

################################################################
# Update
#
# Description: Update given song
#
# Parameters (optional except for ID)
#		ID
#		NAME, ARTIST, RATING, ENERGY, MOOD, ISSTARRED
#		TAGS
#
# Return Value: array of hashrefs
################################################################
sub Update {
	my ($dbh, $newsong) = @_;

	my $id = delete $newsong->{ID};
	my $oldsong = List($dbh, { ID => $id });

	# song table
	my @updatefields = qw(NAME ARTIST RATING ENERGY MOOD YEAR ISSTARRED);
	my @updates;
	my @binds;
	foreach my $key (@updatefields) {
		if (exists $newsong->{$key} && $newsong->{$key} != $oldsong->{$key}) {
			push @updates, "$key = ?";
			push @binds, $newsong->{$key};
		}
	}

	if (@updates) {
		my $sql = sprintf(qq{
			update
				song
			set
				%s
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
			? "update artistgenre set genre = ? where artist = ?"
			: "insert into artistgenre (genre, artist) values (?, ?)"
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
			SQL => qq{ select tag from songtag where songid = $id },
			COLUMNS => [qw(tag)],
		});
		@oldtags = map { $_->{TAG} } @oldtags;
		my @newtags = split(/\s+/, $newsong->{TAGS});
		my @tagstoadd = Flavors::Util::ArrayDifference(\@newtags, \@oldtags);
		my @tagstoremove = Flavors::Util::ArrayDifference(\@oldtags, \@newtags);

		foreach my $tag (@tagstoadd) {
			Flavors::Data::Util::Results($dbh, {
				SQL => qq{
					insert into songtag (songid, tag) values (?, ?)
				},
				BINDS => [$id, $tag],
				SKIPFETCH => 1,
			});
		}

		if (@tagstoremove) {
			Flavors::Data::Util::Results($dbh, {
				SQL => sprintf(qq{
					delete from songtag where songid = ? and tag in (%s)
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
#	SONGIDS: arrayref
#	COLLECTIONIDS: arrayref
#
# Return Value: none
################################################################
sub UpdateExport {
	my ($dbh, $args) = @_;

	if ($args->{SONGIDS}) {
		my $sql = sprintf(qq{
			update song
			set
				lastexport = now(),
				exportcount = exportcount + 1
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
			update collection
			set
				lastexport = now(),
				exportcount = exportcount + 1
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

1;
