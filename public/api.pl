#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsData;
use FlavorsHTML;
use FlavorsUtils;
use JSON qw(to_json);

my $cgi = CGI->new;
print $cgi->header(-type => "application/json");
my $fdat = FlavorsUtils::Fdat($cgi);

my $cmd = delete $fdat->{CMD};

my $dbh = FlavorsData::DBH();

if ($cmd eq "LIST") {
	my $table = $fdat->{TYPE};
	my $sql = qq{
		select id, name
		from $table
		order by name
	};

	my @results = FlavorsData::_results($dbh, {
		SQL => $sql,
		COLUMNS => [qw(ID NAME)],
	});

	my $data = {
		TYPE => $table,
		ITEMS => \@results,
	};
	print JSON::to_json($data);
}
else {
	my $condition;
	my @binds;
	if ($fdat->{COLLECTIONID}) {
		$condition = qq{
			and exists (
				select 1 
				from collection, songcollection 
				where 
					collection.id = songcollection.collectionid 
					and song.id = songcollection.songid 
					and collection.id = ?
				)
		};
		@binds = ($fdat->{COLLECTIONID});
	}
	elsif ($fdat->{PLAYLISTID}) {
		my @rows = FlavorsData::_results($dbh, {
			SQL => qq{ select filter from playlist where id = ? },
			BINDS => [$fdat->{PLAYLISTID}],
			COLUMNS => [qw(FILTER)],
		});
		if (@rows) {
			$condition = "and " . $rows[0]->{FILTER};
		}
	}
	my $sql = qq{
		select spotifyuri
		from song
		where
			spotifyuri is not null
			$condition
		order by rand()
		limit 1
	};

	my @results = FlavorsData::_results($dbh, {
		SQL => $sql,
		BINDS => \@binds,
		COLUMNS => [qw(SPOTIFYURI)],
	});
	my $song = $results[0];
	print JSON::to_json($song);
}
