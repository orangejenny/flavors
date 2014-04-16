#!/usr/bin/perl

use lib "..";
use strict;

use Data::Dumper;
use FlavorsData;
use FlavorsHTML;
use FlavorsUtils;
use POSIX;

my $dbh = FlavorsData::DBH();
my $fdat = FlavorsUtils::Fdat();

my $object = $fdat->{TYPE};
$object = "song" unless $object =~ /collection/i;

my $cgi = CGI->new;
print $cgi->header();
FlavorsHTML::Header({
	TITLE => "Lab",
});

my @tags = FlavorsData::TagList($dbh);
my @categories;
my %tagcategories;
my %categorytags;
foreach my $tag (@tags) {
	if ($tag->{METACATEGORY}) {
		$tagcategories{$tag->{TAG}} = $tag->{METACATEGORY};
		push @{ $categorytags{$tag->{METACATEGORY}} }, $tag->{TAG};
		push @categories, $tag->{METACATEGORY};
	}
}
my %temp = map { $_ => 1 } @categories;
@categories = sort(keys %temp);
my %slidervalues = (
	mood => 64,
	energy => 73,
	rating => 28,
	year => 19,
	chaos => 10,
	song => 46,
	colors => 55,
	nebulous => 90,
	personal => 81,
	specific => 37,
);

my @objects;
$fdat->{OBJECTID} =~ s/\D//g;
$fdat->{LIMIT} =~ s/\D//g;
$fdat->{LIMIT} ||= 25;
if ($fdat->{OBJECTID}) {
my @songs;#TODO
	@songs = FlavorsData::SongList($dbh, { 
		FILTER => qq{
			song.id <> $fdat->{SONGID}
			and exists (
				select 1
				from songtag
				where
					song.id = songtag.songid
					and songtag.tag in (
						select tag from songtag where songid = $fdat->{SONGID}
					)
			)
		}
	});
	my $seed = FlavorsData::SongList($dbh, { ID => $fdat->{SONGID} });

	# Score each song
	foreach my $song (@songs) {
		# base score of 50
		my $score = 50;
		my %factors;

		# genre
		if ($seed->{GENRE}) {
			my $genrescore = 0;
			if ($song->{GENRE}) {
				$factors{GENRE} = $song->{GENRE} eq $seed->{GENRE} ? 1 : -1;
			}
		}

		# rating
		if ($song->{RATING}) {
			$factors{RATING} = ($song->{RATING} - 3) / 2;
		}

		# energy and mood
		my @fields = qw(ENERGY MOOD);
		foreach my $field (@fields) {
			if ($seed->{$field} && $song->{$field}) {
				my $difference = abs($song->{$field} - $seed->{$field});
				$factors{$field} = ($difference - 2) * -1.5;
			}
		}

		# year
		if ($seed->{YEAR} && $song->{YEAR}) {
			my $difference = abs($song->{YEAR} - $seed->{YEAR});
			my $thisyear = strftime("%Y", localtime);
			$factors{YEAR} = (($difference / ($thisyear - 1950)) - 0.5) * -2;
		}

		# tags
		my @songtags = split(/\s+/, $song->{TAGS});
		my @seedtags = split(/\s+/, $seed->{TAGS});
		foreach my $category (@categories) {
			my @songcategorytags = grep { $tagcategories{$_} eq $category } @songtags;
			my @seedcategorytags = grep { $tagcategories{$_} eq $category } @seedtags;
			if (@songcategorytags && @seedcategorytags) {
				my @commontags = FlavorsUtils::ArrayIntersection(\@songcategorytags, \@seedcategorytags);
				$factors{$category} = scalar(@commontags) / scalar(@seedcategorytags);
			}
		}
$song->{SCORESTRING} .= "[" . join(" ", FlavorsUtils::ArrayIntersection(\@songtags, \@seedtags)) . "]";

		if (0 && $seed->{TAGS}) {
			my @songtags = split(/\s+/, $song->{TAGS});
			my @seedtags = split(/\s+/, $seed->{TAGS});
			my @commontags = FlavorsUtils::ArrayIntersection(\@songtags, \@seedtags);
			$factors{TAGS} = 2 * scalar(@commontags) / scalar(@seedtags);
		}

		foreach my $factor (keys %factors) {
			$score += $factors{$factor} * $fdat->{$factor} / 10;
			$song->{SCORESTRING} .= ", ${factor}=$factors{$factor}";
		}

		$song->{SCORE} = $score;
	}

	# Pick top section of songs
	@songs = sort { $b->{SCORE} <=> $a->{SCORE} } @songs;
	my $max = $fdat->{LIMIT} * ($fdat->{CHAOS} || 1);
	@songs = @songs[0..$max] if $max < scalar(@songs);

	# Delete random songs until correct size is reached
	while (@songs > $fdat->{LIMIT}) {
		splice(@songs, int(rand(scalar(@songs))), 1);
	}
}


