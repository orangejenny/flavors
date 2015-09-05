#!/usr/bin/perl

use lib "..";
use strict;

use FlavorsHTML;
use FlavorsData::Tag;
use FlavorsData::Util;

my $dbh = FlavorsData::Util::DBH();

my $cgi = CGI->new;
print $cgi->header();
my $fdat = FlavorsUtil::Fdat($cgi);

FlavorsHTML::Header({
	CSS => ['colors.css', 'thirdparty/jquery.miniColors.css'],
	JS => ['colors.js', 'thirdparty/jquery.miniColors.js'],
});

my @colors = FlavorsData::Tag::ColorList($dbh);

print qq{ <div class="post-nav"> };

foreach my $color (@colors) {
	printf(qq{
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

print qq{ </div> };
print FlavorsHTML::Footer();
