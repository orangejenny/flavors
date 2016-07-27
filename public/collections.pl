#!/usr/bin/perl

use lib "..";
use strict;

use Flavors::Data::Collection;
use Flavors::Data::Song;
use Flavors::Data::Tag;
use Flavors::Data::Util;
use Flavors::HTML;
use Flavors::Util;
use POSIX qw(floor);

my $dbh = Flavors::Data::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = Flavors::Util::Fdat($cgi);
Flavors::HTML::Header($dbh, {
    TITLE => "Collections",
    BUTTONS => Flavors::HTML::ExportControl() . qq{
        <button type="button" class="btn btn-xs btn-info" id="add-collection">
            <span class="glyphicon glyphicon-plus"></span>
            New
        </button>
    },
    CSS => ['collections.css', 'filters.css', 'song_attributes.css'],
    JS => ['collections.js', 'song-attributes.js', 'stars.js'],
    SPINNER => 1,
});

my $results = Flavors::Data::Util::TrySQL($dbh, {
    SUB => 'Flavors::Data::Collection::List',
    ARGS => {
        FILTER => $fdat->{FILTER},
        ORDERBY => $fdat->{ORDERBY},
    },
});
my $sqlerror = $results->{ERROR} || "";
my @collections = @{ $results->{RESULTS} };

my %songs;
my @songs = Flavors::Data::Song::List($dbh);
foreach my $song (@songs) {
    $songs{$song->{ID}} = $song;
}

print Flavors::HTML::FilterControl($dbh, {
    FILTER => $fdat->{FILTER},
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
                data-original-title="%s"
                data-tag-list="%s"
                data-name="%s"
                data-artist="%s"
                data-artist-list="%s"
                data-starred="%s",
                class="collection clearfix"
            >
        },
        $collection->{ID},
        $collection->{NAME},
        Flavors::Util::EscapeHTMLAttribute(join(" ", @{ $collection->{TAGS} })),
        lc($collection->{NAME}),
        lc($collection->{ARTIST}),
        lc($collection->{ARTISTLIST}),
        $collection->{ISSTARRED} ? 1 : 0,
    );

    my @files = Flavors::Data::Collection::CoverArtFiles($collection->{ID});
    if (@files) {
        printf(qq{
                <div class="cover-art%s">
                    %s
                </div>
            },
            @files > 1 ? " multiple" : "",
            # TODO: select at most four, at random, and store the filenames
            join("", map { sprintf("<img src='%s' />", $_) } @files));
    }
    else {
        my $color = $colors{$collection->{COLOR}};
        printf(qq{
                <div class="cover-art missing" style="%s%s">
                    %s
                </div>
            },
            $color ? ("background-color: #" . $color->{HEX} . ";") : "",
            $color->{WHITETEXT} ? " color: white; font-weight: bold;" : "",
            join("", map { "<div>$_</div>" } @{ $collection->{TAGS} }[0..8]),
        );
    }
    printf(qq{
            <div class="accepting-drop hide">
                <i class="glyphicon glyphicon-cloud-upload"></i>
                <br /><br />
                Drop new cover art
            </div>
            <div class="name">%s</div>
            <div class="artist">%s</div>
        },
        $collection->{NAME},
        $collection->{ARTIST},
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
            <div class="details-background">
            <div class="details">
                <div>Acquired %s</div>
                %s<br><br>
                <div class="ratings">
                    <div>
                        <div class="rating">%s</div>
                        <div class="rating">%s</div>
                        <div class="rating">%s</div>
                    </div>
                    <div>
                        <div class="rating">%s</div>
                        <div class="rating">%s</div>
                        <div class="rating">%s</div>
                    </div>
                    <div>
                        <div class="rating">%s</div>
                        <div class="rating">%s</div>
                        <div class="rating">%s</div>
                    </div>
                    <div>%s</div>
                </div>
                <div class="tags">%s</div>
            </div>
            </div>
            <ul class="cover-art-thumbnails clearfix hide">%s</ul>
        },
        Flavors::Util::TrimDate($collection->{CREATED}),
        $exporttext,
        Flavors::HTML::Rating($collection->{MINRATING}, 'star'),
        Flavors::HTML::Rating($collection->{MINENERGY}, 'fire'),
        Flavors::HTML::Rating($collection->{MINMOOD}, 'heart'),
        Flavors::HTML::Rating($collection->{AVGRATING}, 'star'),
        Flavors::HTML::Rating($collection->{AVGENERGY}, 'fire'),
        Flavors::HTML::Rating($collection->{AVGMOOD}, 'heart'),
        Flavors::HTML::Rating($collection->{MAXRATING}, 'star'),
        Flavors::HTML::Rating($collection->{MAXENERGY}, 'fire'),
        Flavors::HTML::Rating($collection->{MAXMOOD}, 'heart'),
        $collection->{COMPLETION} == 1 ? "&nbsp;" : sprintf("(%s%% complete)", floor($collection->{COMPLETION} * 100)),
        join("", map { "<div>$_</div>" } @{ $collection->{TAGS} }[0..2]),
        join("", map { sprintf("<li><img src='%s' /><div class='trash'><i class='glyphicon glyphicon-trash'></i></div></li>", $_) } @files),
    );

    print "</div>";
}
print "</div></div>";

# Modal for complex filtering
print Flavors::HTML::FilterModal($dbh, {
    ERROR => $sqlerror,
    FILTER => $fdat->{FILTER},
    HINTS => [ Flavors::Data::Collection::ListColumns() ],
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

print Flavors::HTML::SongsModal();

print Flavors::HTML::Footer();
