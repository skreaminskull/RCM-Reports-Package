#!/usr/bin/perl
use strict;
use warnings;

use lib '/projects/RCM_ReportsPackage/lib';
use ReportsPackage;

my $client = $ARGV[0] || die("No Client");
my $ccyymm = $ARGV[1] || die ("No CCYYMM");
my $report_type = "AR";
my $report_dir = "/mnt/nfs/Portal Media/";
my $distribution = "DIVEPORT";
my $page_number_placement = "right";
my $log_table = 'N';
my $package_id = 14;


my $status = 0;
$status = process_packages(client=>$client,ccyymm=>$ccyymm, report_type=>$report_type,header_footer=>'N',report_dir=>$report_dir,distribution=>$distribution, page_number_placement=>$page_number_placement, log_table=>$log_table,package_id=>$package_id);
if ($status == 0) {
  print "Run status: $status - success\n";
} else {
  print "Run status: $status - failure\n";
}
