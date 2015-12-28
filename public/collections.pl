#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Collection;
use Flavors::Data::Song;
use Flavors::Data::Tag;
use Flavors::Data::Util;
use Flavors::HTML;
use Flavors::Util;
use POSIX qw(strftime);

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);
Flavors::HTML::Header({
	TITLE => "Collections",
	BUTTONS => Flavors::HTML::ExportControl() . qq{
		<button type="button" class="btn btn-xs btn-info" id="add-collection">
			<span class="glyphicon glyphicon-plus"></span>
            New
		</button>
    },
	CSS => ['collections.css', 'filters.css'],
	JS => ['collections.js'],
	SPINNER => 1,
});

my @collections = ();
eval {
    @collections = Flavors::Data::Collection::List($dbh, {
		FILTER => $fdat->{FILTER},
		ORDERBY => $fdat->{ORDERBY},
    });
};

# TODO: DRY up, this is duplicated in songs.pl
my $sqlerror = "";
if ($fdat->{FILTER} && $@) {
	# assume this was an error in user's complex filter SQL
	$sqlerror = $@;
	$sqlerror =~ s/\n.*//s;
	$sqlerror =~ s/\(select \* from \(\s*//s;
}

my %songs;
my @songs = Flavors::Data::Song::List($dbh);
foreach my $song (@songs) {
	$songs{$song->{ID}} = $song;
}
my @tracks = Flavors::Data::Collection::TrackList($dbh);
my %tracks;
foreach my $song (@tracks) {
	if (!exists $tracks{$song->{COLLECTIONID}}) {
		$tracks{$song->{COLLECTIONID}} = [];
	}
	push(@{ $tracks{$song->{COLLECTIONID}} }, $song);
}

print Flavors::HTML::FilterControl($dbh, {
    FILTER => $fdat->{FILTER},
    PLACEHOLDER => $fdat->{PLACEHOLDER},
});

print qq{ <div class="post-nav"> };

print "<div class=\"collections clearfix\">";

my %colors;
foreach my $color (Flavors::Data::Tag::ColorList($dbh)) {
	$colors{$color->{NAME}} = $color;
}

foreach my $collection (@collections) {
	printf(qq{
			<div 
				data-id="%s"
				data-is-mix="%s"
				data-original-title="%s"
				data-tag-list="%s"
				data-date-acquired="%s"
				data-name="%s"
				data-artist="%s"
				data-rating="%s"
				data-energy="%s"
				data-mood="%s"
				data-last-export="%s"
				data-export-count="%s"
				class="collection has-details clearfix"
			>
		},
		$collection->{ID},
		$collection->{ISMIX} ? 1 : 0,
		$collection->{NAME},
		Flavors::Util::EscapeHTMLAttribute(join(" ", @{ $collection->{TAGS} })),
		$collection->{DATEACQUIRED},
		lc($collection->{NAME}),
		lc($collection->{ARTIST}),
		$collection->{RATING},
		$collection->{ENERGY},
		$collection->{MOOD},
		$collection->{LASTEXPORT},
		$collection->{EXPORTCOUNT},
	);

	my $image = sprintf("images/collections/%s.jpg", $collection->{ID});
	if (-e $image) {
		printf(qq{<img src="%s" class="album" />}, $image);
	}
	else {
		my $color = $colors{$collection->{COLOR}};
		my @tags = @{ $collection->{TAGS} }[0..3];
		printf(qq{
				<div class="mix" style="%s%s">
					%s
				</div>
			},
			$color ? ("background-color: #" . $color->{HEX} . ";") : "",
			$color->{WHITETEXT} ? " color: white; font-weight: bold;" : "",
			join("", map { "<div>$_</div>" } @tags),
		);
	}
	printf(qq{
			<div class="details">
				<div class="name">%s</div>
				<div class="artist">%s</div>
				<div class="export-icons">
					<br><br>
					<span class="glyphicon glyphicon-download"></span>
				</div>
				<div class="rating">%s</div>
				<br><div class="rating">%s</div>
				<br><div class="rating">%s</div>
			</div>
		},
		$collection->{NAME},
		$collection->{ARTIST},
		Flavors::HTML::Rating($collection->{RATING}, 'star'),
		Flavors::HTML::Rating($collection->{ENERGY}, 'fire'),
		Flavors::HTML::Rating($collection->{MOOD}, 'heart'),
	);

	my $exporttext = "";
	if ($collection->{EXPORTCOUNT} == 0) {
		$exporttext = "Never exported";
	}
	else {
		$exporttext = "Exported ";
		if ($collection->{EXPORTCOUNT} == 1) {
			$exporttext .= "once, on ";
		}
		else {
			if ($collection->{EXPORTCOUNT} == 2) {
				$exporttext .= "twice";
			}
			else {
				$exporttext .= $collection->{EXPORTCOUNT} . " times";
			}
			$exporttext .= "<br>Last exported ";
		}
		$exporttext .= " " . Flavors::Util::TrimDate($collection->{LASTEXPORT});
	}
	printf(qq{
			<div class="track-list clear">
				%s
				<div>Acquired %s</div>
				<ol>%s</ol>
			</div>
		},
		$exporttext,
		Flavors::Util::TrimDate($collection->{DATEACQUIRED}),
		join("", map { "<li>" . $_->{NAME} . "</li>" } @{ $tracks{$collection->{ID}} }),
	);
	print "</div>";
}
print "</div></div>";

# Modal for complex filtering
print Flavors::HTML::FilterModal($dbh, {
    ERROR => $sqlerror,
    FILTER => $fdat->{FILTER},
    HINTS => [qw(id name ismix dateacquired rating energy mood artist genre color tags lastexport exportcount)],
    PLACEHOLDER => $fdat->{PLACEHOLDER},
});

# Modal for new collection
print q{
	<div id="new-collection" class="modal">
		<div class="modal-dialog modal-lg">
			<div class="modal-content">
				<button type="button" class="close" data-dismiss="modal">
					<span aria-hidden="true">&times;</span><span class="sr-only">Close</span>
				</button>
				<div class="modal-header">
					<h4>
						<input type='text' name='name' placeholder='collection' />
						<label>
							<input type='checkbox' name='ismix' />
							is mix
						</label>
					</h4>
				</div>
				<div class="modal-body">
					<div class='song hide'>
						<span class='ordinal'>0</span>
						<input type='text' name='name' placeholder='song' />
						<input type='text' name='artist' placeholder='artist' />
						<input type='text' name='minutes' placeholder='0' />
						:
						<input type='text' name='seconds' placeholder='00' />
						<span class='glyphicon glyphicon-trash'></span>
					</div>
					<div id="add-song">
						<button class='btn btn-default btn-large'>
							<span class='glyphicon glyphicon-plus'></span>
						</button>
						<input type='text' value='1' />
					</div>
				</div>
				<div class="modal-footer">
					<button id='cancel-add-collection' class='btn btn-default btn-large'>
						cancel
					</button>
					<button id='save-collection' class='btn btn-primary btn-large'>
						save
					</button>
				</div>
			</div>
		</div>
	</div>
};

print Flavors::HTML::Footer();
