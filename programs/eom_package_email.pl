use strict;
use warnings;
use MIME::Lite;

my %arg = (@_);

# process arguments
my $package_name = $ARGV[0];
my $eom_ccyymm = $ARGV[1];
my $to_list = $ARGV[2];
my $cc_list = $ARGV[3];
my $email_subject = $ARGV[4];
my $report_dir = $ARGV[5];
my $report_name = $ARGV[6];

my @months = qw( January February March April May June July August September October November December );

my $month_year =  $months[substr($eom_ccyymm,4) - 1] . ", " . substr($eom_ccyymm,0,4);

my $email_data =<<"EMAILDATA";
<!DOCTYPE html>
<html>
<head>
  <style>
    * {
      font-family: Century Gothic,CenturyGothic,AppleGothic,sans-serif;
    }
  </style>
</head>
<body>
  <p style="font-size:small;">Please find the attached PDF containing the $package_name for $month_year.</p>
  <p style="font-size:small;">Thank you, <br/>Analytics</p>
  <hr>
  <p style="font-size:medium;"><span style="color:#00509E;">COMPANY</span><span style="color:#717271;"> LLC</span>
    <br/>
    <span style="font-size:x-small; color:#717271">TAGLINE</span>
  </p>
</body>
</html>
EMAILDATA

### Create a new multipart message:
my $msg = MIME::Lite->new(
    From    => 'test@test.com',
    To      => $to_list,
    Cc      => $cc_list,
    Subject => $email_subject,
    Type    => 'multipart/mixed'
);

$msg->attach(
    Type     => 'text/html',
    Data     => $email_data
);
my $path = $report_dir . "/" . $report_name;
$msg->attach(
    Type     => 'application/pdf',
    Path     => $path,
    Filename => $report_name,
    Disposition => 'attachment'
);
### use Net:SMTP to do the sending
$msg->send('smtp','x.x.x.x', Debug=>0);
