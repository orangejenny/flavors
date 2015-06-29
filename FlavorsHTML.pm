package FlavorsHTML;

use strict;
use Data::Dumper;
use FlavorsData;
use JSON qw(to_json);

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
	my $html = "<div class='tag' category='$tag->{CATEGORY}'>$tag->{TAG}";
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
	my ($rating, $symbol) = @_;

	if (!$rating && $symbol) {
		$rating = 5;
		$symbol .= " blank";
	}

	my $html;
	while ($rating > 0) {
		$html .= $symbol ? "<span class='glyphicon glyphicon-$symbol'></span>" : "*";
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
#		INITIALPAGEDATA: (optional) hash to convert to JSON
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
	$url =~ s/.*\///;	# strip anything but foo.pl
	my $title = $url;
	$title =~ s/\..*//g;

	printf(qq{
		<html>
			<head>
				<link href="/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet" type="text/css" />
				<link href="/css/flavors.css" rel="stylesheet" type="text/css" />
				<link href="/css/%s.css" rel="stylesheet" type="text/css" />
				<script type="text/javascript" src="/javascript/thirdparty/jquery-1.7.1.min.js"></script>
				<script type="text/javascript" src="/javascript/thirdparty/jquery-ui.min.js"></script>
				<script type="text/javascript" src="/javascript/thirdparty/underscore-min.js"></script>
				<script type="text/javascript" src="/bootstrap/dist/js/bootstrap.min.js"></script>
				<script type="text/javascript" src="/javascript/application.js"></script>
				<script type="text/javascript" src="/javascript/%s.js"></script>
				<title>$args->{TITLE}</title>
			</head>
			<body>
			<div id="loading">
				<div>
					<div></div>
				</div>
			</div>
	}, $title, $title);

	if ($args->{INITIALPAGEDATA}) {
		printf(qq{ <div id="initial-page-data">%s</div> }, JSON::to_json($args->{INITIALPAGEDATA}));
	}

	my @urls = qw(
		songs.pl
		collections.pl
		categories.pl
		tags.pl
		lab.pl
	);

	print qq{ <div class="navbar-container"><nav class="navbar navbar-default"> };

	printf(qq{
					<a class='navbar-brand' href='#'>Flavors</a>
					<ul class="nav navbar-nav">
						%s
					</ul>
	}, join("", map {
		sprintf("<li class='%s'><a href='%s'>%s</a></li>", $url eq $_ ? 'active' : '', $_, ucfirst($1))
		if $_ =~ m/(.*)\.[^.]+/	# shorthand; all elements will match
	} @urls));

	print qq{
		<button type="button" class="export-button btn btn-xs btn-info pull-right" data-os="mac">
			<span class="glyphicon glyphicon-home"></span>
			Export
		</button>
		<button type="button" class="export-button btn btn-xs btn-info pull-right" data-os="pc">
			<span class="glyphicon glyphicon-briefcase"></span>
			Export
		</button>
	} unless $args->{HIDEEXPORT};

	print qq { </nav> };

	print qq{
						</div>
					</div>
				</div>
			</div>
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
		CONTENT => join("", map { Tag($_) } @tags),
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

	my @songs = FlavorsData::SongList($dbh, {
		FILTER => sprintf("exists (select 1 from songtag where id=songid and tag = '%s')", $args->{TAG}),
	});
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
		$html .= sprintf(qq{
			<div class='category' category='%s'>
				<div class='header clickable'>
					%s
				</div>
				<div class='category-tags'>
					%s
				</div>
			</div>
		}, $category, uc($category), join("", map { FlavorsHTML::Tag({ TAG => $_ }) } @categorytags));
	}
	$html .= "</div>";

	# Uncategorized items
	$html .= "<div class=\"uncategorized\">";
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
