#!/usr/bin/perl
use strict;
use warnings;

use lib '/projects/RCM_ReportsPackage/lib';
use ReportsPackage;

my $client = $ARGV[0] || die("No Client");
my $ccyymm = $ARGV[1] || die ("No CCYYMM");
my $report_type = "DRP";
my $report_dir = "/mnt/nfs/DRP/";
my $distribution = "SHAREPOINT";
my $page_number_placement = "left";
my $log_table = 'N';


my $status = 0;
$status = process_packages(client=>$client,ccyymm=>$ccyymm, report_type=>$report_type,header_footer=>'N',report_dir=>$report_dir,distribution=>$distribution, page_number_placement=>$page_number_placement, log_table=>$log_table);
if ($status == 0) {
  print "Run status: $status - success\n";
} else {
  print "Run status: $status - failure\n";
}
