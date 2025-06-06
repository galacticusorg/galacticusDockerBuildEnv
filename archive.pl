#!/usr/bin/env perl
use strict;
use warnings;
use JSON;

# Retrieve and archive copies of all dependencies for Galacticus' build environment.
# Andrew Benson (26-February-2024)

# Get arguments.
die("Usage: archive.pl <dockerFile> <archivePath> <slackToken>")
    unless ( scalar(@ARGV) == 3 );
my $dockerFileName = $ARGV[0];
my $archivePath    = $ARGV[1];
my $slackToken     = $ARGV[2];

# Parse the Dockerfile.
my $report;
my $GCC_VERSION;
open(my $dockerFile,$dockerFileName);
while ( my $line = <$dockerFile> ) {
    if ( $line =~ m/^ENV\s+GCC_VERSION\s*=\s*(\S*)/ ) {
	$GCC_VERSION = $1;
    }
    next
	unless ( $line =~ m/^(RUN\s)??\s*wget\s+(\S+)/ );
    my $source = $2;
    $source =~ s/\$GCC_VERSION/$GCC_VERSION/;
    my $fileName;
    my $path;
    if ( $source =~ m/^(http|https|ftp):\/\/(.*)\/(.+)/ ) {
	$path     = $2;
	$fileName = $3;
	system("mkdir -p ".$archivePath.$path);
    }
    unless ( -e $archivePath.$path."/".$fileName ) {
	$report->{'report'} .= "RETRIEVING: ".$source."\n";
	system("wget ".$source." -O ".$archivePath.$path."/".$fileName);
	unless ( $? == 0 ) {
	    $report->{'report'} .= "\tFAILED: ".$source."\n";
	}
    } else {
	$report->{'report'} .= "SKIPPING: (already archived) ".$source."\n";
    }
}
close($dockerFile);

# Report the results.
system("curl -X POST -H 'Content-type: application/json' --data '".encode_json($report)."' https://hooks.slack.com/triggers/".$slackToken);

exit;
