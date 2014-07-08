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

print q{
	<script type="text/javascript">
		jQuery(function() {
			jQuery('.tag').css("cursor", "pointer").click(function() {
				var tag = jQuery(this).text();
				tag = tag.replace(/\\(.*/, "");
				CallRemote({
					SUB: 'FlavorsHTML::TagDetails', 
					ARGS: { TAG: tag }, 
					FINISH: function(data) {
						var $modal = jQuery("#item-detail");
						$modal.find('.modal-header h4').html(data.TITLE);
						$modal.find('.modal-body').html(data.CONTENT);
						$modal.modal();
					}
				});
			});
		});
	</script>
};

# Print tags by frequency, click to pull up related tags
print "<div class='category-tab'>" . join("", map { FlavorsHTML::Tag($_) } @tags) . "</div>";

print q{
	<div id="item-detail" class="modal">
		<div class="modal-dialog modal-lg">
			<div class="modal-content">
				<button type="button" class="close" data-dismiss="modal">
					<span aria-hidden="true">&times;</span><span class="sr-only">Close</span>
				</button>
				<div class="modal-header">
					<h4></h4>
				</div>
				<div class="modal-body">
				</div>
			</div>
		</div>
	</div>
};

print FlavorsHTML::Footer();
