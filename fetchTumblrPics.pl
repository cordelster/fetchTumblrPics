#!/usr/bin/perl

use strict;
use 5.005;
use Config::General;
use Getopt::Std;
use fetchTumblrPics::ConfObj;
use fetchTumblrPics::GetObj;

our ($opt_c,$opt_d,$opt_i);
getopts("id:c:");

my $configFile = $opt_d || 'fetchTumblrPics.conf';
my $do_init = $opt_i && 1;
my $catchUp = $opt_c;

$| = 1;

my $conf = new Config::General($configFile) or die $!;
my %config = $conf->getall;

my $confObj = new fetchTumblrPics::ConfObj;

$confObj->setConf(\%config);

if (defined($catchUp)) {
	$confObj->prepare();
	$confObj->fillJob($catchUp);
	$confObj->set('do_init',1);
	print "Job " . $catchUp . " ready for catchUp.\n";
        my $getObj = new fetchTumblrPics::GetObj;
        $getObj->setJob($confObj);
        $getObj->run();
} else {
	foreach my $job ($confObj->getJobs()) {
		$confObj->prepare();
		$confObj->fillJob($job);
		if ($do_init) {
			$confObj->set('do_init',$do_init);
		}
		$confObj->getParam('debug') && print $job . " is configured\n";
		my $getObj = new fetchTumblrPics::GetObj;
		$getObj->setJob($confObj);
		$getObj->run();
	}
}
exit;
