#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header();

my @artists = FlavorsData::ArtistGenreList($dbh);
my $categorizedartists = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@artists,
});
my @sorted = sort @{ $categorizedartists->{UNCATEGORIZED} };
$categorizedartists->{UNCATEGORIZED} = \@sorted;

print qq{
	<script type="text/javascript">
		jQuery(function() {
			jQuery('.tag').css("cursor", "move").draggable();
			jQuery('.category').droppable({
				hoverClass: "ui-state-active",
				drop: function(event, ui) {
					var container = jQuery('.category-tags', this);
					jQuery(ui.draggable).remove().css('position', 'static').appendTo(container);
					var args = {
						VALUE: ui.draggable.text(),
						CATEGORY: jQuery(this).attr("category")
					};
					args.TABLE = "artistgenre";
					args.VALUECOLUMN = "artist";
					args.CATEGORYCOLUMN = "genre";
					CallRemote({
						SUB: 'FlavorsData::UpdateCategory',
						ARGS: args,
						FINISH: function(data) {
							//alert(data.MESSAGE);
						}
					});
				}
			});
		});

		function ToggleCategory(obj) {
			jQuery(obj).next('.category-tags').slideToggle();
		}
	</script>
};

# Map artist to genres
print "<div class='category-tab'>" . FlavorsHTML::Categorize($dbh, $categorizedartists) . "</div>";

print FlavorsHTML::Footer();
