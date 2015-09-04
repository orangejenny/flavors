package FlavorsData::Utils;

use strict;
use DBI;
use FlavorsUtils;

our $SEPARATOR = "\n";

################################################################
# DBH
#
# Description: Create database handle
#
# Return Value: $dbh
################################################################
sub DBH {
	my $config = FlavorsUtils::Config->{db};

	my $host = $config->{host};
	my $database = $config->{database};
	my $user = $config->{user};
	my $password = $config->{password};

	return DBI->connect("dbi:mysql:host=$host:$database", $user, $password) or die $DBI::errstr;
}

################################################################
# Results
#
# Description: Execute query
#
# Parameters
#		SQL: query string
#		COLUMNS: arrayref of names for the fetched elements
#		BINDS (optional)
#		SKIPFETCH: (optional) denotes a non-select query
#		GROUPCONCAT: (optional) arrayref of column names coming from
#			group_concat, should be split
#
# Return Value: array of hashrefs
################################################################
sub Results {
	my ($dbh, $args) = @_;

	my @binds = $args->{BINDS} ? @{ $args->{BINDS} } : ();

	my $sql = $args->{SQL};
	my $query = $dbh->prepare($sql) or die "PREPARE: $DBI::errstr ($sql)";
	$query->execute(@binds) or die "EXECUTE: $DBI::errstr ($sql)";

	my %groupconcat = map { uc $_ => 1 } (@{ $args->{GROUPCONCAT} || []});

	my @results;
	my @columns = $args->{COLUMNS} ? @{ $args->{COLUMNS} } : ();
	while (!$args->{SKIPFETCH} && (my @row = $query->fetchrow())) {
		my %labeledrow;
		for (my $i = 0; $i < @columns; $i++) {
			my $value = $row[$i];
			if (exists $groupconcat{uc $columns[$i]}) {
				$value = $value ? [split(/$SEPARATOR/, $value)] : [];
			}
			$labeledrow{uc($columns[$i])} = $value;
		}
		push @results, \%labeledrow;
	}
	$query->finish();

	return @results;
}

1;
