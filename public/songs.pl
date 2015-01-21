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

my @songs = FlavorsData::SongList($dbh, {
	FILTER => $fdat->{FILTER},
	ORDERBY => $fdat->{ORDERBY},
});
my $initialpagedata = {
	ROWS => [
		map {
			{
				c => [
					{ v => $_->{ID}} ,
					{ v => $_->{ISSTARRED}} ,
					{ v => $_->{NAME} },
					{ v => $_->{ARTIST} },
					{ v => $_->{COLLECTIONS} },
					{ v => FlavorsHTML::Rating($_->{RATING}) },
					{ v => FlavorsHTML::Rating($_->{ENERGY}) },
					{ v => FlavorsHTML::Rating($_->{MOOD}) },
					{ v => $_->{TAGS} },
				],
			}
		} @songs
	],
};


FlavorsHTML::Header({
	TITLE => "Songs",
	INITIALPAGEDATA => $initialpagedata,
});

if ($fdat->{RANDOM}) {
	my $column = $fdat->{RANDOM};
	my $item = FlavorsData::RandomItem($dbh, $column);
	$item = FlavorsUtils::EscapeSQL($item);
	if ($column =~ m/collection/i) {
		$fdat->{FILTER} = sprintf("collectionlist like '%% %s %%'", $item);
	}
	elsif ($column =~ m/tag/i) {
		$fdat->{FILTER} = sprintf("taglist like '%% %s %%'", $item);
	}
	else {
		$fdat->{FILTER} = sprintf("%s = '%s'", $column, $item);
	}
	$fdat->{PLACEHOLDER} = "";
}

print q{
	<div id="helpers" class="modal">
		<div class="modal-dialog">
			<div class="modal-content">
				<div class="modal-header">
					<h4>Songs</h4>
				</div>
				<div class="modal-body">
					<div class="group" data-category="random">
						<button class="btn btn-default">Random collection</button>
						<button class="btn btn-default">Random artist</button>
						<button class="btn btn-default">Random tag</button>
					</div>
					<div class="group" data-category="stars">
						<button class="btn btn-default">5 stars</button>
						<button class="btn btn-default">4 stars</button>
						<button class="btn btn-default">3 stars</button>
					</div>
					<div class="group" data-category="missing">
						<button class="btn btn-default">Missing rating</button>
						<button class="btn btn-default">Missing mood</button>
						<button class="btn btn-default">Missing energy</button>
					</div>
					<div class="group" data-category="popular">
						<button class="btn btn-default">Recently added</button>
						<button class="btn btn-default">Recently exported</button>
						<button class="btn btn-default">Frequently exported</button>
					</div>
					<div class="group" data-category="unpopular">
						<button class="btn btn-default">Rarely exported</button>
						<button class="btn btn-default btn-info">All songs</button>
						<button class="btn btn-default">Exported long ago</button>
					</div>
				</div>
			</div>
		</div>
	</div>
};

print sprintf(qq{
	<div class="post-nav">
		<div class="complex-filter-container">
			<form method=POST id="complex-filter">
				<textarea name=filter rows=3 style="width: 400px;" placeholder="%s">%s</textarea>
				<span class="glyphicon glyphicon-remove clear-filter" style="position: absolute; cursor: pointer;" title="Clear filter"></span>
				<span class="glyphicon glyphicon-question-sign hint" style="position: absolute; top: 20px;" title="%s"></span>
				<span class="glyphicon glyphicon-heart helpers-trigger" style="position: absolute; top: 40px; cursor: pointer;" title="Common filters"></span>
				<br>
				<input type="button" value="Filter" class="btn btn-default btn-lg" style="width: 400px;" />
				<input type="hidden" name="random" value="" />
				<input type="hidden" name="orderBy" value="" />
				<input type="hidden" name="placeholder" value="" />
			</form>
		</div>
	},
	$fdat->{PLACEHOLDER},
	$fdat->{FILTER},
	q{
		id, name, artist,
		<br>rating, energy, mood,
		<br>time, filename,
		<br>ismix, mindateacquired, maxdateacquired,
		<br>taglist, tagcount, collectionlist,
		<br>minyear, maxyear
	},
);


print qq{ <div id="dashboard"> };

print qq{
	<div id="simple-filters" class="clearfix">
		<div id="simple-filter-name" style="width: 15%; float: left; margin-left: 2%;"></div>
		<div id="simple-filter-artist" style="width: 15%; float: left; margin-left: -0.5%;"></div>
		<div id="simple-filter-collections" style="width: 15%; float: left;"></div>
		<div id="simple-filter-tags" style="width: 25%; float: left; margin-left: 14%;"></div>
	</div>
};

print qq{ <div id="top-veil"></div> };
print qq{ <div id="song-table-container"></div> };
print qq{ </div> };

print "</tbody></table>";
print qq{ </div> };	# close .post-nav

print qq{
	<div id="song-count-container">
		<div id="bottom-veil"></div>
		<span id="song-count-span" class="ui-corner-all">
			<span id="song-count"></span> songs
		</span>
	</div>
};

print FlavorsHTML::Footer();
