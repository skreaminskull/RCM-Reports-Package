#!/usr/bin/perl
use strict;
use warnings;

use lib '/projects/RCM_ReportsPackage/lib';
use ReportsPackage;

my $client = $ARGV[0] || die("No Client");
my $ccyymm = $ARGV[1] || die ("No CCYYMM");
my $package_id = $ARGV[2] || '';
my $test = $ARGV[3] || 'N';
my $report_type = "EOM";
my $report_dir = "/mnt/nfs/EOM/";
my $distribution = "EMAIL";

my $status = 0;
$status = process_packages(client=>$client,ccyymm=>$ccyymm, report_type=>$report_type,header_footer=>'N',report_dir=>$report_dir,distribution=>$distribution,package_id=>$package_id,test=>$test);
if ($status == 0) {
  print "Run status: $status - success\n";
} else {
  print "Run status: $status - failure\n";
}
