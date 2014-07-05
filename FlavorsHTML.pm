package FlavorsHTML;

use strict;
use Data::Dumper;
use FlavorsData;

################################################################
# Tag
#
# Description: Generates HTML to display a tag and its frequency
#
# Params: tag (CATEGORY and COUNT may or may not be present)
#
# Return Value: HTML
################################################################
sub Tag {
	my ($tag) = @_;
	my $html = "<div class='tag ui-corner-all' category='$tag->{CATEGORY}'>$tag->{TAG}";
	if ($tag->{COUNT}) {
		$html .= "<span class='tag-count'>($tag->{COUNT})</span>";
	}
	$html .= "</div> ";
	return $html;
}

################################################################
# Rating
#
# Description: Generates HTML to display a rating as stars
#
# Params: integer, likely 1-5
#
# Return Value: HTML
################################################################
sub Rating {
	my ($rating) = @_;

	my $html;
	while ($rating > 0) {
		#$html .= qq{<i class="icon icon-star-empty"></i>};
		$html .= "*";
		$rating--;
	}

	return $html;
}

################################################################
# Header
#
# Description: Generates HTML for page header, meanu, etc.
#
# Params:
#		TITLE: (optional) page title
#
# Return Value: HTML
################################################################
sub Header {
	my ($args) = @_;

	if ($args->{TITLE}) {
		$args->{TITLE} = "Flavors: " . $args->{TITLE};
	}
	else {
		$args->{TITLE} = "Flavors";
	}

	my $url = $0;

	print qq{
		<html>
			<head>
				<link href="/css/bootstrap.css" rel="stylesheet" type="text/css" />
				<link href="/css/flavors.css" rel="stylesheet" type="text/css" />
				<link href="/css/cupertino/jquery-ui-1.8.17.custom.css" rel="stylesheet" type="text/css" />
				<script type="text/javascript" src="/javascript/jquery-1.7.1.min.js"></script>
				<script type="text/javascript" src="/javascript/jquery-ui-1.8.17.custom.min.js"></script>
				<script type="text/javascript" src="/javascript/bootstrap.min.js"></script>
				<script type="text/javascript" src="/javascript/application.js"></script>
				<title>$args->{TITLE}</title>
			</head>
			<body>
				<div class="navbar-container">
					<div class="navbar">
						<div class="navbar-inner">
							<div class="brand">Flavors</div>
	};

	my @pages = (
		{ url => "songs.pl" },
		{ url => "collections.pl" },
		{ url => "categories.pl" },
		{ url => "tags.pl" },
		{ url => "lab.pl" },
	);
	my $currentpage;
	foreach my $page (@pages) {
		if (!$page->{name}) {
			$page->{name} = $page->{url};
			$page->{name} =~ s/\..*$//;
			$page->{name} = ucfirst($page->{name});
		}
		$currentpage = $page if $page->{url} eq $url;
	}

	print sprintf(qq{
							<ul class="nav">
								<li class="dropdown">
									<a href="#" class="dropdown-toggle" data-toggle="dropdown" role="button" id="menu-button">
										%s
										<b class="caret"></b>
									</a>
									<ul class="dropdown-menu" role="menu" aria-labelledby="menu-button">
		},
		$currentpage->{name},
	);
	foreach my $page (@pages) {
		print sprintf(qq{
				<li><a href="%s">%s</a></li>
			},
			$page->{url},
			$page->{name},
		) unless $page->{url} eq $currentpage->{url};
	}
	print qq{
									</ul>
								</li>
							</ul>
	};

	print qq{
		<button type="button" class="export-button btn btn-mini btn-info pull-right" data-os="mac">
			<span class="icon-white icon-home"></span>
			Export
		</button>
		<button type="button" class="export-button btn btn-mini btn-info pull-right" data-os="pc">
			<span class="icon-white icon-briefcase"></span>
			Export
		</button>
	} unless $args->{HIDEEXPORT};

	print qq{
						</div>
					</div>
				</div>
	};
}

