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
	my ($dbh, $args) = @_;

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
				<link href="bower_components/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet" type="text/css" />
                <link href="bower_components/jquery-minicolors/jquery.minicolors.css" rel="stylesheet" type="text/css" />
                <link href="bower_components/At.js/dist/css/jquery.atwho.min.css" rel="stylesheet" type="text/css" />
				<link href="/css/flavors.css" rel="stylesheet" type="text/css" />
				%s
				<script src="bower_components/jquery/dist/jquery.min.js"></script>
				<script src="bower_components/jquery-ui/jquery-ui.min.js"></script>
				<script src="bower_components/underscore/underscore-min.js"></script>
				<script src="bower_components/d3/d3.min.js"></script>
				<script src="bower_components/bootstrap/dist/js/bootstrap.min.js"></script>
				<script src="bower_components/jquery-minicolors/jquery.minicolors.min.js"></script>
                <script src="bower_components/Caret.js/dist/jquery.caret.min.js"></script>
                <script src="bower_components/At.js/dist/js/jquery.atwho.min.js"></script>
				<script src="/javascript/application.js"></script>
				<script src="/javascript/api.js"></script>
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

    # Visualization dropdown
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
			Visualizations <span class="caret"></span>
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

	# Category dropdown
	my @pages = qw(genres.pl colors.pl profiles.pl categories.pl);
	my %pagetitles = (
		'categories.pl' => 'Tags &rArr; Categories',
		'genres.pl' => 'Artists &rArr; Genres',
		'colors.pl' => 'Colors',
        'profiles.pl' => 'Profiles',
	);
	printf(qq{ <li class='dropdown %s'> }, (grep { $url eq $_ } @pages) ? "active" : "");
	print qq{
		<a class='dropdown-toggle' data-toggle='dropdown' role='label' href='#'>
			Data <span class="caret"></span>
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

	print qq{ </ul> };

	print $args->{BUTTONS};

    my $count = Flavors::Data::Song::Count($dbh, {
        FILTER => "echonestid is null",
    });
    if ($count) {
        print qq{
            <button id="echo-nest-populate" type="button" class="btn btn-xs btn-default">
                <i class="glyphicon glyphicon-refresh"></i>
                EchoNest
            </button>
        };
    }

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
#   combination. Depends on jquery.atwho.min.css, 
#   jquery.caret.min.js, and jquery.atwho.min.js.
#
# Params:
#   FILTER
#
# Return Value: HTML
################################################################
sub FilterControl {
    my ($dbh, $args) = @_;

    my $iconcount = $args->{FILTER} ? 2 : 0;
    return sprintf(qq{
    		<div id="filter-container">
                <div id="simple-filter">
                    <div id="last-query">
    			        <span class='glyphicon glyphicon-search'></span>
    			        <span class='glyphicon glyphicon-remove hide'></span>
                        <span id="last-query-text"></span>
                    </div>
		    	    <input id='filter' type='text'/>
	    		</div>
    			<div id="complex-filter-trigger" class="icon-count-%i">
			    	<a href='#'>%s</a> %s %s
		    	</div>
	    	</div>
        },
    	$iconcount,
    	$args->{FILTER} || "advanced search",
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
#
# Return Value: HTML
################################################################
sub FilterModal {
    my ($dbh, $args) = @_;

    return sprintf(qq{
			<div id="complex-filter" class="modal" data-hints="%s">
				<div class="modal-dialog">
					<div class="modal-content">
						<div class="modal-body">
		
							<div class="alert alert-danger %s" id="sql-error">%s</div>
		
							<form method="POST">
								<textarea name=filter rows=3 placeholder="type &quot;#&quot; to see available columns">%s</textarea>
								<input type="button" value="Filter" class="btn btn-default btn-lg"/>
								<input type="hidden" name="placeholder" value="" />
							</form>
                            %s
						</div>
					</div>
				</div>
			</div>
        },
        Flavors::Util::EscapeHTMLAttribute(JSON::to_json($args->{HINTS} || [])),
    	$args->{ERROR} ? "" : "hide",
	    $args->{ERROR},
	    $args->{FILTER},
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
    return sprintf(qq{
        <div id="echo-nest" class="modal" data-api-key="%s">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <div class="pull-right">
                            <a href="http://the.echonest.com/" class="img-link" target="_blank">
                                <img src="images/echo_nest.png" />
                            </a>
                        </div>
                        <h4 class="modal-title"></h4>
                    </div>
                    <div class="modal-body">
                        <div class="alert alert-danger hide"></div>
                        <table class="table table-striped table-hover">
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    }, Flavors::Util::Config->{echo_nest_api_key}) . qq{
        <script type="text/template" id="echo-nest-disambiguation-row">
            <tr class="clickable disambiguation" data-id="<%= id %>">
                <td class="col-sm-4"><%= artist_name %></td>
                <td class="col-sm-4"><%= title %></td>
                <td class="col-sm-4">
                    <ul class="list-unstyled">
                        <% _.each(albums, function(album) { %>
                            <li><%= album %></li>
                        <% }) %>
                    </ul>
                </td>
            </tr>
        </script>
        <script type="text/template" id="echo-nest-summary-row">
            <% for (var i in pairs) { %>
                <tr>
                    <td><%= pairs[i].key %></td>
                    <td><%= pairs[i].value %></td>
                </tr>
            <% } %>
        </script>
    } . qq{
		<div id="tooltip" class="hide">
			<div></div>
			<ul></ul>
		</div>
		</body></html>
	};
}

1;
