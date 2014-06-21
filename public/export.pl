#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsData;
use FlavorsHTML;
use FlavorsUtils;

my $cgi = CGI->new;
my $fdat = FlavorsUtils::Fdat($cgi);
my $dbh = FlavorsData::DBH();

my @songs;
my $filename;
my %updateexport;

if ($fdat->{COLLECTIONID} =~ /^[^,]+$/) {
	$fdat->{COLLECTIONID} = delete $fdat->{COLLECTIONIDS};
}
if ($fdat->{COLLECTIONID}) {
	# Export a single collection
	my $collectionid = $fdat->{COLLECTIONID};
	my $collection = FlavorsData::CollectionList($dbh, { ID => $collectionid });
	$filename = $collection->{NAME};
	@songs = FlavorsData::TrackList($dbh, { COLLECTIONIDS => $collectionid });
	%updateexport = (
		COLLECTIONIDS => [$collectionid],
	);
}
elsif ($fdat->{COLLECTIONIDS}) {
	# Export a set of collections
	$filename = "collections";
	$fdat->{COLLECTIONIDS} =~ s/[^0-9,]//;
	@songs = FlavorsData::TrackList($dbh, { COLLECTIONIDS => $fdat->{COLLECTIONIDS}	});
	%updateexport = (
		COLLECTIONIDS => [split(",", $fdat->{COLLECTIONIDS})],
	);
}
elsif ($fdat->{SONGIDLIST}) {
	# Export a specific set of songs
	$fdat->{SONGIDLIST} =~ s/\s+/,/g;
	my @unsorted = FlavorsData::SongList($dbh, { 
		FILTER => "song.id in ($fdat->{SONGIDLIST})",
	});
	my %songsbyid = map { $_->{ID} => $_ } @unsorted;
	foreach my $id (split(/,/, $fdat->{SONGIDLIST})) {
		push @songs, $songsbyid{$id};
	}
	$filename = "lab";
}
else {
	# Export a filtered set of songs
	$filename = "songs";
	@songs = FlavorsData::SongList($dbh, $fdat);
}
$updateexport{SONGIDS} = [map { $_->{ID} } @songs];
FlavorsData::UpdateExport($dbh, \%updateexport);

$filename =~ s/[^\w \-[\]]+//g;
print $cgi->header(-type => 'text/text', -attachment => "$filename.m3u");

my $os = lc $fdat->{OS};
if ($os !~ /^(mac|pc)$/) {
	$os = "mac";
}
my $directory = FlavorsUtils::Config->{path}->{$os};

foreach my $song (@songs) {
	my $song = "$directory$song->{FILENAME}\n";
	if ($os eq "pc") {
		$song =~ s/\//\\/g;
	}
	print $song;
}