################################################################
# CollectionDetails
#
# Description: Generates HTML for dialog to view collection
#
# Params:
#		ID
#
# Return Value: HTML
################################################################
sub CollectionDetails {
	my ($dbh, $args) = @_;

	my $collection = FlavorsData::CollectionList($dbh, { ID => $args->{ID} });
	my @tracks = FlavorsData::TrackList($dbh, { COLLECTIONIDS => $args->{ID} });

	my $html = sprintf(qq{
		<table>
			<tr>
				<th>Name</th>
				<td>%s [%s]</td>
				<th>Rating</th>
				<td>%s</td>
			</tr>
			<tr>
				<th>Acquired</th>
				<td>%s</td>
				<th>Energy</th>
				<td>%s</td>
			</tr>
			<tr>
				<td></td>
				<td></td>
				<th>Mood</th>
				<td>%s</td>
			</tr>
			<tr>
				<th>Tracks</th>
				<td colspan=3>
		}, 
		$collection->{NAME},
		$collection->{ID},
		Rating($collection->{RATING}),
		$collection->{DATEACQUIRED},
		Rating($collection->{ENERGY}),
		Rating($collection->{MOOD}),
	);

	my %tags;
	foreach my $track (@tracks) {
		$html .= qq{
			$track->{TRACKNUMBER}. $track->{NAME} ($track->{ARTIST})<br>
		};

		my @strings = split(/\s+/, $track->{TAGS});
		foreach my $string (@strings) {
			$tags{$string}++;
		}
	}
	$html .= qq{
			</td>
		</tr>
	};

	my @counts;
	foreach my $tag (keys %tags) {
		push @counts, {
			TAG => $tag,
			COUNT => $tags{$tag},
		};
	}
	@counts = sort { $b->{COUNT} <=> $a->{COUNT} || $a->{TAG} <=> $b->{TAG} } @counts;

	$html .= sprintf(qq{
			<tr>
				<th>Tags</th>
				<td colspan=3>%s</td>
			</tr>
		},
		join("", map { Tag($_) } @counts),
	);

	$html .= qq{
		</table>
	};

	return {
		TITLE => $collection->{NAME},
		CONTENT => $html,
	};
}

################################################################
# TagDetails
#
# Description: Generates HTML for dialog to view related tags
#
# Params:
#		TAG
#
# Return Value: HTML
################################################################
sub TagDetails {
	my ($dbh, $args) = @_;

	my @tags = FlavorsData::TagList($dbh, { RELATED => $args->{TAG} });

	return {
		TITLE => "Related Tags: $args->{TAG}",
		CONTENT => "<div style='text-align: center;'>" . join("", map { Tag($_) } @tags) . "</div>",
	};
}

################################################################
# TagSongList
#
# Description: Generates HTML for dialog to view all songs with
# 	given tag.
#
# Params:
# 	TAG
#
# Return Value: HTML
################################################################
sub TagSongList {
	my ($dbh, $args) = @_;

	my @songs = FlavorsData::SongList($dbh, { TAGS => $args->{TAG} });
	@songs = sort { $a->{ARTIST} cmp $b->{ARTIST} || $a->{NAME} cmp $b->{NAME} } @songs;

	return {
		TITLE => "Songs tagged with '$args->{TAG}'",
		CONTENT => "<ul class=plain>" . join("", map { "<li>" . $_->{NAME} . " (" . $_->{ARTIST} . ")</li>" } @songs) . "</ul>",
	}
}

################################################################
# Categorize
#
# Description: Generates HTML for a catgorization UI
#
# Params:
#		CATEGORIES: hashref of category name => items
#		UNCATEGORIZED: arrayref of items with a category
#
# Return Value: HTML
################################################################
sub Categorize {
	my ($dbh, $args) = @_;

	my %categories = %{ $args->{CATEGORIES} };
	my @uncategorized = @{ $args->{UNCATEGORIZED} };
	my $html;

	# Categories
	$html .= "<div class=\"clearfix\">";
	foreach my $category (sort keys %categories) {
		my @categorytags = @{ $categories{$category} };
		my $width = sqrt(scalar(@categorytags)) * 5;
		if ($width > 100) {
			$width = 100;
		}
		$width = 20;
		$html .= sprintf(qq{
			<div class='category ui-corner-all' style='width: %s%%;' category='%s'>
				<div style='cursor: pointer;' onclick='ToggleCategory(this)'>
					%s
				</div>
				<div class='category-tags'>
					%s
				</div>
			</div>
		}, $width, $category, uc($category), join("", map { FlavorsHTML::Tag({ TAG => $_ }) } @categorytags));
	}
	$html .= "</div>";

	# Uncategorized items
	$html .= "<div style=\"text-align: center;\">";
	foreach my $item (@uncategorized) {
		$html .= FlavorsHTML::Tag({ TAG => $item });
	}
	$html .= "</div>";

	return $html;
}

################################################################
# Footer
#
# Description: Generates HTML for page footer
#
# Return Value: HTML
################################################################
sub Footer {
	return "</body></html>";
}

1;
