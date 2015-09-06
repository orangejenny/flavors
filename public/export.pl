#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Collection;
use Flavors::Data::Song;
use Flavors::Data::Util;
use Flavors::HTML;
use Flavors::Util;

my $cgi = CGI->new;
my $fdat = Flavors::Util::Fdat($cgi);
my $dbh = Flavors::Data::Util::DBH();

my @songs;
my %updateexport;

if ($fdat->{COLLECTIONID} =~ /^[^,]+$/) {
	$fdat->{COLLECTIONID} = delete $fdat->{COLLECTIONIDS};
}
if ($fdat->{COLLECTIONID}) {
	# Export a single collection
	my $collectionid = $fdat->{COLLECTIONID};
	my $collection = Flavors::Data::Collection::List($dbh, { ID => $collectionid });
	@songs = Flavors::Data::Collection::TrackList($dbh, { COLLECTIONIDS => $collectionid });
	%updateexport = (
		COLLECTIONIDS => [$collectionid],
	);
}
elsif ($fdat->{COLLECTIONIDS}) {
	# Export a set of collections
	$fdat->{COLLECTIONIDS} =~ s/[^0-9,]//;
	@songs = Flavors::Data::Collection::TrackList($dbh, { COLLECTIONIDS => $fdat->{COLLECTIONIDS}	});
	%updateexport = (
		COLLECTIONIDS => [split(",", $fdat->{COLLECTIONIDS})],
	);
}
elsif ($fdat->{SONGIDLIST}) {
	# Export a specific set of songs
	$fdat->{SONGIDLIST} =~ s/\s+/,/g;
	my @unsorted = Flavors::Data::Song::List($dbh, { 
		FILTER => "song.id in ($fdat->{SONGIDLIST})",
	});
	my %songsbyid = map { $_->{ID} => $_ } @unsorted;
	foreach my $id (split(/,/, $fdat->{SONGIDLIST})) {
		push @songs, $songsbyid{$id};
	}
}
else {
	# Export a filtered set of songs
	@songs = Flavors::Data::Song::List($dbh, $fdat);
}
$updateexport{SONGIDS} = [map { $_->{ID} } @songs];
Flavors::Data::Song::UpdateExport($dbh, \%updateexport);

my $filename = $fdat->{FILENAME};
$filename =~ s/[^\w \-[\]]+//g;
$filename .= " (" . @songs . ")";
print $cgi->header(-type => 'text/text', -attachment => "$filename.m3u");

my $os = lc $fdat->{OS};
if ($os !~ /^(mac|pc)$/) {
	$os = "mac";
}
my $directory = Flavors::Util::Config->{path}->{$os};

foreach my $song (@songs) {
	my $song = "$directory$song->{FILENAME}\n";
	if ($os eq "pc") {
		$song =~ s/\//\\/g;
	}
	print $song;
}

