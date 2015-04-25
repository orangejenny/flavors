#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsUtils;
use FlavorsData;
use JSON qw(to_json);

my $dbh = FlavorsData::DBH();
my $fdat = FlavorsUtils::Fdat();

my $cgi = CGI->new;
print $cgi->header();

my @songs = ();
eval {
	@songs = FlavorsData::SongList($dbh, {
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
	INITIALPAGEDATA => {
		TOKENS => $tokens,
		LETTERS => $letters,
		LETTERCOUNTS => $lettercounts,
		SQLERROR => $sqlerror,
	},
});

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

my @colors = FlavorsData::ColorList($dbh);
my %colormap = ();
foreach my $color (@colors) {
	$colormap{$color->{NAME}} = $color->{HEX};
}
foreach my $song (@songs) {
	print sprintf(qq {
		<tr id="song-%s" data-song-id="%s" data-colors="%s">
			<td class='isstarred'><span class='glyphicon glyphicon-star%s'></span></td>
			<td>%s</td>
			<td>%s</td>
			<td>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true' class='rating'>%s</td>
			<td contenteditable='true' style='width:35%;'>%s</td>
		</tr>
		},
		$song->{ID},
		$song->{ID},
		join(" ", map { $colormap{$_} } grep { exists $colormap{$_} } split(/\s+/, $song->{TAGS})),
		$song->{ISSTARRED} ? "" : "-empty",
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
		<span id="song-count-span" class="ui-corner-all">
			<span id="song-count"></span> songs
		</span>
	</div>
};

print FlavorsHTML::Footer();
