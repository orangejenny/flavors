package Flavors::HTML;

use strict;
use Flavors::Data::Song;
use Flavors::Data::Tag;
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
#		CSS (optional): arrayref of strings
#		JS (optional): arrayref of strings
#		FDAT (optional)
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

	printf(qq{
		<html>
			<head>
				<link href="/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet" type="text/css" />
				<link href="/css/flavors.css" rel="stylesheet" type="text/css" />
				%s
				<script type="text/javascript" src="/javascript/thirdparty/jquery-1.7.1.min.js"></script>
				<script type="text/javascript" src="/javascript/thirdparty/jquery-ui.min.js"></script>
				<script type="text/javascript" src="/javascript/thirdparty/underscore-min.js"></script>
				<script type="text/javascript" src="/javascript/thirdparty/d3.min.js"></script>
				<script type="text/javascript" src="/bootstrap/dist/js/bootstrap.min.js"></script>
				<script type="text/javascript" src="/javascript/application.js"></script>
				%s
				<title>$args->{TITLE}</title>
			</head>
			<body>
			<div class="loading%s">
				<div>
					<div></div>
				</div>
			</div>
		},
		join("", map { sprintf(qq{ <link href="/css/%s" rel="stylesheet" type="text/css" /> }, $_) } @{ $args->{CSS} || [] }),
		join("", map { sprintf(qq{ <script type="text/javascript" src="/javascript/%s"></script> }, $_) } @{ $args->{JS} || [] }),
		$args->{SPINNER} ? "" : " hide",
		$args->{TITLE},
	);

	if ($args->{INITIALPAGEDATA}) {
		printf(qq{ <div id="initial-page-data">%s</div> }, JSON::to_json($args->{INITIALPAGEDATA}));
	}

	my @urls = qw(
		songs.pl
		collections.pl
		tags.pl
	);

	print qq{
		<div class="navbar-container">
			<nav class="navbar navbar-default">
				<a class='navbar-brand' href='#'>Flavors</a>
					<ul class="nav navbar-nav">
	};

	# Single menu items
	foreach my $u (@urls) {
		if ($u =~ m/(.*)\.[^.]+/) {		# all elements will match
			printf("<li class='%s'><a href='%s'>%s</a></li>", $u eq $url ? 'active' : '', $u, ucfirst($1));
		}
	}

	# Category dropdown
	my @pages = qw(categories.pl genres.pl colors.pl);
	my %pagetitles = (
		'categories.pl' => 'Tags &rArr; Categories',
		'genres.pl' => 'Artists &rArr; Genres',
		'colors.pl' => 'Colors',
	);
	printf(qq{ <li class='dropdown %s'> }, (grep { $url eq $_ } @pages) ? "active" : "");
	print qq{
		<a class='dropdown-toggle' data-toggle='dropdown' role='label' href='#'>
			Categories <span class="caret"></span>
		</a>
	};
	print qq{ <ul class="dropdown-menu"> };
	foreach my $page (@pages) {
		printf(qq{ <li class='%s'><a href='%s'>%s</a></li> }, 
			$url eq $page ? "active" : "",
			$page,
			$pagetitles{$page},
		);
	}
	print qq{ </ul> };
	print qq{ </li> };

	# Data dropdown
	my %icons = (
		rating => 'star',
		energy => 'fire',
		mood => 'heart',
		matrix => 'th-large',
		acquisitions => 'shopping-cart',
		timeline => 'time',
	);
	my @datapages = qw(matrix acquisitions timeline);
	printf(qq{ <li class='dropdown %s'> }, (grep { $url eq $_ . ".pl" } ('facet', @datapages)) ? "active" : "");
	print qq{
		<a class='dropdown-toggle' data-toggle='dropdown' role='label' href='#'>
			Data <span class="caret"></span>
		</a>
	};
	print qq{ <ul class="dropdown-menu"> };
	$args->{FDAT}->{FACET} ||= 'rating';
	$args->{FDAT}->{FACET} = lc($args->{FDAT}->{FACET});
	foreach my $facet (qw(rating energy mood)) {
		printf(qq{ <li class='%s'><a href='facet.pl?facet=%s'><i class='glyphicon glyphicon-%s'></i> %s</a></li> }, 
			$url eq 'facet.pl' && $args->{FDAT}->{FACET} eq $facet ? "active" : "",
			$facet,
			$icons{$facet},
			ucfirst($facet),
		);
	}
	foreach my $page (@datapages) {
		printf(qq{ 
				<li class='%s'><a href='%s.pl'>%s%s</a></li> 
			}, 
			($url eq $page . ".pl" ? 'active' : ''), 
			$page, 
			exists $icons{$page} ? sprintf("<i class='glyphicon glyphicon-%s'></i> ", $icons{$page}) : "",
			ucfirst($page),
		);
	}
	print qq{ </ul> };
	print qq{ </li> };
	print qq{ </ul> };

	print $args->{BUTTONS};

	print qq{
							</nav>
						</div>
					</div>
				</div>
			</div>
	};
}

