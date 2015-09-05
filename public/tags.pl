#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsData::Tag;
use FlavorsData::Util;
use FlavorsHTML;

my $dbh = FlavorsData::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({
	CSS => ['tags.css'],
	JS => ['tags.js'],
	TITLE => "Tags",
});

my @tags = FlavorsData::Tag::List($dbh);

# Print tags by frequency, click to pull up related tags
print "<div class='post-nav category-tab'>" . join("", map { FlavorsHTML::Tag($_) } @tags) . "</div>";

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
