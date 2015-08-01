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
				group_concat(distinct tag order by rand() separator ' ') as taglist
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
# CollectionSuggestions
#
# Description: Get a list of suggested collections
#
# Parameters
#		None
#
# Return Value: arrayref of hashrefs
################################################################
sub CollectionSuggestions {
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
			order by dateacquired desc
			limit %s
			},
			pop(@clauses),
			$maxcollections,
		);

		my @newcollections = _results($dbh, {
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
# SongStats
#
# Description: Get statistics, by song
#
# Args:
#	GROUPBY: CSV of strings, each one of qw(rating energy mood)
#
# Return Value: array of counts, with each index representing
#	the number of songs with that value. Zero maps to null.
################################################################
sub SongStats {
	my ($dbh, $args) = @_;
	my @groupby = split(/\s*,\s*/, FlavorsUtils::Sanitize($args->{GROUPBY}));

	my $sql = sprintf(qq{
			select 
				%s, 
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
	return [_results($dbh, {
		SQL => $sql,
		COLUMNS => [@groupby, 'count'],
	})];
}

################################################################
# CategoryStats
#
# Description: Get statistics, by category
#
# Args:
#	FACET: one of qw(rating energy mood)
#	CATEGORY: string, may be 'genres'
#
# Return Value: array of hashrefs, each containing
#	TAG: string
#	VALUES: arrayref of length 5, each a count mapping to index + 1
################################################################
sub CategoryStats {
	my ($dbh, $args) = @_;
	my $facet = FlavorsUtils::Sanitize($args->{FACET});
	my $category = FlavorsUtils::Sanitize($args->{CATEGORY});
	my $sql;
	my @binds = ();
	if ($category =~ m/genre/i) {
		$sql = sprintf(qq{
			select artistgenre.genre, %s, count(*)
			from song, artistgenre
			where song.artist = artistgenre.artist
			and %s is not null
			group by artistgenre.genre, %s;
		}, $args->{FACET}, $args->{FACET}, $args->{FACET});
	}
	else {
		$sql = sprintf(qq{
			select songtag.tag, %s, count(*)
			from song, songtag, tagcategory
			where song.id = songtag.songid and songtag.tag = tagcategory.tag
			and tagcategory.category = ?
			and %s is not null
			group by songtag.tag, %s;
		}, $args->{FACET}, $args->{FACET}, $args->{FACET});
		push(@binds, $args->{CATEGORY});
	}
	my @rows = _results($dbh, {
		SQL => $sql,
		BINDS => \@binds,
		COLUMNS => [qw(tag rating count)],
	});

	# Transform SQL rows into hash of tag => [count1, count2, count3, count4, count5]
	my %tagcounts = ();
	foreach my $row (@rows) {
		if (!exists $tagcounts{$row->{TAG}}) {
			$tagcounts{$row->{TAG}} = [0, 0, 0, 0, 0];
		}
		$tagcounts{$row->{TAG}}[$row->{RATING} - 1] = $row->{COUNT};
	}

	# Generate sorted lsit of tags, descending based on total count per tag
	my @sortedtags = sort {
		my $suma = 0;
		foreach my $value (@{ $tagcounts{$a} }) {
			$suma += $value;
		}
		my $sumb = 0;
		foreach my $value (@{ $tagcounts{$b} }) {
			$sumb += $value;
		}
		return $sumb <=> $suma;
	} keys %tagcounts;

	# Generate sorted list of hashrefs to send back
	my @data = ();
	foreach my $tag (@sortedtags) {
		push(@data, {
			TAG => $tag,
			VALUES => $tagcounts{$tag},
		});
	}

	return \@data;
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
# CategoryList
#
# Description: Get list of all tag categories
#
# Return Value: array of strings
################################################################
sub CategoryList {
	my ($dbh, $args) = @_;

	return map { $_->{CATEGORY} } _results($dbh, {
		SQL => "select distinct category from tagcategory;",
		COLUMNS => [qw(category)],
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
			filter,
			isstarred
		from
			playlist
		order by
			isstarred,
			lasttouched desc
	});

	return _results($dbh, {
		SQL => $sql,
		COLUMNS => [qw(id filter isstarred)],
	});
}

################################################################
# StarPlaylist
#
# Description: Update playlist metadata
#
# Parameters:
#		ID
#		ISSTARRED
#
# Return Value: none
################################################################
sub StarPlaylist {
	my ($dbh, $args) = @_;

	_results($dbh, {
		SQL => "update playlist set isstarred = ? where id = ?",
		BINDS => [$args->{ISSTARRED} ? 1 : 0, $args->{ID}],
		SKIPFETCH => 1,
	});
}

################################################################
# UpdatePlaylists
#
# Description: Update playlist metadata
#
# Parameters:
#		FILTER
#
# Return Value: none
################################################################
sub UpdatePlaylists {
	my ($dbh, $args) = @_;

	my $filter = FlavorsUtils::Sanitize($args->{FILTER});
	if (!$filter) {
		return;
	}

	my @results = _results($dbh, {
		SQL => "select id from playlist where filter = ?",
		BINDS => [$filter],
		COLUMNS => ['id'],
	});
	if (@results) {
		# touch playlist
		_results($dbh, {
			SQL => "update playlist set lasttouched = now() where id = ?",
			BINDS => [$results[0]->{ID}],
			SKIPFETCH => 1,
		});
	}
	else {
		# create playlist
		@results = _results($dbh, {
			SQL => "select max(id) from playlist",
			COLUMNS => ['id'],
		});
		my $sql = qq{
			insert into playlist
				(id, filter, lasttouched)
			values
				(?, ?, now())
		};
		_results($dbh, {
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
				lasttouched desc
		};
		@results = _results($dbh, {
			SQL => $sql,
			COLUMNS => ['id'],
		});
		for (my $i = 5; $i < @results; $i++) {
			_results($dbh, {
				SQL => "delete from playlist where id = ?",
				BINDS => [$results[$i]->{ID}],
				SKIPFETCH => 1,
			});
		}
	}
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
# AddCollection
#
# Description: Add a new collection and set of songs
#
# Parameters
#		COLLECTION: Hashref containing
#			NAME
#			ISMIX
#		SONGS: Arrayref, each with
#			NAME
#			ARTIST
#			TIME
#
# Return Value: nothing
################################################################
sub AddCollection {
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
	my @ids = _results($dbh, {
		SQL => qq{ select max(id) id from collection },
		COLUMNS => ['id'],
	});
	my $collectionid = $ids[0]->{ID} + 1;
	my $sql = qq{
		insert into collection (id, name, ismix, dateacquired, exportcount)
		values (?, ?, ?, now(), 0)
	};
	_results($dbh, {
		SQL => $sql,
		BINDS => [$collectionid, $args->{NAME}, $args->{ISMIX} ? 1 : 0],
		SKIPFETCH => 1,
	});

	# Add songs
	my @songids = _results($dbh, {
		SQL => qq{ select max(id) id from song },
		COLUMNS => ['id'],
	});
	my $lastid = $songids[0]->{ID} + 1;
	my $firstid = $lastid;
	foreach my $song (@songs) {
		my $sql = qq{
			insert into song (id, name, artist, time, ispurchased, filename)
			values (?, ?, ?, ?, 1, concat(?, '/', ?, '.mp3'))
		};
		_results($dbh, {
			SQL => $sql,
			BINDS => [$lastid, $song->{NAME}, $song->{ARTIST}, $song->{TIME}, $song->{ARTIST}, $song->{NAME}],
			SKIPFETCH => 1,
		});
		$lastid++;
	}

	# Add tracks
	my $sql = qq{
		insert into songcollection (songid, collectionid, tracknumber)
		select id, ?, id - ?
		from song
		where id >= ? and id <= ?
	};
	_results($dbh, {
		SQL => $sql,
		BINDS => [$collectionid, $firstid - 1, $firstid, $lastid],
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
