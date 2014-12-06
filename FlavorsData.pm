package FlavorsData;

use strict;
use Data::Dumper;
use DBI;
use FlavorsUtils;

################################################################
# DBH
#
# Description: Create database handle
#
# Return Value: $dbh
################################################################
sub DBH {
	my $config = FlavorsUtils::Config->{db};

	my $host = $config->{host};
	my $database = $config->{database};
	my $user = $config->{user};
	my $password = $config->{password};

	return DBI->connect("dbi:mysql:host=$host:$database", $user, $password) or die $DBI::errstr;
}

################################################################
# SongList
#
# Description: Get a list of songs
#
# Parameters (optional)
#		FILTER: additional where clause
#		ID: only this song
#		ORDERBY: order by this column (may include "desc")
#		NAME, ARTIST, COLLECTIONS, TAGS: 'like' filters for these columns
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
			min(collection.dateacquired) as dateacquired,
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
	};

	if ($args->{ID}) {
		$sql .= " where song.id = $args->{ID}";
	}

	$sql .= " group by song.id ";

	$sql = "select * from ($sql) songs where 1 = 1";
	my %filtercolumns = (
		NAME => 'name',
		ARTIST => 'artist',
		COLLECTIONS => 'collectionlist',
		TAGS => 'taglist',
	);
	my @binds;
	foreach my $column (keys %filtercolumns) {
		if ($args->{$column}) {
			my @values = split(/\s+/, $args->{$column});
			my @conditions = map { "$filtercolumns{$column} like concat('%', ?, '%')" } @values;
			push @binds, @values;
			$sql .= sprintf(" and (%s)", join(" and ", @conditions));
		}
	}

	$args->{FILTER} = FlavorsUtils::Sanitize($args->{FILTER});
	if ($args->{FILTER}) {
		$sql .= " and " . $args->{FILTER};
	}

	$sql .= " order by " . ($args->{ORDERBY} ? $args->{ORDERBY} : "maxyear desc, minyear desc, id desc");

	my @results = _results($dbh, {
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
# CollectionList
#
# Description: Get a list of collections
#
# Parameters (optional)
#		ID: only this collection
#		SONGID: only collections that include this song
#
# Return Value: array of hashrefs UNLESS ID is passed, in which
#		case, return that single hashref
################################################################
sub CollectionList {
	my ($dbh, $args) = @_;

	my @collectioncolumns = qw(
		id
		name
		ismix
		dateacquired
		rating
		energy
		mood
		artist
		genre
		color
		taglist
		lastexport
		exportcount
	);

	my $sql = sprintf(qq{
		select
			%s
		from
			collection
		inner join (
			select 
				collectionid, 
				avg(rating) rating, 
				avg(energy) energy, 
				avg(mood) mood
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
				group_concat(distinct tag separator ' ') as taglist
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
	}, join(", ", @collectioncolumns));

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
	}

	$sql .= qq{
		order by dateacquired desc
	};

	my @results = _results($dbh, {
		SQL => $sql,
		COLUMNS => \@collectioncolumns,
	});

	if ($args->{ID}) {
		return $results[0];
	}
	else {
		return $args->{REF} ? \@results : @results;
	}
}

################################################################
# TagList
#
# Description: Get a list of tags
#
# Parameters (optional)
#		RELATED: only tags that appear in a song with this tag
#
# Return Value: array of hashrefs
################################################################
sub TagList {
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

	return _results($dbh, {
		SQL => $sql,
		COLUMNS => [qw(tag category metacategory count)],
	});
}

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

	return _results($dbh, {
		SQL => $sql,
		COLUMNS => [qw(tag category)],
	});
}

################################################################
# RandomItem
#
# Description: Get a set of distinct items
#
# Args:
#		Column: "artist", "collection", or "tag"
# Return Value: String
################################################################
sub RandomItem {
	my ($dbh, $column) = @_;

	my $table;
	if ($column =~ m/collection/i) {
		$table = "collection";
		$column = "name";
	}
	elsif ($column =~ m/tag/i) {
		$table = 'songtag';
	}
	else {
		$table = 'song';
	}

	my $sql = "select distinct $column from $table order by rand() limit 1";

	my @rows = _results($dbh, {
		SQL => $sql,
		COLUMNS => [$column],
	});

	return $rows[0]->{uc $column};
}

################################################################
# PlaylistList
#
# Description: Get a list of playlists
#
# Args:
#		None
# Return Value: array of hashrefs
################################################################
sub PlaylistList {
	my ($dbh, $args) = @_;

	my $sql = sprintf(qq{
		select
			id,
			name,
			filter
		from
			playlist
		order by
			name
	});

	return _results($dbh, {
		SQL => $sql,
		COLUMNS => [qw(id name filter)],
	});
}

################################################################
# SavePlaylist
#
# Description: Save a playlist
#
# Args:
#		NAME
#		FILTER
#
# Return Value: nothing (if save failed) or hashref of
#		NAME
#		FILTER: The filter that actually saved (sanitized)
################################################################
sub SavePlaylist {
	my ($dbh, $args) = @_;

	my $filter = FlavorsUtils::Sanitize($args->{FILTER});
	if (!$filter) {
		return;
	}

	my @results = _results($dbh, {
		SQL => "select max(id) from playlist",
		COLUMNS => ['id'],
	});

	my $newid = $results[0]->{ID} + 1;

	my $sql = qq{
		insert into playlist
			(id, name, filter)
		values
			(?, ?, ?)
	};

	_results($dbh, {
		SQL => $sql,
		BINDS => [$newid, $args->{NAME}, $filter],
		SKIPFETCH => 1,
	});

	return { 
		NAME => $args->{NAME},
		FILTER => $filter,
	};
}

################################################################
# TrackList
#
# Description: Get a list of songs in a given collection(s)
#
# Parameters
#		COLLECTIONIDS: comma-separated string
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

	return _results($dbh, {
		SQL => $sql,
		COLUMNS => [qw(collectionid id name artist tracknumber filename tags)],
	});
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

	return _results($dbh, {
		SQL => $sql,
		COLUMNS => [qw(name hex whitetext)],
	});
}

