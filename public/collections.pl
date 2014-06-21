#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsData;
use FlavorsHTML;
use FlavorsUtils;
use POSIX qw(strftime);

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtils::Fdat($cgi);
FlavorsHTML::Header({
	TITLE => "Collections",
});

my @collections = FlavorsData::CollectionList($dbh);
my %songs;
my @songs = FlavorsData::SongList($dbh);
foreach my $song (@songs) {
	$songs{$song->{ID}} = $song;
}
my @tracks = FlavorsData::TrackList($dbh);
my %tracks;
foreach my $song (@tracks) {
	if (!exists $tracks{$song->{COLLECTIONID}}) {
		$tracks{$song->{COLLECTIONID}} = [];
	}
	push(@{ $tracks{$song->{COLLECTIONID}} }, $song);
}

print q{
	<script type="text/javascript">
		function FilterCollections() {
			var collectionfilter = jQuery("#collection-filter").val().toLowerCase();
			var tagfilters = jQuery("#tag-filter").val().split(/\s+/);
			var showalbums = jQuery("#is-mix input:checked[value=0]").length;
			var showmixes = jQuery("#is-mix input:checked[value=1]").length;
			jQuery(".collection").each(function() {
				var $collection = jQuery(this);
				var show = true;

				// IsMix filter
				if ($collection.attr("data-is-mix") == 1) {
					show = showmixes;
				}
				else {
					show = showalbums;
				}

				// Collection filter
				if (show && ($collection.attr("data-name") + $collection.attr("data-artist")).indexOf(collectionfilter) == -1) {
					show = false;
				}

				// Tag filter
				var tags = $collection.attr("data-tag-list");
				for (var i = 0; show && i < tagfilters.length; i++) {
					if (tags.indexOf(tagfilters[i]) == -1) {
						show = false;
					}
				}

				if (show) {
					$collection.show();
				}
				else {
					$collection.hide();
				}
			});
		}

		jQuery(document).ready(function() {
			// Popovers with top tags and track lists
			jQuery(".collection").popover({
				html: true,
				placement: "left",
				trigger: "hover"
			});

			// Controls: Toggle details
			jQuery("#show-details").click(function() {
				if (jQuery(this).is(":checked")) {
					jQuery(".collection").addClass("has-details");
					jQuery(".collection .details").show();
				}
				else {
					jQuery(".collection").removeClass("has-details");
					jQuery(".collection .details").hide();
				}
			});

			// Controls: Sort collections
			jQuery(".sort-menu .dropdown-menu a").click(function() {
				var $link = jQuery(this);
				var $container = jQuery(".collections");
				var attribute = "data-" + $link.text().toLowerCase().replace(" ", "-");

				var collections = [];
				$container.find(".collection").each(function() { collections.push(jQuery(this).detach()); });

				var ascendingSort = function(a, b) {
					a = a.attr(attribute).toLowerCase();
					b = b.attr(attribute).toLowerCase();
					return a > b ? 1 : (a < b ? -1 : 0);
				}
				var descendingSort = function(a, b) {
					a = a.attr(attribute).toLowerCase();
					b = b.attr(attribute).toLowerCase();
					return b > a ? 1 : (b < a ? -1 : 0);
				}

				collections = collections.sort(attribute.match(/name|artist/) ? ascendingSort : descendingSort);
				for (var i in collections) {
					$container.append(jQuery(collections[i]));
				}

				// Change status of dropdown and re-sort links
				var $dropdown = $link.closest(".sort-menu");
				var $current = $dropdown.find(".dropdown-toggle .current");
				var temp = $current.text();
				$current.text($link.text());
				$link.text(temp);
				var $menu = $dropdown.find(".dropdown-menu");
				var links = [];
				$menu.find("li").each(function() { links.push(jQuery(this)); });
				links = links.sort(function(a, b) { return a.text() > b.text() ? 1 : (a.text() < b.text() ? -1 : 0); });
				for (var i in links) {
					$menu.append(links[i]);
				}
			});

			// Controls: Filter collections
			jQuery("#is-mix input:checkbox").click(FilterCollections);
			jQuery("#collection-filter, #tag-filter").keyup(FilterCollections);

			// Drag collections
			jQuery(".collection").draggable({
				helper: 'clone',
				opacity: 0.5,
				zIndex: 2
			});

			// Drop collections onto target
			var collections = [];
			jQuery("#export-list").droppable({
				activeClass: "export-list-active",
				hoverClass: "export-list-hover",
				drop: function(event, ui) {
					var $this = jQuery(this);
					var $ul = $this.find("ul");
					var li = "<li data-id=\"" + ui.draggable.attr("data-id") + "\">";
					li += ui.draggable.find(".name").text();
					li += "</li>";
					$ul.append(li);
					collections.push(ui.draggable.detach());
					jQuery(".controls .clear").show();
				}
			});

			// "Clear" button
			jQuery("button.clear").click(function() {
				for (var i in collections) {
					jQuery(".collections").prepend(collections[i]);
				}
				jQuery(this).closest(".controls").find("#export-list ul").html("");
				collections = [];
			});

			// Export collections
			jQuery(".export-button").click(function() {
				var collectionids = [];
				var collections = jQuery("#export-list li");
				if (!collections.length) {
					collections = jQuery(".collection:visible");
				}
				collections.each(function() {
					collectionids.push(jQuery(this).attr("data-id"));
				});
				if (!collectionids.length) {
					alert("No collections selected");
					return;
				}
				ExportPlaylist({
					COLLECTIONIDS: collectionids,
				});
			});
		});
	</script>
};