################################################################
# ExportControl
#
# Description: Generates HTML for button to export playlist
#
# Return Value: HTML
################################################################
sub ExportControl {
	return qq{
		<button type="button" class="export-button btn btn-xs btn-info">
			<span class="glyphicon glyphicon-download"></span>
			Export
		</button>
	};
}

################################################################
# SelectionControl
#
# Description: Generates HTML for buttons to act on selections
#
# Return Value: HTML
################################################################
sub SelectionControl {
	return qq{
		<span class="selection-buttons hide">
			<button class="btn btn-info btn-xs clear-button">
				<i class="glyphicon glyphicon-remove"></i>
				Clear Selection
			</button>
			<button class="btn btn-info btn-xs songs-button">
				<i class="glyphicon glyphicon-share-alt"></i>
				View Songs
			</button>
		</span>
	};
}

################################################################
# FilterControl
# 
# Description: Generates HTML for simple and complex filter
#   combination.
#
# Params:
#   FILTER
#   PLACEHOLDER
#
# Return Value: HTML
################################################################
sub FilterControl {
    my ($dbh, $args) = @_;

    my $iconcount = $args->{FILTER} ? 2 : ($args->{PLACEHOLDER} ? 1 : 0);
    return sprintf(qq{
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
    	$args->{PLACEHOLDER} || $args->{FILTER} || "advanced search",
    	$iconcount == 2 ? "<span class='glyphicon glyphicon-refresh'></span>" : "",
    	$iconcount > 0 ? "<span class='glyphicon glyphicon-remove'></span>" : "",
    );
}

################################################################
# FilterModal
#
# Description: Generates HTML for modal with advanced filter form
#
# Params:
#   ERROR
#   FILTER
#   HINTS
#   PLACEHOLDER
#
# Return Value: HTML
################################################################
sub FilterModal {
    my ($dbh, $args) = @_;

    return sprintf(qq{
			<div id="complex-filter" class="modal">
				<div class="modal-dialog">
					<div class="modal-content">
						<div class="modal-body">
		
							<div class="alert alert-danger %s" id="sql-error">%s</div>
		
							<form method="POST">
								<textarea name=filter rows=3 placeholder="%s">%s</textarea>
								<input type="button" value="Filter" class="btn btn-default btn-lg"/>
								<input type="hidden" name="orderBy" value="" />
								<input type="hidden" name="placeholder" value="" />
							</form>
		
							<div id="column-hints">
                                %s
							</div>
                            %s
						</div>
					</div>
				</div>
			</div>
        },
    	$args->{ERROR} ? "" : "hide",
	    $args->{ERROR},
    	$args->{PLACEHOLDER},
	    $args->{FILTER},
        join(", ", @{ $args->{HINTS} || [] }),
        $args->{ADDITIONALMARKUP},
    );
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

	my @songs = Flavors::Data::Song::List($dbh, {
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
#		TABLE: one of qw(artistgenre tagcategory)
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
			<div class='category' category='%s' data-table='%s'>
				<div class='header clickable'>
					%s
				</div>
				<div class='category-tags hide'>
					%s
				</div>
			</div>
		}, $category, $args->{TABLE}, $category, join("", map { Flavors::HTML::Tag({ TAG => $_ }) } @categorytags));
	}
	$html .= "</div>";

	# Uncategorized items
	$html .= "<div class=\"uncategorized\">";
	foreach my $item (@uncategorized) {
		$html .= Flavors::HTML::Tag({ TAG => $item });
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
	return qq{
		<div id="tooltip" class="hide">
			<div></div>
			<ul></ul>
		</div>
		</body></html>
	};
}

1;
