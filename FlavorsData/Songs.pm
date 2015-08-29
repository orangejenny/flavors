package FlavorsData::Songs;

use strict;
use FlavorsData;

################################################################
# SongList
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
# Return Value: array of hashrefs UNLESS ID is passed, in which 
#		case, return the single hashref
################################################################
sub SongList {
	my ($dbh, $args) = @_;

	$args->{ORDERBY} = FlavorsUtils::Sanitize($args->{ORDERBY});

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
	my $sql = qq{
		select distinct
			$songcolumnstring,
			artistgenre.genre,
			concat(' ', songtaglist.taglist, ' ') as taglist,
			concat(' ', group_concat(collection.name order by dateacquired separator '; '), ' ') as collectionlist,
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
	};

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
					or collectionlist like concat('%', ?, '%')
					or taglist like concat('%', ?, '%')
				)
			};
			push(@binds, $token, $token, $token, $token);
		}
	}

	$args->{FILTER} = FlavorsUtils::Sanitize($args->{FILTER});
	if ($args->{FILTER}) {
		$sql .= " and (" . $args->{FILTER} . ")";
	}

	$sql .= " order by " . ($args->{ORDERBY} ? $args->{ORDERBY} : "maxdateacquired desc, tracknumber");

	my @results = FlavorsData::_results($dbh, {
		SQL => $sql,
		COLUMNS => [@songcolumns, 'genre', 'tags', 'collections'],
		BINDS => \@binds,
	});

	if ($args->{ID}) {
		return $results[0];
	}
	else {
		return $args->{REF} ? \@results : @results;
	}
}

################################################################
# SongStats
#
# Description: Get statistics, by song
#
# Args:
#	GROUPBY: CSV of strings, each one of qw(rating energy mood)
#
# Return Value: arrayref of hashrefs, each with a count and
#	a value for each grouped-by attribute
################################################################
sub SongStats {
	my ($dbh, $args) = @_;
	my @groupby = split(/\s*,\s*/, FlavorsUtils::Sanitize($args->{GROUPBY}));

	my $sql = sprintf(qq{
			select 
				%s, 
				group_concat(concat(song.name, ' (', song.artist, ')') order by rand() separator '\n') samples,
				count(*)
			from
				song
			group by %s
			order by %s;
		},
		join(", ", map { sprintf("coalesce(%s, 0)", $_) } @groupby),
		join(", ", @groupby),
		join(", ", @groupby),
	);
	return [FlavorsData::_results($dbh, {
		SQL => $sql,
		COLUMNS => [@groupby, 'samples', 'count'],
	})];
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
		FlavorsData::_results($dbh, {
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
		FlavorsData::_results($dbh, {
			SQL => $sql,
			BINDS => $args->{COLLECTIONIDS},
			SKIPFETCH => 1,
		});
	}

	return;
}

################################################################
# UpdateSong
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
sub UpdateSong {
	my ($dbh, $newsong) = @_;

	my $id = delete $newsong->{ID};
	my $oldsong = SongList($dbh, { ID => $id });

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
		FlavorsData::_results($dbh, {
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
		FlavorsData::_results($dbh, {
			SQL => $sql,
			BINDS => [$newsong->{GENRE}, $oldsong->{ARTIST}],
			SKIPFETCH => 1,
		});
	}

	# tag table
	if (exists $newsong->{TAGS}) {
		my @oldtags = FlavorsData::_results($dbh, {
			SQL => qq{ select tag from songtag where songid = $id },
			COLUMNS => [qw(tag)],
		});
		@oldtags = map { $_->{TAG} } @oldtags;
		my @newtags = split(/\s+/, $newsong->{TAGS});
		my @tagstoadd = FlavorsUtils::ArrayDifference(\@newtags, \@oldtags);
		my @tagstoremove = FlavorsUtils::ArrayDifference(\@oldtags, \@newtags);

		foreach my $tag (@tagstoadd) {
			FlavorsData::_results($dbh, {
				SQL => qq{
					insert into songtag (songid, tag) values (?, ?)
				},
				BINDS => [$id, $tag],
				SKIPFETCH => 1,
			});
		}

		if (@tagstoremove) {
			FlavorsData::_results($dbh, {
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

1;
