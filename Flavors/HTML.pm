package Flavors::HTML;

use strict;
use Flavors::Data::Collection;
use Flavors::Data::Playlist;
use Flavors::Data::Song;
use Flavors::Data::Tag;
use JSON qw(to_json);


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
        $html .= $symbol ? "<span class='fas fa-$symbol'></span>" : "*";
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
#        TITLE: (optional) page title
#        INITIALPAGEDATA: (optional) hash to convert to JSON
#        JS (optional): arrayref of strings
#        FDAT (optional)
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
    $url =~ s/.*\///;    # strip anything but foo.pl

    printf(qq{
        <html>
            <head>
                <link href="bower_components/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet" type="text/css" />
                <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.7.1/css/all.css" integrity="sha384-fnmOCqbTlWIlj8LyTjo7mOUStjsKC4pOpQbqyi7RrhN7udi9RwhKkMHpvLbHG9Sr" crossorigin="anonymous">
                <link href="bower_components/jquery-minicolors/jquery.minicolors.css" rel="stylesheet" type="text/css" />
                <link href="bower_components/At.js/dist/css/jquery.atwho.min.css" rel="stylesheet" type="text/css" />
                <link href="/css/flavors.css" rel="stylesheet" type="text/css" />
                <script src="bower_components/jquery/dist/jquery.min.js"></script>
                <script src="bower_components/jquery-ui/jquery-ui.min.js"></script>
                <script src="bower_components/underscore/underscore-min.js"></script>
                <script src="bower_components/d3/d3.js"></script>
                <script src="bower_components/bootstrap/dist/js/bootstrap.min.js"></script>
                <script src="bower_components/jquery-minicolors/jquery.minicolors.min.js"></script>
                <script src="bower_components/Caret.js/dist/jquery.caret.min.js"></script>
                <script src="bower_components/At.js/dist/js/jquery.atwho.min.js"></script>
                <script src="/javascript/application.js"></script>
                <script src="/javascript/api.js"></script>
                %s
                <title>%s</title>
            </head>
            <body>
            <div class="loading">
                <div>
                    <div></div>
                </div>
            </div>
        },
        join("", map { sprintf(qq{ <script type="text/javascript" src="/javascript/%s"></script> }, $_) } @{ $args->{JS} || [] }),
        $args->{TITLE},
    );

    if ($args->{INITIALPAGEDATA}) {
        printf(qq{ <div id="initial-page-data" class="hide">%s</div> }, JSON::to_json($args->{INITIALPAGEDATA}));
    }

    my @pages = (
        { name => 'songs', icon => 'music' },
        { name => 'collections', icon => 'compact-disc' },
        { name => 'tags', icon => 'tag' },
        { name => 'rating', icon => 'star', url => 'facet.pl?facet=rating' },
        { name => 'energy', icon => 'fire', url => 'facet.pl?facet=energy' },
        { name => 'mood', icon => 'heart', url => 'facet.pl?facet=mood' },
        { name => 'matrix', icon => 'table' },
        { name => 'acquisitions', icon => 'shopping-cart' },
        { name => 'timeline', icon => 'calendar-alt' },
        { name => 'network', icon => 'globe-africa' },
    );

    print qq{
        <div class="navbar-container">
            <nav class="navbar navbar-default">
                <a class='navbar-brand' href='#'>Flavors</a>
                    <ul class="nav navbar-nav">
    };

    # Single menu items
    my $facet = $args->{FDAT}->{FACET} || "rating";
    foreach my $p (@pages) {
        my $pageurl = $p->{url} || ($p->{name} . ".pl");
        printf(qq{
                <li class='%s'>
                    <a href='%s'>
                        <i class="fas fa-%s"></i>
                        %s
                    </a>
                </li>
            },
            $url eq $pageurl || $url eq "facet.pl" && $p->{name} eq $facet ? 'active' : '',
            $pageurl,
            $p->{icon},
            ucfirst($p->{name})
        );
    }

    # Data entry dropdown
    my @pages = qw(genres.pl profiles.pl categories.pl);
    my %pagetitles = (
        'categories.pl' => 'Tags &rArr; Categories',
        'genres.pl' => 'Artists &rArr; Genres',
        'profiles.pl' => 'Profiles',
    );
    printf(qq{ <li class='dropdown %s'> }, (grep { $url eq $_ } @pages) ? "active" : "");
    print qq{
        <a class='dropdown-toggle' data-toggle='dropdown' role='label' href='#'>
            <i class='fas fa-database'></i> Data <span class="caret"></span>
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

    print "<div class='controls'>" . $args->{BUTTONS} . "</div>";

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
    my $paths = Flavors::Util::Config->{paths};
    return sprintf(qq{
        <div class="dropdown export-dropdown pull-right">
            <button class="btn btn-info btn-xs dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="true">
                <span class="fas fa-cloud-download-alt"></span>
                Export
                <span class="caret"></span>
            </button>
            <ul class="dropdown-menu">%s</ul>
        </div>
    }, join("", map { sprintf(qq{
        <li><a href='#' data-name='%s'><span class='fas %s'></span> %s</a></li>
    }, $_->{name}, $_->{icon}, ucfirst($_->{name})) } @{ $paths }));
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
                <i class="fas fa-times"></i>
                Clear Selection
            </button>
            <button class="btn btn-info btn-xs songs-button">
                <i class="fas fa-eye"></i>
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
#   ERROR
#   FILTER
#   HASCOUNT
#   HASRANDOM
#   TYPE
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
                        <input type='hidden' />
                        <span class='fas fa-search'></span>
                        <span class='far fa-star'></span>
                        %s
                        <span class='fas fa-times hide'></span>
                    </div>
                    %s
                </div>
                <div id="complex-filter-trigger" class="icon-count-%i">
                    <a href='#'>%s</a> %s %s
                </div>
            </div>

            <div id="complex-filter" class="modal" data-hints="%s" data-shortcuts="%s">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-body">
        
                            <div class="alert alert-danger %s" id="sql-error">%s</div>
        
                            <form method="POST">
                                <textarea name=filter rows=3 placeholder="&quot;#&quot; to see columns, &quot;*&quot; to see shortcuts">%s</textarea>
                                <input type="button" value="Filter" class="btn btn-default btn-lg"/>
                                <input type="hidden" name="placeholder" value="" />
                            </form>
                            <ul class="playlists">
                                %s
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        },
        $args->{HASRANDOM} ? "<span class='fas fa-random text-muted'></span>" : "",
        $args->{HASCOUNT} ?  qq{
            <div class='input-group'>
                <span class='input-group-addon item-count'>0</span>
                <input id='filter' type='text' class='form-control' />
            </div>
        } : qq{ <input id='filter' type='text' class='form-control' /> },
        $iconcount,
        $args->{FILTER} || "advanced search",
        $iconcount == 2 ? "<span class='fas fa-sync-alt'></span>" : "",
        $iconcount > 0 ? "<span class='fas fa-times'></span>" : "",
        Flavors::Util::EscapeHTMLAttribute(JSON::to_json([qw(
            id name artist rating energy mood time filename ismix mincollectioncreated
            maxcollectioncreated taglist tagcount collectionlist minyear maxyear isstarred
            lyrics haslyrics
        )])),
        Flavors::Util::EscapeHTMLAttribute(JSON::to_json([
            { name => '[TAG]',          'expansion' => 'taglist like \'% TAG %\'' },
            { name => 'unrated',        'expansion' => 'rating is null or energy is null or mood is null' },
            { name => 'before YEAR',    'expansion' => 'maxyear < YEAR' },
            { name => 'after YEAR',     'expansion' => 'minyear > YEAR' },
            { name => 'quality',        'expansion' => 'rating > 3' },
            { name => 'decent',         'expansion' => 'rating > 2' },
            { name => 'starred',        'expansion' => 'isstarred = 1' },
            { name => 'mellow',         'expansion' => 'energy < 3' },
            { name => 'slow',           'expansion' => 'energy < 3' },
            { name => 'energetic',      'expansion' => 'energy > 3' },
            { name => 'happy',          'expansion' => 'mood > 3' },
            { name => 'unhappy',        'expansion' => 'mood < 3' },
            { name => 'sad',            'expansion' => 'mood < 3' },
            { name => 'angry',          'expansion' => 'mood < 3' },
        ])),
        $args->{ERROR} ? "" : "hide",
        $args->{ERROR},
        $args->{FILTER},
        join("", map {
            sprintf(
                "<li data-id='%s'>%s <a href='#'>%s</a></li>",
                $_->{ID}, 
                sprintf("<span class='%s fa-star'></span>", $_->{ISSTARRED} ? 'fas' : 'far'),
                $_->{FILTER},
            )
        } Flavors::Data::Playlist::List($dbh, { TYPE => $args->{TYPE} })),
    );
}

