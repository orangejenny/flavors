package FlavorsUtils;

use strict;
use CGI;
use Data::Dumper;
use YAML;

sub Config {
	return YAML::LoadFile("../config.yml");
}

################################################################
# EscapeJS
#
# Description: Escape a given string for use in JavaScript
#
# Params: string
#
# Return Value: string
################################################################
sub EscapeJS {
	my ($string) = @_;
	$string =~ s/'/\\'/g;
	$string =~ s/"/\\"/g;
	return $string;
}

sub EscapeHTMLAttribute {
	my $string = shift;
	$string =~ s/"/&quot;/g;
	return $string;
}

sub EscapeSQL {
	my ($string) = @_;
	$string =~ s/'/\'\'/g;
	return $string;
}

################################################################
# Fdat
#
# Description: Builds hashref of GET/POST params
#
# Params: none
#
# Return Value: hashref
################################################################
sub Fdat {
	my $q = CGI->new;
	my $fdat;

	foreach my $key ($q->param(), $q->url_param()) {
		my $value = $q->param($key) || $q->url_param($key);
		#$value = s/^\s+//;
		#$value = s/\s+$//;
		$fdat->{uc($key)} = $value;
	}

	return $fdat;
}

################################################################
# ArrayDifference
#
# Description: Subtracts one array from another
#
# Params: two arrayrefs
#
# Return Value: Array of elements present in the first array
#	but not the second
################################################################
sub ArrayDifference {
	my ($a1, $a2) = @_;

	my %a1 = map { $_ => 1 } @$a1;
	my %a2 = map { $_ => 1 } @$a2;

	my @difference;
	foreach my $e (keys %a1) {
		if (!$a2{$e}) {
			push @difference, $e;
		}
	}

	return @difference;
}

################################################################
# ArrayIntersection
#
# Description: Finds the elements common to two arrays
#
# Params: two arrayrefs
#
# Return Value: Array of elements present in both arrays
################################################################
sub ArrayIntersection {
	my ($a1, $a2) = @_;

	my %a1 = map { $_ => 1 } @$a1;

	my @intersection;
	foreach my $e (@$a2) {
		if ($a1{$e}) {
			push @intersection, $e;
		}
	}

	return @intersection;
}

################################################################
# Sanitize
#
# Description: Sanitizes an SQL where clause input by user
#
# Return Value: String (may be blank)
################################################################
sub Sanitize {
	my ($sql) = @_;

	$sql =~ s/;.*//;
	if ($sql =~ /update|insert|delete|;/i) {
		$sql = "";
	}

	return $sql;
}

################################################################
# Categorize
#
# Description: Group given rows by a "category" value and get 
#		any uncategorized values
#
# Parameters:
#		ITEMS
#
# Return Value: hashref
#		CATEGORIES: hashref of categoryname => arrayref of values
#		UNCATEGORIZED: arrayref of values without a category
################################################################
sub Categorize {
	my ($dbh, $args) = @_;

	my @items = @{ $args->{ITEMS} };

	my $category = $args->{CATEGORY} || "CATEGORY";

	my %categories;
	my @uncategorized;
	foreach my $item (@items) {
		if ($item->{$category}) {
			$categories{$item->{$category}} ||= [];
			push @{ $categories{$item->{$category}} }, $item->{TAG};
		}
		else {
			push @uncategorized, $item->{TAG};
		}
	}
	@uncategorized = sort @uncategorized;

	return {
		CATEGORIES => \%categories,
		UNCATEGORIZED => \@uncategorized,
	};	
}

1;
