#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsHTML;
use FlavorsData;

my $dbh = FlavorsData::DBH();

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({
	TITLE => "Tags",
});

my @tags = FlavorsData::TagList($dbh);

print qq{
	<script type="text/javascript">
		jQuery(function() {
			jQuery('.tag').css("cursor", "pointer").click(function() {
				var tag = jQuery(this).text();
				tag = tag.replace(/\\(.*/, "");
				CallRemote({
					SUB: 'FlavorsHTML::TagDetails', 
					ARGS: { TAG: tag }, 
					FINISH: function(data) {
						jQuery('#itemdetail').html(data.CONTENT);
						jQuery('#itemdetail').dialog({
							title: data.TITLE,
							width: 650,
							modal: true
						});
					}
				});
			});
		});
	</script>
};

# Print tags by frequency, click to pull up related tags
print "<div class='category-tab'>" . join("", map { FlavorsHTML::Tag($_) } @tags) . "</div>";

print "<div id=itemdetail title='Tag Details'></div>";

print FlavorsHTML::Footer();