print qq{ <link href="/css/collections.css" rel="stylesheet" type="text/css" /> };

print qq{
	<div class="controls">
		Collections:
		<input type="text" id="collection-filter">
		Tags:
		<input type="text" id="tag-filter">
		<div class="dropdown sort-menu">
			Sort by
			<a class="dropdown-toggle" data-toggle="dropdown" role="label" href="#">
				<span class="current">Date Acquired</span>
				<b class="caret"></b>
			</a>
			<ul class="dropdown-menu">
				<li><a href="#">Artist</a></li>
				<li><a href="#">Energy</a></li>
				<li><a href="#">Export Count</a></li>
				<li><a href="#">Last Export</a></li>
				<li><a href="#">Mood</a></li>
				<li><a href="#">Name</a></li>
				<li><a href="#">Rating</a></li>
			</ul>
		</div>
		<br>
		<div id="is-mix">
			<label>
				<input type="checkbox" value="0" checked>
				Albums
			</label>
			<label>
				<input type="checkbox" value="1" checked>
				Mixes
			</label>
		</div>
		<label>
			<input type="checkbox" id="show-details" checked>
			Show Details
		</label>
		<br><br>
		<div class="well" id="export-list">
			<ul></ul>
			<button class="btn btn-small hide clear">Clear</button>
		</div>
	</div>
};

print "<div class=\"collections clearfix\" style=\"margin-left: 250px;\">";

my %colors;
foreach my $color (FlavorsData::ColorList($dbh)) {
	$colors{$color->{NAME}} = $color;
}

foreach my $collection (@collections) {
	my $dateacquiredstring = $collection->{DATEACQUIRED};
	$dateacquiredstring  =~ s/ (.*)/<span style='display:none;'>$1<\/span>/;
	printf(qq{
			<div 
				data-id="%s"
				data-is-mix="%s"
				data-original-title="%s"
				data-content="<ol>%s</ol>"
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
		FlavorsUtils::EscapeHTMLAttribute(join("", map { "<li>" . $_->{NAME} . "</li>" } @{ $tracks{$collection->{ID}} })),
		FlavorsUtils::EscapeHTMLAttribute($collection->{TAGLIST}),
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
		printf(qq{
				<div class="mix" style="%s%s">
					<br>%s
				</div>
			},
			$color ? ("background-color: #" . $color->{HEX} . ";") : "",
			$color->{WHITETEXT} ? " color: white; font-weight: bold;" : "",
			$collection->{NAME},
		);
	}
	printf(qq{
			<div class="details">
				<div class="name">%s</div>
				<div class="artist">%s</div>
				<div class="date-acquired">%s</div>
				<div class="rating">%s</div>
			</div>
		},
		$collection->{NAME},
		$collection->{ARTIST},
		$dateacquiredstring,
		FlavorsHTML::Rating($collection->{RATING}),
	);
	print "</div>";
}
print "</div>";

print FlavorsHTML::Footer();