################################################################
# UpdateColor
#
# Description: Update color row
#
# Args:
#	NAME (required)
#	HEX (optional)
#	WHITETEXT (optional)
#
# Return value: none
################################################################
sub UpdateColor {
	my ($dbh, $args) = @_;

	my @colors = _results($dbh, {
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
		$sql .= "update color set " . join(", ", @clauses) . " where name = ?";
	}
	else {
		push(@binds, $args->{HEX} || "000000");
		push(@binds, $args->{WHITETEXT} || 0);
		$sql .= "insert into color (hex, whitetext, name) values (?, ?, ?);";
	}
	push (@binds, $args->{NAME});

	_results($dbh, {
		SQL => $sql,
		BINDS => \@binds,
		SKIPFETCH => 1,
	});
}

################################################################
# UpdateSong
#
# Description: Update given song
#
# Parameters (optional except for ID)
#		ID
#		NAME, ARTIST, RATING, ENERGY, MOOD
#		TAGS
#
# Return Value: array of hashrefs
################################################################
sub UpdateSong {
	my ($dbh, $newsong) = @_;

	my $id = delete $newsong->{ID};
	my $oldsong = SongList($dbh, { ID => $id });

	# song table
	my @updatefields = qw(NAME ARTIST RATING ENERGY MOOD YEAR);
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
		_results($dbh, {
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
		_results($dbh, {
			SQL => $sql,
			BINDS => [$newsong->{GENRE}, $oldsong->{ARTIST}],
			SKIPFETCH => 1,
		});
	}

	# tag table
	if (exists $newsong->{TAGS}) {
		my @oldtags = _results($dbh, {
			SQL => qq{ select tag from songtag where songid = $id },
			COLUMNS => [qw(tag)],
		});
		@oldtags = map { $_->{TAG} } @oldtags;
		my @newtags = split(/\s+/, $newsong->{TAGS});
		my @tagstoadd = FlavorsUtils::ArrayDifference(\@newtags, \@oldtags);
		my @tagstoremove = FlavorsUtils::ArrayDifference(\@oldtags, \@newtags);

		foreach my $tag (@tagstoadd) {
			_results($dbh, {
				SQL => qq{
					insert into songtag (songid, tag) values (?, ?)
				},
				BINDS => [$id, $tag],
				SKIPFETCH => 1,
			});
		}

		if (@tagstoremove) {
			_results($dbh, {
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
# UpdateCategory
#
# Description: Update category for item
#
# Parameters:
#		VALUE
#		CATEGORY
#		TABLE
#		VALUECOLUMN
#		CATEGORYCOLUMN
#
# Return Value: none
################################################################
sub UpdateCategory {
	my ($dbh, $args) = @_;

	my $sql = "select $args->{CATEGORYCOLUMN} from $args->{TABLE} where $args->{VALUECOLUMN} = ?";
	my $currentrow = _results($dbh, {
		SQL => $sql,
		BINDS => [$args->{VALUE}],
	});

	my $message;
	if ($currentrow) {
		$sql = "update $args->{TABLE} set $args->{CATEGORYCOLUMN} = ? where $args->{VALUECOLUMN} = ?";
		$message = "Moved";
	}
	else {
		$sql = "insert into $args->{TABLE} ($args->{CATEGORYCOLUMN}, $args->{VALUECOLUMN}) values (?, ?)";
		$message = "Added";
	}
	$message .= " $args->{VALUE} to $args->{CATEGORY}.";

	_results($dbh, {
		SQL => $sql,
		BINDS => [$args->{CATEGORY}, $args->{VALUE}],
		SKIPFETCH => 1,
	});

	return {
		MESSAGE => $message,
	};
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
		_results($dbh, {
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
		_results($dbh, {
			SQL => $sql,
			BINDS => $args->{COLLECTIONIDS},
			SKIPFETCH => 1,
		});
	}

	return;
}

################################################################
# _results
#
# Description: Execute query
#
# Parameters
#		SQL: query string
#		COLUMNS: arrayref of names for the fetched elements
#		BINDS (optional)
#		SKIPFETCH: (optional) denotes a non-select query
#
# Return Value: array of hashrefs
################################################################
sub _results {
	my ($dbh, $args) = @_;

	my @binds = $args->{BINDS} ? @{ $args->{BINDS} } : ();

	my $sql = $args->{SQL};
	my $query = $dbh->prepare($sql) or die "PREPARE: $DBI::errstr ($sql)";
	$query->execute(@binds) or die "EXECUTE: $DBI::errstr ($sql)";

	my @results;
	my @columns = $args->{COLUMNS} ? @{ $args->{COLUMNS} } : ();
	while (!$args->{SKIPFETCH} && (my @row = $query->fetchrow())) {
		my %labeledrow;
		for (my $i = 0; $i < @columns; $i++) {
			$labeledrow{uc($columns[$i])} = $row[$i];
		}
		push @results, \%labeledrow;
	}
	$query->finish();

	return @results;
}

1;
