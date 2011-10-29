#!/usr/bin/perl

use strict;
use 5.005;
use Config::General;
use Getopt::Std;
use fetchTumblrPics::ConfObj;
use fetchTumblrPics::GetObj;

our $opt_d;
getopts("d:");

my $configFile = $opt_d || 'fetchTumblrPics.conf';

$| = 1;

my @urls;
my %fetched;

my $conf = new Config::General($configFile) or die $!;
my %config = $conf->getall;

my $confObj = new fetchTumblrPics::ConfObj;

$confObj->setConf(\%config);

foreach my $job ($confObj->getJobs()) {
	$confObj->prepare();
	$confObj->fillJob($job);
	$confObj->getParam('debug') && print $job . " is configured\n";
	my $getObj = new fetchTumblrPics::GetObj;
	$getObj->setJob($confObj);
	$getObj->run();
}

exit;
