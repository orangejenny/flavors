#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({ HIDEEXPORT => 1 });

my @tags = FlavorsData::TagList($dbh);
my $categorizedtags = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@tags,
});

my @artists = FlavorsData::ArtistGenreList($dbh);
my $categorizedartists = FlavorsUtils::Categorize($dbh, {
	ITEMS => \@artists,
});

my @colors = FlavorsData::ColorList($dbh);

print qq{
	<link href="/css/jquery.miniColors.css" rel="stylesheet" type="text/css" />
	<script type="text/javascript" src="/javascript/jquery.miniColors.js"></script>
};

print qq{
	<style type="text/css">
		.tab-content { overflow: visible; }
		.minicolors-panel { top: 22px; }
		.minicolors input { height: 22px; }
		.btn-group > .btn.active { z-index: 1; }
		.color {
			float: left;
			width: 325px;
			padding: 10px;
		}
		.color .name {
			width: 75px;
			float: left;
		}
		.color .btn-group {
			margin-left: 10px;
		}
	</style>
};

print q{
	<script type="text/javascript">
		jQuery(function() {
			jQuery('.tag').css("cursor", "move").draggable();

			jQuery('.category').droppable({
				hoverClass: "ui-state-active",
				drop: function(event, ui) {
					var $container = jQuery('.category-tags', this);
					jQuery(ui.draggable).remove().css('position', 'static').appendTo($container);
					var args = {
						VALUE: ui.draggable.text(),
						CATEGORY: jQuery(this).attr("category")
					};

					var $tab = jQuery(this).closest(".tab-pane");
					if ($tab.attr("id") == "tag-category") {
						args.TABLE = "tagcategory";
						args.VALUECOLUMN = "tag";
						args.CATEGORYCOLUMN = "category";
					}
					else if ($tab.attr("id") == "artist-genre") {
						args.TABLE = "artistgenre";
						args.VALUECOLUMN = "artist";
						args.CATEGORYCOLUMN = "genre";
					}
					else {
						alert("Confused, this is neither a tag nor an artist");
						return;
					}
					CallRemote({
						SUB: 'FlavorsData::UpdateCategory',
						ARGS: args,
					});
				}
			});

			jQuery(".white-text button").click(function() {
				UpdateColor(this, { WHITETEXT: jQuery(this).val() });
			});

			jQuery("input[type=minicolors]").change(function() {
				UpdateColor(this, { HEX: jQuery(this).val().replace("#", "") });
			});
		});

		function ToggleCategory(obj) {
			jQuery(obj).next('.category-tags').slideToggle();
		}

		function UpdateColor(obj, args) {
			var $color = jQuery(obj).closest(".color");
			var $input = $color.find("input:first");
			args.NAME = $color.children(".name").text();
			$color.addClass("update-in-progress");
			CallRemote({
				SUB: 'FlavorsData::UpdateColor',
				ARGS: args,
				FINISH: function() {
					$color.removeClass("update-in-progress");
				}
			});
		}
	</script>
};

my $colorscontent = "";
foreach my $color (@colors) {
	$colorscontent .= sprintf(qq{
			<div class="color">
				<div class="name">%s</div>
				<input type="minicolors" data-slider="wheel" value="#%s" data-textfield="false">
				<div class="btn-group white-text" data-toggle="buttons-radio">
					<button class="btn btn-xs btn-default%s" value="0">black text</button>
					<button class="btn btn-xs btn-default%s" value="1">white text</button>
				</div>
			</div>
		},
		$color->{NAME},
		$color->{HEX},
		$color->{WHITETEXT} ? "" : " active",
		$color->{WHITETEXT} ? " active" : "",
	);
}

printf(qq{
		<ul class="nav nav-tabs">
			<li class="active"><a data-toggle="tab" href="#tag-category">Tags &rArr; Categories</a></li>
			<li><a data-toggle="tab" href="#artist-genre">Artists &rArr; Genres</a></li>
			<li><a data-toggle="tab" href="#colors">Colors</a></li>
		</ul>

		<div class="tab-content">
			<div class="tab-pane active" id="tag-category">%s</div>
			<div class="tab-pane" id="artist-genre">%s</div>
			<div class="tab-pane" id="colors">%s</div>
		</div>
	},
	FlavorsHTML::Categorize($dbh, $categorizedtags),
	FlavorsHTML::Categorize($dbh, $categorizedartists),
	$colorscontent,
);

print FlavorsHTML::Footer();
