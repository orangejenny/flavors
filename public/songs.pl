#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsData::Playlists;
use FlavorsData::Songs;
use FlavorsData::Tags;
use FlavorsData::Utils;
use FlavorsHTML;
use FlavorsUtils;
use JSON qw(to_json);

my $dbh = FlavorsData::Utils::DBH();
my $fdat = FlavorsUtils::Fdat();

my $cgi = CGI->new;
print $cgi->header();

my @songs = ();
eval {
	@songs = FlavorsData::Songs::List($dbh, {
		FILTER => $fdat->{FILTER},
		ORDERBY => $fdat->{ORDERBY},
	});
};

my $sqlerror = "";
if ($fdat->{FILTER} && $@) {
	# assume this was an error in user's complex filter SQL
	$sqlerror = $@;
	$sqlerror =~ s/\n.*//s;
	$sqlerror =~ s/\(select \* from \(\s*//s;
}
else {
	FlavorsData::Playlists::Update($dbh, {
		FILTER => $fdat->{FILTER},
	});
}

my $tokens = {};	# token => [songid1, songid2, ... ]
foreach my $song (@songs) {
	my @songtokens = split(/\s+/, lc(join(" ", $song->{NAME}, $song->{ARTIST}, $song->{COLLECTIONS}, $song->{TAGS})));
	my $songtokenset = {};
	foreach my $token (@songtokens) {
		if ($token) {
			$songtokenset->{$token} = 1;
		}
	}
	foreach my $token (keys $songtokenset) {
		if (!$tokens->{$token}) {
			$tokens->{$token} = [];
		}
		push($tokens->{$token}, $song->{ID});
	}
}

my $letters = {};	# letter => [token1, token2, ... ]
foreach my $token (keys $tokens) {
	foreach my $letter (split(//, $token)) {
		if (!$letters->{$letter}) {
			$letters->{$letter} = [];
		}
		push($letters->{$letter}, $token);
	}
}

my $lettercounts = {};
foreach my $letter (keys $letters) {
	$lettercounts->{$letter} = scalar(@{ $letters->{$letter} });
}

FlavorsHTML::Header({
	TITLE => "Songs",
	BUTTONS => FlavorsHTML::ExportControl(),
	INITIALPAGEDATA => {
		TOKENS => $tokens,
		LETTERS => $letters,
		LETTERCOUNTS => $lettercounts,
		SQLERROR => $sqlerror,
	},
	CSS => ['songs.css'],
	JS => ['songs.js'],
});

my @playlists = FlavorsData::Playlists::List($dbh);
print sprintf(q{
	<div id="complex-filter" class="modal">
		<div class="modal-dialog">
			<div class="modal-content">
				<div class="modal-body">

					<div class="alert alert-danger sql-error %s">%s</div>

					<form method="POST">
						<textarea name=filter rows=3 placeholder="%s">%s</textarea>
						<input type="button" value="Filter" class="btn btn-default btn-lg"/>
						<input type="hidden" name="orderBy" value="" />
						<input type="hidden" name="placeholder" value="" />
					</form>

					<div id="column-hints">
						id, name, artist, rating, energy, mood, time, filename,
						<br>ismix, mindateacquired, maxdateacquired,
						<br>taglist, tagcount, collectionlist, minyear, maxyear, isstarred
					</div>

					<ul class="playlists">
						%s
					</ul>

					<div class="group" data-category="popular">
						<button class="btn btn-default">Recently added</button>
						<button class="btn btn-default">Recently exported</button>
						<button class="btn btn-default">Frequently exported</button>
					</div>
					<div class="group" data-category="unpopular">
						<button class="btn btn-default">Rarely exported</button>
						<button class="btn btn-default">Exported long ago</button>
					</div>
				</div>
			</div>
		</div>
	</div>
},
	$sqlerror ? "" : "hide",
	$sqlerror,
	$fdat->{PLACEHOLDER},
	$fdat->{FILTER},
	join("", map {
		sprintf(
			"<li data-id='%s'>%s <a href='#'>%s</a></li>",
			$_->{ID}, 
			FlavorsHTML::Rating(1, $_->{ISSTARRED} ? 'star' : 'star-empty'), 
			$_->{FILTER},
		)
	} @playlists),
);

my $iconcount = $fdat->{FILTER} ? 2 : ($fdat->{PLACEHOLDER} ? 1 : 0);
print sprintf(qq{
		<div class="post-nav">
			<div id="filter-container">
				<div id="filter-input">
					<span class='glyphicon glyphicon-search'></span>
					<input id='filter' type='text'/>
				</div>
				<div id="complex-filter-trigger" class="icon-count-%i">
					<a href='#'>%s</a> %s %s
				</div>
			</div>
	},
	$iconcount,
	$fdat->{PLACEHOLDER} || $fdat->{FILTER} || "advanced search",
	$iconcount == 2 ? "<span class='glyphicon glyphicon-refresh'></span>" : "",
	$iconcount > 0 ? "<span class='glyphicon glyphicon-remove'></span>" : "",
);

print qq{ <div id="top-veil"></div> };
print qq{ <div id="song-table-container"> };

print qq{ <table><tbody> };

my @colors = FlavorsData::Tags::ColorList($dbh);
my %colormap = ();
foreach my $color (@colors) {
	$colormap{$color->{NAME}} = $color;
}
foreach my $song (@songs) {
	print sprintf(qq {
		<tr id="song-%s" data-song-id="%s" data-colors="%s">
			<td class='isstarred'>%s</td>
			<td>%s</td>
			<td>%s</td>
			<td>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true'>%s</td>
		</tr>
		},
		$song->{ID},
		$song->{ID},
		FlavorsUtils::EscapeHTMLAttribute(lc(JSON::to_json([
			grep { $_->{HEX} } map { $colormap{$_} } grep { exists $colormap{$_} } split(/\s+/, $song->{TAGS})
		]))),
		FlavorsHTML::Rating(1, $song->{ISSTARRED} ? 'star' : 'star-empty'),
		$song->{NAME},
		$song->{ARTIST},
		$song->{COLLECTIONS},
		FlavorsHTML::Rating($song->{RATING}, 'star'),
		FlavorsHTML::Rating($song->{ENERGY}, 'fire'),
		FlavorsHTML::Rating($song->{MOOD}, 'heart'),
		$song->{TAGS},
	);
}

print qq{ </tbody></table> };

print qq{</div> };
print qq{ </div> };

print qq{
	<div id="song-count-container">
		<div id="bottom-veil"></div>
		<span id="song-count-span">
			<span id="song-count"></span> songs
		</span>
	</div>
};

print FlavorsHTML::Footer();