print sprintf(qq{
	<script type="text/javascript">
		jQuery(function() {
			jQuery('#objectid').autocomplete({
				autoFocus: true,
				minLength: 3,
				source: function(request, response) {
					CallRemote({
						SUB: 'FlavorsData::%sList', 
						ARGS: { NAME: request.term }, 
						FINISH: function(objects) {
							var options = new Array();
							for (var index in objects) {
								options.push({
									label: objects[index].NAME%s,
									value: objects[index].ID
								});
							}
							response(options);
						}
					});
				}
			});

			jQuery('.tag').css("cursor", "pointer").click(function() {
				var tag = jQuery(this).text();
				tag = tag.replace(/\\(.*/, "");
				CallRemote({
					SUB: 'FlavorsHTML::TagSongList', 
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
}, 
	ucfirst $object,
	$object eq "song" ? " + ' (' + objects[index].ARTIST + ')'" : "",
);

print sprintf(qq{
	<form method=POST>
		<table id=sliders>
			<tbody>
				<tr>
					<th>%s</th>
					<td><input name=objectid value="$fdat->{OBJECTID}" id=objectid /></td>
				</tr>
	}, ucfirst $object);

	foreach my $slider (sort { $slidervalues{$b} <=> $slidervalues{$a} } keys(%slidervalues)) {
		my $value = exists $fdat->{uc $slider} ? $fdat->{uc $slider} : $slidervalues{$slider};
		my @randomtags = $categorytags{$slider} ? map { FlavorsHTML::Tag({ TAG => $_ }) } @{ $categorytags{$slider} } : ();
		while (scalar(@randomtags) > 5) {
			splice(@randomtags, int(rand(scalar(@randomtags))), 1);
		}
		print sprintf(qq{
			<tr>
				<th>%s</th>
				<td>
					<div class=slider></div>
					<input name=$slider value='$value' type=hidden />
				</td>
				<td>
					%s
				</td>
			</tr>
		}, ucfirst($slider), join("", @randomtags));
	}

	print sprintf(qq{
				<tr>
					<th>Length</th>
					<td><input value=$fdat->{LIMIT} name=limit size=3 />%ss</td>
				</tr>
				<tr>
					<td></td>
					<td><input type=submit value=Generate /></td>
				</tr>
	}, $object);

	if (@objects) {
		print qq{
			<tr>
				<th style="vertical-align: top;">Results</th>
				<td id=results colspan=2>
		};

		my $i = 1;
		foreach my $object (@objects) {
			print sprintf(
				"$i. $object->{NAME} %s($object->{SCORE}$object->{SCORESTRING}) <br>", 
				$object eq "song" ? "($object->{ARTIST}) " : ""
			);
			$i++;
		}

		print sprintf(qq{
					<input id=objectidlist value="%s" type=hidden />
				</td>
			</tr>
			<tr>
				<td></td>
				<td>
					<input type=button value=export id=export onclick="ExportPlaylist({ OBJECT: '%s', OBJECTIDLIST: jQuery('#objectidlist').val() });;" />
					%s
			</td>
			</tr>
		}, join("\t", map { $_->{ID} } @objects), FlavorsHTML::LocationInput(), $object);
	}

	print qq{
			</tbody>
		</table>
	</form>
};

print "<div id=itemdetail title='Tag Details'></div>";

print FlavorsHTML::Footer();
