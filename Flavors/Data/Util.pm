package Flavors::Data::Util;

use strict;
use DBI;
use Flavors::Util;

our $SEPARATOR = "\n";

################################################################
# DBH
#
# Description: Create database handle
#
# Return Value: $dbh
################################################################
sub DBH {
    my $config = Flavors::Util::Config->{db};

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
#        SQL: query string
#        COLUMNS: arrayref of names for the fetched elements
#        BINDS (optional)
#        SKIPFETCH: (optional) denotes a non-select query
#        GROUPCONCAT: (optional) arrayref of column names coming from
#            group_concat, should be split
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

################################################################
# TrySQL
#
# Description: Attempt SQL query and return both results and
#   error message, if any
#
# Parameters
#        SUB: String; sub to execute
#        ARGS: Hashref of args to pass to sub
#
# Return Value: hashref containing
#        ERROR: String; error message
#        RESULTS: Arrayref of hashrefs, each a row of data
################################################################
sub TrySQL {
    my ($dbh, $args) = @_;
    my @results = ();
    my $error = "";

    $args->{SUB} ||= $args->{TRYSUB};

    eval {
        no strict 'refs';
        @results = $args->{SUB}($dbh, $args->{ARGS} || $args);
    };

    if ($@) {
        # assume this was an error in user's complex filter SQL
        $error = $@;
        $error =~ s/\n.*//s;
        $error =~ s/\(select \* from \(\s*//s;
    }

    return {
        RESULTS => \@results,
        ERROR => $error,
    };
}


1;
