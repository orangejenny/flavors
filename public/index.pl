#!/usr/bin/perl
use CGI;
my $query = new CGI;
print $query->redirect("songs.pl");