################################################################
# SongsModal
#
# Description: Generates HTML for modal with song list
#
# Params: None
#
# Return Value: HTML
################################################################
sub SongsModal {
    return sprintf(qq{
        <div id="song-list" class="modal">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h4>
                            <div class="pull-right">%s</div>
                            <span class="modal-title"></span>
                        </h4>
                    </div>
                    <div class="modal-body"></div>
                </div>
            </div>
        </div>
    }, Flavors::HTML::ExportControl());
}

################################################################
# Categorize
#
# Description: Generates HTML for a catgorization UI
#
# Params:
#        CATEGORIES: hashref of category name => items
#        UNCATEGORIZED: arrayref of items with a category
#        TABLE: one of qw(artistgenre tagcategory)
#
# Return Value: HTML
################################################################
sub Categorize {
    my ($dbh, $args) = @_;

    my %categories = %{ $args->{CATEGORIES} };
    my @uncategorized = @{ $args->{UNCATEGORIZED} };
    my $html;

    # Uncategorized items
    $html .= "<div class=\"text-center\">";
    foreach my $item (@uncategorized) {
        $html .= "<div class='tag'>$item</div>";
    }
    $html .= "</div>";

    # Categories
    $html .= "<div class=\"clearfix text-center\">";
    foreach my $category (sort keys %categories) {
        my @categorytags = @{ $categories{$category} };
        $html .= sprintf(qq{
                <div class='category' category='%s' data-table='%s'>
                    <div class='header clickable'>%s</div>
                    <div class='category-tags'>%s</div>
                </div>
            },
            $category,
            $args->{TABLE},
            $category,
            join("", map { "<div class='tag' category='$category'>$_</div>"; } @categorytags)
        );
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
            <div class="modal-dialog modal-lg">
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
        <script type="text/template" id="echo-nest-summary-row">
            <% for (var i in pairs) { %>
                <tr>
                    <td><%= pairs[i].key %></td>
                    <td><%= pairs[i].value %></td>
                </tr>
            <% } %>
        </script>
    } . qq{
        <div id="tooltip" class="hide"></div>
        </body></html>
    };
}

1;
