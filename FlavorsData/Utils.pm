package FlavorsData::Utils;

use strict;
use DBI;
use FlavorsUtils;

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
#
# Return Value: array of hashrefs
################################################################
sub Results {
	my ($dbh, $args) = @_;

	my @binds = $args->{BINDS} ? @{ $args->{BINDS} } : ();

	my $sql = $args->{SQL};
	my $query = $dbh->prepare($sql) or die "PREPARE: $DBI::errstr ($sql)";
	$query->execute(@binds) or die "EXECUTE: $DBI::errstr ($sql)";

	my @results;
	my @columns = $args->{COLUMNS} ? @{ $args->{COLUMNS} } : ();
	while (!$args->{SKIPFETCH} && (my @row = $query->fetchrow())) {
		my %labeledrow;
		for (my $i = 0; $i < @columns; $i++) {
			$labeledrow{uc($columns[$i])} = $row[$i];
		}
		push @results, \%labeledrow;
	}
	$query->finish();

	return @results;
}

1;
