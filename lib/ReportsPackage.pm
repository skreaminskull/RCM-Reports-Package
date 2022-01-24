package ReportsPackage;

# use 5.024001;
use strict;
use warnings;
use PDF::API2;
use DBI;
use Time::Local;
use DateTime;
use Data::Dumper;

# declarations
# 25.4 mm in an inch
# 72 postscript points in an inch
# 612x1008 = legal
# 612x792 = letter
use constant mm => 25.4 / 72;
use constant in => 1 / 72;
use constant pt => 1;

require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use ReportsPackage ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
process_packages	test_methods
);

our $VERSION = '1.00';

# Preloaded methods go here.
my ($seconds, $minute, $hour, $day, $month, $year) = localtime;
my @months = qw( January February March April May June July August September October November December );
my $copyYear = 1900 + $year;
#my $timeStamp = sprintf("%02d/%02d/%04d %02d:%02d", $month + 1, $day, $copyYear, $hour, $minute);
my $timeStamp = sprintf("%04d%02d%02d_%02d%02d%02d", $copyYear, $month + 1, $day, $hour, $minute, $seconds);
my $copyRight = "Copyright $copyYear.";
my $reportCreation = "Report Created: $timeStamp";
my $header_height = 84;
my $footer_height = 84;
my $projDir = "RCM_ReportsPackage";
my $tmpDir = '/tmp/';
#my $projDir = "C:\\projects\\RCM_ReportsPackage";
#my $tmpDir = "\\tmp\\";
my $padding = 36;
my (%toc_HoH, @display_order);
# my $groupColor = "#7498CB";
# my $groupColor = "#1d4288";
# my $groupColor = "#315D85";
my $groupColor = "#417CB3";
my $reportLog;
my $reportListing;
my $client;
my $ccyymm;
my $page_orientation = "portrait";
my $package_name = "EOM Reports Package";
my @media_box = ("0","0","612","792");
#my @media_box = ("0","0","792","612");
my $fileSaveName;
my $saveRootName;
my ($report_type, $report_dir, $distribution);
my ($endw, $ypos, $paragraph);

sub db_connect {
	my $DBName = shift;
	my $DBUser = shift;
	my $DBPass = shift;
	my $DBHost = shift;

	my $dbh=DBI->connect("dbi:Pg:dbname=$DBName;host=$DBHost",$DBUser,$DBPass) or die "Error: Unable to connect to database";

	return $dbh;
}

sub trim {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

sub get_quarter {
	my $month_4_quarter = shift;
	#print "get_quarter $month_4_quarter\n";
	my $quarter;
  if ($month_4_quarter =~ m/(10|11|12)/) {
    $quarter = 4;
  } elsif ($month_4_quarter =~ m/(7|8|9)/) {
    $quarter = 3;
  } elsif  ($month_4_quarter =~ m/(4|5|6)/) {
    $quarter = 2;
  } elsif ($month_4_quarter =~ m/(1|2|3)/) {
    $quarter = 1;
  } else {
    print "Quarter can not be calculated!";
    die;
  }
	return $quarter;
}

sub process_quickValues {
  my $quick_value = shift;
  my $ccyymm = shift;
  my @values = split /;/, $quick_value;
  my $quick_value_temp = "";
  my $quick_value_new = "";
  # print Dumper(@values);
  foreach my $value (@values) {
    #print "Pattern Match Resutls - " . $value . ": ";
    if ($value =~ /\]$/) {
      #print "Yes\n";
      my @custom = split /:/, $value;
      #print Dumper(@custom);
      my $format = trim($custom[0]);
      my $offset = trim($custom[1]);
      $format =~ s/\[//;
      $offset =~ s/\]//;
      print "\nFormat: $format Offset: $offset\n";
      $quick_value_temp = gen_custom_ccyymm($format,$offset,$ccyymm);
    }
    else {
      #print "No\n";
      $quick_value_temp = $value ;
    }
    if ($quick_value_new eq "") {
      $quick_value_new = $quick_value_temp;
    }
    else {
      $quick_value_new = $quick_value_new . ";" . $quick_value_temp;
    }
  }
  return $quick_value_new;
}

sub gen_custom_ccyymm {
  my $format = shift;
  my $offset = shift;
  my $ccyymm = shift;

	### SPLIT DATE UP INTO DAY, MONTH & YEAR VARIABLES
	my $year = substr($ccyymm,0,4);
	my $month = substr($ccyymm,4,2);

	### CHECK FORMAT FOR RETURN TYPE
	if ($format eq "YYYY-MM") {
	  ($year, $month) = month_offset($month, $year, $offset);
	  $year = sprintf("%04d", $year);
	  $month = sprintf("%02d", $month);
	  return ($year . "-" . $month);
	} elsif ($format eq "YYYY-QP") {
	  $offset = 3 * $offset;
	  ($year, $month) = month_offset($month, $year, $offset);
	  my $quarter = get_quarter($month);
	  $year = sprintf("%04d", $year);
	  return ($year . "-Q" . $quarter);
	} elsif ($format eq "YYYY") {
	  $year = $year + $offset;
		return $year;
	}
}

sub month_offset {
  my $month_offset = shift;
  my $year_offset = shift;
  my $offset = shift;
  my $base_units = 12;
  my $polarity =  $offset < 0 ? -1 : 1;
  my $abs_offset = abs($offset);
  my $year_offset_flag = 0;
  my $year_adj = 0;
  my $month_adj = 0;

  if ($abs_offset > $base_units) {
    $year_adj = int(($abs_offset / $base_units)) * $polarity;
    $offset = ($abs_offset % $base_units) * $polarity;
    $year_offset_flag = 1;
  }

  $month_adj = $offset % $base_units;
  $month_offset = $month_offset + $month_adj;
  #print "Month: $month\n";
  if ($month_offset > 12) {
    $month_offset = $month_offset - 12;
    if ($polarity == 1) {
      $year_adj = $year_adj + $polarity;
    }
  } else {
    if ($polarity == -1 and ($month_adj > 0 or $year_offset_flag == 0)) {
      $year_adj = $year_adj + $polarity;
    }
  }

  #print "Year Adj: $year_adj\n";
  #print "Month Adj: $month_adj\n";
  $year_offset = $year_offset + $year_adj;
  return ($year_offset, $month_offset);
}

sub get_client {
	$client = shift;
	my %configOptions = do 'lookups.cfg';
	my $dbh = db_connect($configOptions{DBName}, $configOptions{DBUser}, $configOptions{DBPass}, $configOptions{DBHost});
	my $query = $dbh->prepare("SELECT client_name FROM clients where client_acronym = '" . $client . "'") or die "prepare statement failed";
	my %packages;

	$query->execute() or die "execution failed";

	my $clientFull;
	my @data;

	while(@data = $query->fetchrow_array()) {
	    $clientFull = $data[0];
	}

	$dbh->disconnect;
	return $clientFull;
}

sub get_packages {
	my %configOptions = do '/config/reports_package.cfg';
	my $dbh = db_connect($configOptions{DBName}, $configOptions{DBUser}, $configOptions{DBPass}, $configOptions{DBHost});
	my $query = $dbh->prepare("SELECT * FROM report_packages where (client_acronym = '" . $client . "' or client_acronym = '*') and report_type = '" . $report_type . "' group by package_id order by package_id") or die "prepare statement failed";
	$query->execute() or die "execution failed";

	my %packages;
	my @result;
	my $id;

	while(@result = $query->fetchrow_array()) {
		#print "@result\n";
    $id = $result[1] . "-" . $result[0];
		$packages{$id}{package_id} = $result[0];
		$packages{$id}{package} = $result[2];
		$packages{$id}{subject} = $result[3];
		$packages{$id}{layout} = $result[4];
	}

	return %packages;
}

sub get_package {
	my $package_id = shift;
	my %configOptions = do '/var/opt/DI/dl-dataroot/config/reports_package.cfg';
	my $dbh = db_connect($configOptions{DBName}, $configOptions{DBUser}, $configOptions{DBPass}, $configOptions{DBHost});
	my $query = $dbh->prepare("SELECT * FROM report_packages where package_id = " . $package_id) or die "prepare statement failed";
	$query->execute() or die "execution failed";

	my %packages;
	my @result;
	my $id;

	while(@result = $query->fetchrow_array()) {
		#print "@result\n";
    $id = $result[1] . "-" . $result[0];
		$packages{$id}{package_id} = $result[0];
		$packages{$id}{package} = $result[2];
		$packages{$id}{subject} = $result[3];
		$packages{$id}{layout} = $result[4];
	}

	return %packages;
}

sub process_packages {
	my %defaults = (
		gen_reports => 'Y',
		combine_multi => 'Y',
		gen_toc => 'Y',
		header_footer => 'N',
		merge_pdfs => 'Y',
		page_number_placement => 'right',
		gen_bookmarks => 'Y',
		clean_up => 'Y',
		test => 'N',
		log_table => 'Y',
		report_dir => $projDir . '/reports/',
		distribution => 'NONE',
		package_id => ''
	);
	my %arg = (%defaults, @_);
	my %configOptions = do '/config/reports_package_admin.cfg';

	foreach (keys %arg) {
  #	defined ($arg{$_})  || {$arg{$_}=$defaults{$_}};
		print "Argument: ", $_ ,"\t\tValue: ",$arg{$_},"\n";
	}

	if ($arg{header_footer} eq 'N') {
		$header_height = 0;
		$footer_height = 0;
	}

	$client = $arg{client};
	$ccyymm = $arg{ccyymm};
	$report_type = $arg{report_type};
	$report_dir = $arg{report_dir};
	$distribution = $arg{distribution};
	my $package_id_in = $arg{package_id};
	my %packages;
	my $package_id;

	# Check if a specific package_id was sent or if this is a global run
	if ($package_id_in eq '') {
		%packages = get_packages($client);
	} else {
		%packages = get_package($package_id_in);
	}

	my $file_header = "marker|key|value|page_group|page_order|toc_title|toc_parent";
	my ($marker, $key, $value, $page_group, $page_order, $toc_title, $toc_parent, $report_order);

	#print Dumper(%packages);
	#my @temp = %packages;
	#print "Client: $client\nCCYYMM: $ccyymm\n";
	#exit;
  print "\n\nProcesing Packages\n\n**********************************************\n";

	while ( $key = each %packages ) {
    # print "Package: $k => $v\n";
		print "\n\nPackage Info\n============================================\n";
		print "Package: $key\n\t $packages{$key}{package_id}\n";
		$page_orientation = $packages{$key}{layout};
		$package_name = $packages{$key}{package};
    $fileSaveName = $client . " " . $packages{$key}{package} . " " . $ccyymm . ".pdf";
		print "File Save Name: $fileSaveName\n";
		# Set media_box
		if ($page_orientation eq "portrait") {
			@media_box = ("0","0","612","792");
		} else {
			@media_box = ("0","0","792","612");
		}

		$package_id = $packages{$key}{package_id};

		my $dbh = db_connect($configOptions{DBName}, $configOptions{DBUser}, $configOptions{DBPass}, $configOptions{DBHost});

		my $query = $dbh->prepare("SELECT marker,key,value,page_group,page_order, toc_title,toc_parent,report_order FROM report_listing where package_id = '" . $package_id . "' order by report_order") or die "prepare statement failed";
		$query->execute() or die "execution failed";
		my @result;
		my $tmpListing = "";

		$tmpListing = "$file_header\n";
		while(@result = $query->fetchrow_array()) {
			# ignore warning for ininitiaized values
			{
				no warnings qw(uninitialized);
				($marker, $key, $value, $page_group, $page_order, $toc_title, $toc_parent, $report_order) = @result;
				# replace * with actual client acronym when all clients needed
				$marker =~ s/\*/$client/g;
				if ($marker eq "Directory") {
					my @files = <$key/$value>;
					foreach my $file (sort @files) {
						my @file_arr = split(/\//, $file);
 						my $last_index = $#file_arr;
 						$toc_title = substr($file_arr[$last_index],0,-4);
						$tmpListing = $tmpListing . "$file|||||$toc_title|\n";
					}
				} else {
					$tmpListing = $tmpListing . "$marker|$key|$value|$page_group|$page_order|$toc_title|$toc_parent\n";
				}
			}
		}

		$saveRootName = $client . "_" . $package_id . "_";
		$reportLog = $projDir . "/logs/" . $saveRootName . "package.log";
		$reportListing = $projDir . "/data/" . $client . "_" . $package_id . ".list";
		open my $fh, ">", $reportListing or die("Could not open file. $!");
		print {$fh} $tmpListing;
		close $fh;

		# Flow Control
		if($arg{gen_reports} eq 'Y') {
			gen_reports();
		}

		if ($arg{combine_multi} eq 'Y') {
			combine_multi();
		}

		if ($arg{gen_toc} eq 'Y') {
			gen_toc(toc_HoH=>\%toc_HoH,display_order=>\@display_order,log=>$reportLog);
		}

		if ($arg{header_footer} eq 'Y') {
			header_footer();
		}

		if ($arg{merge_pdfs} eq 'Y') {
			merge_pdfs(log=>$reportLog,saveName=>$fileSaveName,page_number_placement=>$arg{page_number_placement});
		}

		if ($arg{gen_bookmarks} eq 'Y') {
			gen_bookmarks(toc_HoH=>\%toc_HoH,display_order=>\@display_order,saveName=>$fileSaveName);
		}

		if ($arg{clean_up} eq 'Y') {
			clean_up(log=>$reportLog);
		}

		if ($arg{test} eq 'N' && $arg{log_table} eq 'Y' ) {
			$query = "";
			$query = $dbh->prepare("INSERT INTO report_packages_log (package_id, report_dir,file_name,eom_ccyymm,distribution_method) VALUES (?,?,?,?,?)");
			$query->execute($package_id, $report_dir, $fileSaveName, $ccyymm, $distribution) or die $DBI::errstr;
			$query->finish();
		}

		$dbh->disconnect;
	}
	print "\n\nProcesing Packages - Complete\n\n******************************************\n";

 return 0;
}

sub create_cover {
	my $ccyymm = shift;
	my $fileName = shift;
	my $clientFull = get_client($client);
	my $monthYear =  $months[substr($ccyymm,4) - 1] . ", " . substr($ccyymm,0,4);
	my $pdf = PDF::API2->new;
  my $font = $pdf->corefont('Helvetica');
	my $fontBold = $pdf->corefont('Helvetica-Bold');
	my $fontBoldItalic = $pdf->corefont('Helvetica-BoldOblique');
	$fileName = $projDir . $tmpDir . $fileName;

	my $page = $pdf->page;
	# Resize pdf page to dimensions based on page_orientation
	$page->mediabox(@media_box);
	my $text = $page->text();
  $text->font($font, 22);
	my ($xpos, $ypos);

	$ypos = $media_box[3] - ($media_box[3] * .18);
	#$text->translate(50,650);
	$text->translate(50,$ypos);
	$text->text($clientFull);
	# determine page width to pass to text_block
	my $width = $media_box[2] - 78;

	$text->font($fontBold, 18);

	#$ypos = 504;
	#$ypos = 403;
	$ypos = $media_box[3] - ($media_box[3] * .35);
	( $endw, $ypos, $paragraph ) = text_block(
		$text,
		$package_name,

		#-x => 20 / mm,
		-x => 15 / mm,
		-y => $ypos - 7 / pt,
		-w => $width,
		-h => 110 / mm - ( 119 / mm - $ypos ),
		-lead     => 25 / pt,
		-parspace => 0 / pt,
		-align    => 'center',
	);

	$text->font($font, 16);
  #$ypos = 450;
	#$ypos = 360;
	$ypos = $media_box[3] - ($media_box[3] * .43);
	( $endw, $ypos, $paragraph ) = text_block(
    $text,
    $monthYear,
    #-x => 20 / mm,
    -x => 15 / mm,
    -y => $ypos - 7 / pt,
    -w => $width,
    -h => 110 / mm - ( 119 / mm - $ypos ),
    -lead     => 25 / pt,
    -parspace => 0 / pt,
    -align    => 'center',
	);

	$text->font($fontBoldItalic, 18);
	#$ypos = 396;
	#$ypos = 316;
	$ypos = $media_box[3] - ($media_box[3] * .50);
	( $endw, $ypos, $paragraph ) = text_block(
		$text,
		"CONFIDENTIAL",
		#-x => 20 / mm,
		-x => 15 / mm,
		-y => $ypos - 7 / pt,
		-w => $width,
		-h => 110 / mm - ( 119 / mm - $ypos ),
		-lead     => 25 / pt,
		-parspace => 0 / pt,
		-align    => 'center',
	);

	my $copyRight = "Copyright $copyYear ThunderSteed, LLC";
	$text->font($font, 10);
	#$ypos = 140;
	#$ypos = 112;
	$ypos = $media_box[3] - ($media_box[3] * .82);
	($endw, $ypos, $paragraph ) = text_block(
		$text,
		$copyRight,
		#-x => 20 / mm,
		-x => 5 / mm,
		-y => $ypos - 7 / pt,
		-w => $width,
		-h => 110 / mm - ( 119 / mm - $ypos ),
		-lead     => 25 / pt,
		-parspace => 0 / pt,
		-align    => 'right',
	);

	my $reportCreation = "Report Created: $timeStamp";
	$text->font($font, 10);
	# $ypos = 120;
	# $ypos = 96;
	$ypos = $media_box[3] - ($media_box[3] * .85);
	( $endw, $ypos, $paragraph ) = text_block(
		$text,
		$reportCreation,
		#-x => 20 / mm,
		-x => 	5 / mm,
		-y => $ypos - 7 / pt,
		-w => $width,
		-h => 110 / mm - ( 119 / mm - $ypos ),
		-lead     => 25 / pt,
		-parspace => 0 / pt,
		-align    => 'right',
	);
  my $image_logo_name = $projDir . "/img/logo.png";
  my $image_logo = $pdf->image_png($image_logo_name);
	my $gfx = $page->gfx;
	# x-pos,y-pos (bottom left corner of image placed),width, height
	my $logo_width = 270;
	my $logo_height = 90;
	$xpos = $media_box[2] - $logo_width - $padding;
	$ypos = $logo_height + ($padding * 2);
	#$xpos = 492;
	#$ypos = 138;
  # $gfx->image($image_logo, 306, 162, 270, 90);
	$gfx->image($image_logo, $xpos, $ypos, 270, 90);
	header_box($page);
	footer_box($page);
	$pdf->saveas($fileName);
	draw_border($fileName);
}

sub gen_separator {
	my $pageTitle = shift;
  my $fileSaveName = shift;
	my $pdf = PDF::API2->new;

  $fileSaveName = $projDir . $tmpDir . $fileSaveName;

	my $font = $pdf->corefont('Helvetica');
	my $fontBold = $pdf->corefont('Helvetica-Bold');
	my $page = $pdf->page(0);
	$page->mediabox(@media_box);
	# if we want to add logos
	#my $gfx = $page->gfx;
	#$gfx->image($imageCollabLogo, 190, 560, 250, 100);

	my $text = $page->text();

	$text->font($font, 22);
	#my $y_coord;
	#$y_coord =  ($media_box[2] - $text->advancewidth($pageTitle))  / 2;
	my $y_pos =  ($media_box[3] / 2);
	my $width = $media_box[2] - 78;

	$ypos = $media_box[3] * .55;
  #$text->text($pageTitle);
  ( $endw, $ypos, $paragraph ) = text_block(
    $text,
    $pageTitle,
    #-x => 20 / mm,
    -x => 15 / mm,
    -y => $ypos - 7 / pt,
    -w => $width,
    -h => 110 / mm - ( 119 / mm - $ypos ),
    -lead     => 25 / pt,
    -parspace => 0 / pt,
    -align    => 'center',
	);

	header_box($page);
	footer_box($page);
  $pdf->saveas($fileSaveName);
	draw_border($fileSaveName);
}

sub draw_border {
  my $fileName = shift;

	my $pdf_in = PDF::API2->open($fileName);
	my $pdf_out = PDF::API2->new;
	my $pagenum = 1;

	my $page_in = $pdf_in->openpage($pagenum);
  #
  # create new page
  #
  my $page_out = $pdf_out->page(0);
  #
  # Get the page size
  #
  #my @mbox = $page_in->get_mediabox;
  # Inherit mediabox
  $page_out->mediabox(@media_box);

	my $xo = $pdf_out->importPageIntoForm($pdf_in, $pagenum);
  my $gfx = $page_out->gfx;
  $gfx->formimage($xo,
                  my $_x = 0, my $_y = 0,
                  my $_scale = 1.0);
  #
  # Draw a box 10pt in from the edges of the page
  #
  $gfx->linewidth(1);
  $gfx->strokecolor('#000000');
  $gfx->rect($media_box[0]+10, $media_box[1]+10, $media_box[2]-20, $media_box[3]-20);
  $gfx->stroke;

	$pdf_out->saveas($fileName);
}

sub combine_multi {
	print "\nCombining Multi Markers Per Page\n================================================\n";
	my $dir = $projDir . $tmpDir;
	my $x_offset = 10;
	my $y_offset = $media_box[3] - 30;
	my @fileSplit;
	my %HoA;
	my @files;
	my $fileRoot = "";
	my $combine = 0;
	my $padding = 36;
	my $boxPad = 0;
	my $page_height;
	my $totalWorkArea;
	my $pdf;

  opendir DIR, $dir or die "cannot open dir $dir: $!";
  @files= readdir(DIR);
  @files = sort {$a cmp $b} @files;

  for my $file (@files) {
    if ($file =~ /-[123456789]+.pdf$/) {
      #print "In combine_multi: " . $file . "\n";
      $combine = 1;
			@fileSplit = split(/-/, $file);
			$fileRoot = $fileSplit[0];
			#print "fileRoot: " . $fileRoot . "\n";
			push(@{$HoA{$fileRoot}}, $file);
		}
	}

	if ($combine) {
		my $saveName;
		foreach (keys %HoA) {
			my $rootName = $_;
			$totalWorkArea = $media_box[3] - ($header_height + $footer_height);
			my $x = 0;
			my $y = $y_offset;
			$pdf = PDF::API2->new();
			my $page = $pdf->page();
			# Resize pdf page to dimensions based on page_orientation
			$page->mediabox(@media_box);
	    foreach my $fileName(@{$HoA{$rootName}}) {
				#print "Root File: " . $rootName . " File Name: " . $fileName . "\n";
				my $fullPath =  $dir . $fileName;
				print "Processing File: " . $fullPath . "\n";
				my $pdf_in = PDF::API2->open($fullPath);
				my $page_in = $pdf_in->openpage(1);
 			  my @mbox = $page_in->get_mediabox;
				my $gfx = $page->gfx();
				my $xo = $pdf->importPageIntoForm($pdf_in, 1);
				$y = $y - $mbox[3];
				$gfx->formimage($xo, $x = 0, $y);
				# remove multi marker files after combined
	 			unlink($fullPath);
	    }
			$saveName = $dir . $rootName . ".pdf";
			print "Saving Output: " . $saveName . "\n";
			$pdf->saveas($saveName);
		}
	}

}

sub text_block {
  my $text_object = shift;
  my $text = shift;

  my %arg = @_;
  # Get the text in paragraphs
  my @paragraphs = split( /\n/, $text );

  # calculate width of all words
  my $space_width = $text_object->advancewidth(' ');

  my @words = split( /\s+/, $text );
  my %width = ();
  foreach (@words) {
    next if exists $width{$_};
    $width{$_} = $text_object->advancewidth($_);
  }

  my $ypos = $arg{'-y'};
  my @paragraph = split( / /, shift(@paragraphs) );

  my $first_line = 1;
  my $first_paragraph = 1;
	my $endw;

  # while we can add another line
  while ( $ypos >= $arg{'-y'} - $arg{'-h'} + $arg{'-lead'} ) {
    unless (@paragraph) {
      last unless scalar @paragraphs;
      @paragraph = split( / /, shift(@paragraphs) );
      $ypos -= $arg{'-parspace'} if $arg{'-parspace'};
      last unless $ypos >= $arg{'-y'} - $arg{'-h'};
      $first_line = 1;
      $first_paragraph = 0;
    }

    my $xpos = $arg{'-x'};
    # while there's room on the line, add another word
    my @line = ();
    my $line_width = 0;
    if ( $first_line && exists $arg{'-hang'} ) {
      my $hang_width = $text_object->advancewidth( $arg{'-hang'} );
      $text_object->translate( $xpos, $ypos );
      $text_object->text( $arg{'-hang'} );
      $xpos += $hang_width;
      $line_width += $hang_width;
      $arg{'-indent'} += $hang_width if $first_paragraph;
    } elsif ($first_line && exists $arg{'-flindent'}) {
      $xpos += $arg{'-flindent'};
      $line_width += $arg{'-flindent'};
    } elsif ($first_paragraph && exists $arg{'-fpindent'}) {
      $xpos       += $arg{'-fpindent'};
      $line_width += $arg{'-fpindent'};
    } elsif ( exists $arg{'-indent'} ) {
      $xpos += $arg{'-indent'};
      $line_width += $arg{'-indent'};
    }

    while ( @paragraph and $line_width + ( scalar(@line) * $space_width ) + $width{ $paragraph[0] } < $arg{'-w'} ) {
      $line_width += $width{ $paragraph[0] };
      push( @line, shift(@paragraph) );
    }

     # calculate the space width
     my ( $wordspace, $align );

     if ( $arg{'-align'} eq 'fulljustify' or ( $arg{'-align'} eq 'justify' and @paragraph ) ) {
        if ( scalar(@line) == 1 ) {
          @line = split( //, $line[0] );
        }
        $wordspace = ( $arg{'-w'} - $line_width ) / ( scalar(@line) - 1 );
        $align = 'justify';
     } else {
       $align = ( $arg{'-align'} eq 'justify' ) ? 'left' : $arg{'-align'};
       $wordspace = $space_width;
     }
     $line_width += $wordspace * ( scalar(@line) - 1 );

     if ( $align eq 'justify' ) {
       foreach my $word (@line) {
         $text_object->translate( $xpos, $ypos );
         $text_object->text($word);
         $xpos += ( $width{$word} + $wordspace ) if (@line);
     }
     my $endw = $arg{'-w'};
   } else {
     # calculate the left hand position of the line
     if ( $align eq 'right' ) {
       $xpos += $arg{'-w'} - $line_width;
     } elsif ( $align eq 'center' ) {
       $xpos += ( $arg{'-w'} / 2 ) - ( $line_width / 2 );
     }
     # render the line
     $text_object->translate( $xpos, $ypos );
     $endw = $text_object->text( join( ' ', @line ) );
   }
    $ypos -= $arg{'-lead'};
    $first_line = 0;
  }
  unshift( @paragraphs, join( ' ', @paragraph ) ) if scalar(@paragraph);
  return ( $endw, $ypos, join( "\n", @paragraphs ) );
}

sub leaders {
  # determnes how many periods to place between the appropriate header and page number.
  my $title_text = shift;
  my $page_num = shift;
  my $title_indent = shift;
  my $right_margin = shift;
  my $text = shift;
  #my $page = shift;
  #my $pdf = shift;
  #my %font = shift;
  #my @mbox  = shift;
  #my $text = $page->text();
  #my $font = $pdf->corefont('Helvetica');
  #$text->font( $font, 10 / pt);
  my $title_text_space = $text->advancewidth($title_text);
  my $page_num_space = $text->advancewidth($page_num);
  my $space_left = $media_box[2] - ($title_indent + $right_margin + $title_text_space + $page_num_space);
  my $leader = ".";
  my $leader_space = $text->advancewidth($leader);
  my $loops = $space_left / $leader_space;
  my $temp_text = $title_text;
  my $iter;
  my $loop_round = sprintf "%.0f", $loops;

  for ($iter = 0; $iter < $loop_round; $iter++) {
    $temp_text = $temp_text . "." ;
  }
  $temp_text = $temp_text . $page_num;
  #print "Leaders: " . $temp_text;
  return $temp_text;
}

sub create_toc {
  my $fileName = shift;
  $fileName = $projDir . $tmpDir . $fileName;
	my $pdf = PDF::API2->new( -file => $fileName );
	my $page = $pdf->page;
  $page->mediabox(@media_box);
  $pdf->save();
}

sub merge_pdfs {
	my %arg = @_;
  print "\nMerging PDFs\n================================================\n";
	my $savePackage = $report_dir . $arg{saveName};
	print "Package Save Path: $savePackage\n";
  open(LOG, $arg{log}) || die "Could not open the log file in merge_pdfs";
  my $pdf_merged = PDF::API2->new;
  my $fileName = "";

  while (<LOG>) {
    chomp;
    my @line = split(/\|/, $_);
    $fileName =  $projDir . $tmpDir . $line[0] . ".pdf";
    print "Processing file: $fileName\n";
  	my $pdf = PDF::API2->open($fileName);
    $pdf_merged->import_page($pdf, $_) foreach 1 .. $pdf->pages;
  }

  my $pageNumText = "";
  my $font = $pdf_merged->corefont('Helvetica');

  foreach my $pagenum (2 .. $pdf_merged->pages) {
    my $page_merged = $pdf_merged->openpage($pagenum);
    my @mbox = $page_merged->get_mediabox;
    my $text = $page_merged->text();

    $text->font($font, 10);
    # Set the text color
    $text->fillcolor('#000000');
    $pageNumText = $pagenum;
		my $page_coord = 0;
		if ($arg{page_number_placement} eq 'left') {
			$page_coord = $padding;
		} else {
			$page_coord = ($mbox[2] - $text->advancewidth($pageNumText)) - $padding;
		}

    $text->translate($page_coord, 16);
    $text->text($pageNumText);
  }
  $pdf_merged->saveas($savePackage);
	close(LOG);
}

sub gen_toc {
	my %arg = @_;
  print "\nGenerating TOC\n================================================\n";
  # Convert argument list to hash
	open(LOG, $arg{log}) || die "Could not open the log file";
  my $toc_file = "";
  my $total_pages = 0;
  my $cur_toc_title = "";
  my $level = 1;
	my $toc_max_entries_pg1;
	my $toc_max_entries;

	if ($page_orientation eq "portrait") {
		$toc_max_entries_pg1 = 29;
	} else {
		$toc_max_entries_pg1 = 21;
	}
	$toc_max_entries = $toc_max_entries_pg1;

  while ( <LOG> ) {
    chomp;
    my @line = split(/\|/, $_);
    my $file = $projDir . $tmpDir . $line[0] . ".pdf";
    my $toc_title = $line[1];
    my $toc_parent = $line[2];

    if ($. == 1)  {
      next;
    }
    if($. == 2) {
      $toc_file = $file;
			print "TOC: $toc_file\n";
      next;
    }

    my $pdf = PDF::API2->open($file);
    my $pages = $pdf->pages;
    # $page_cntr = $total_pages + 1;
    # print("File $file: has $pages page(s).\n");
    if ($toc_title =~ /\S/) {
      print "TOC Title:\t$toc_title\n";
      if (! defined $arg{toc_HoH}{$toc_title}) {
        if($toc_title ne $cur_toc_title ) {
          if($cur_toc_title ne "") {
            $arg{toc_HoH}{$cur_toc_title}{pages} = $total_pages;
            $arg{toc_HoH}{$cur_toc_title}{level} = $level;
            $total_pages = 0;
          }
          $cur_toc_title = $toc_title;
        }
        if ($toc_parent eq " ") {
          $level = 1;
        } else {
          if (defined $arg{toc_HoH}{$toc_parent}) {
            $level = $arg{toc_HoH}{$toc_parent}{level} + 1;
          } else {
            $level = 1;
          }
        }
				#print "TOC Title: push \t$toc_title\n";
        push @{$arg{display_order}}, $toc_title;
      }
    }
    $total_pages = $total_pages + $pages;
  }
  # process last item
  $arg{toc_HoH}{$cur_toc_title}{pages} = $total_pages;
  $arg{toc_HoH}{$cur_toc_title}{level} = $level;
  my $toc_elements = @{$arg{display_order}};
  my $toc_pages = sprintf("%d",$toc_elements / $toc_max_entries, ) + 1;
  # print "\nTOC Pages: $toc_pages\n";

  my $page_number = 1;
  my $toc_pdf = PDF::API2->new($toc_file);
  my $page = $toc_pdf->page(0);
	$page->mediabox(@media_box);
  my %font = (
      Helvetica => {
          Bold   => $toc_pdf->corefont( 'Helvetica-Bold',    -encoding => 'latin1' ),
          Roman  => $toc_pdf->corefont( 'Helvetica',         -encoding => 'latin1' ),
          Italic => $toc_pdf->corefont( 'Helvetica-Oblique', -encoding => 'latin1' ),
      },
	      Times => {
          Bold   => $toc_pdf->corefont( 'Times-Bold',   -encoding => 'latin1' ),
          Roman  => $toc_pdf->corefont( 'Times',        -encoding => 'latin1' ),
          Italic => $toc_pdf->corefont( 'Times-Italic', -encoding => 'latin1' ),
      },
  );
  #my $page = $toc_pdf->openpage($page_number);
  my $page_offset = $toc_pages + 1;
  my $page_cntr = $page_offset;
  my $font_color = "black";
  my $cur_pos = $media_box[3] - 144;
  my $pos_offset = 20;
  my $title_indent = 15;
  my $right_margin = 25;
  my $title_text = "";
  my $ret_text = "";
  my $indent = 0;
  my $headline_text = $page->text;

  # Add headline
  $headline_text->font( $font{'Helvetica'}{'Roman'}, 16 / pt );
  $headline_text->fillcolor($groupColor);
	$ypos = $media_box[3] - 100;
  $headline_text->translate( 25, $ypos );
  $headline_text->text('TABLE OF CONTENTS');
  my $toc_element_cntr = 0;

	foreach my $key (@{$arg{display_order}}) {
		$toc_element_cntr = $toc_element_cntr  + 1;
		if ($toc_element_cntr > $toc_max_entries) {
			$page = $toc_pdf->page(0);
			$toc_element_cntr = 1;
			$cur_pos = $media_box[3] - 100;
			# can fit a few more entries on without TOC title
			$toc_max_entries = $toc_max_entries_pg1 + 3;
		}
    $page_cntr = $page_cntr + 1;
    #print "$key: page_start: $page_cntr\n";
    if ($arg{toc_HoH}{$key}{level} == 1) {
      $font_color = $groupColor;
    } else {
      $font_color = "black";
    }
    my $text = $page->text;
    $text->font( $font{'Helvetica'}{'Roman'}, 10 / pt );
    $text->fillcolor($font_color);
    $indent = ($arg{toc_HoH}{$key}{level} * 10) + $title_indent;
    $text->translate($indent, $cur_pos);
    $ret_text = leaders($key, $page_cntr, $indent, $right_margin, $text);
    $text->text($ret_text);
    $cur_pos = $cur_pos - $pos_offset;
    $arg{toc_HoH}{$key}{page_number} = $page_cntr;
    $page_cntr = $page_cntr + $arg{toc_HoH}{$key}{pages} - 1;
  }
	unlink $toc_file;
  $toc_pdf->saveas($toc_file);
  close(LOG);
}

sub gen_bookmarks {
	my %arg = @_;
  print "\nGenerating Bookmarks\n================================================\n";
	my @toc_order = @{$arg{display_order}};
	# needs toc_HoH, display_order, saveBooklet
	my $savePackage = $report_dir . $arg{saveName};
	my $pdf = PDF::API2->open($savePackage);
  $pdf->preferences( -outlines => 1 );
  my $cur_key = "";
  my $pagenum = "";
  my $page;
  my $otls = $pdf->outlines;

	# TOC bookmark
	my $toc = $otls->outline;
	$page = $pdf->openpage(2);
	$toc->title('Table of Contents');
	$toc->dest($page);

  foreach my $key (@toc_order) {
		print "Key: $key\n";
    print "$key: $arg{toc_HoH}{$key}{level}\n";
    print "$key: $arg{toc_HoH}{$key}{pages}\n";
    if ($arg{toc_HoH}{$key}{level} == 1) {
      $arg{toc_HoH}{$key}{outline} = $otls->outline;
      $cur_key = $key;
    } else {
      $arg{toc_HoH}{$key}{outline} = $arg{toc_HoH}{$cur_key}{outline}->outline;
    }
    $pagenum = $arg{toc_HoH}{$key}{page_number};
    $page = $pdf->openpage($pagenum);
    $arg{toc_HoH}{$key}{outline}->title($key);
    $arg{toc_HoH}{$key}{outline}->dest($page);
  }
  $pdf->saveas($savePackage);
}

sub gen_reports() {
	my %arg = @_;
  print "\nGenerating Reports\n================================================\n";
  open(LISTING, $reportListing) || die "Could not open the report listing file";
  open my $log_fh, '>', $reportLog or die "Could not open log file: $!";
	my $cntr = 0;

  while ( <LISTING> ) {
  	chomp;
    # skip if header
  	next if /marker\|key\|value\|page_group\|page_order\|toc_title\|toc_parent/;

    my @line = split(/\|/, $_);
    my $markerFullPath = $line[0];
    my $quickKey = $line[1];
    my $quickValue = $line[2];
    my $page_group = $line[3];
    my $page_order = $line[4];
    my $toc_title = $line[5];
    my $toc_parent = $line[6];
		my $pad;
		my $saveName;
		my $cmd;
		my $marker_flag = 0;
		my $separator_flag = 0;

    if (defined $toc_title) {
	     $toc_title = $toc_title;
    } else {
	     $toc_title = " ";
    }

    if (defined $toc_parent) {
	     $toc_parent= $toc_parent;
    } else {
	     $toc_parent = " ";
    }

    print "Marker = " .	$markerFullPath . "\n";
  	if ($quickKey)  {
  		print "QK = " .	$quickKey . " .... " . length($quickKey) . "\n" ;
  	}

  	if ($quickValue)  {
			$quickValue = process_quickValues($quickValue,$ccyymm);
  		print "QV = " .	$quickValue . " .... " . length($quickValue) . "\n\n" ;
  	}

    if (defined $page_order && $page_order ne "") {
      $page_order = $page_order;
    }
    else {
      $page_order = 0;
    }

    if ($page_order < 2) {
      $cntr = $cntr + 1;
    }

    $pad = sprintf( "%05d", $cntr );

    # capture file name, toc_title and toc_parent
    if ($page_order <= 1) {
      $saveName = $saveRootName . $pad;
      print $log_fh "$saveName|$toc_title|$toc_parent\n";
    }

    if ($page_order > 0) {
      $pad = $pad . "-" . $page_order;
    }

    $saveName = $saveRootName . $pad . ".pdf";

    # check if pdf, look for in Hosp Systems subdir of pdfs
    if ($markerFullPath =~ /\.pdf$/) {
      $cmd = "cp \"" . $markerFullPath . "\" \"" . $projDir . "/tmp/" . $saveName . "\"";
      #print "Command: " . $cmd . "\n";
      #exit;
      $marker_flag = 0;
      $separator_flag = 0;
		} elsif ($markerFullPath eq 'Cover') {
			create_cover($ccyymm,$saveName);
			$marker_flag = 0;
      $separator_flag = 0;
    } elsif ($markerFullPath eq 'TOC') {
      create_toc($saveName);
      $marker_flag = 0;
      $separator_flag = 0;
    } elsif ($markerFullPath eq 'Separator') {
      gen_separator($quickKey, $saveName);
      $marker_flag = 0;
      $separator_flag = 1;
		} else {
      $marker_flag = 1;
      my $separator_flag = 0;
    }

    # pass quickview key and values if necessary
    if ($marker_flag == 1) {
      if ($quickKey) {
        $cmd = "java -jar /dial.jar $projDir/programs/marker2pdf.dial \"" . $markerFullPath . "\" \"" . $projDir . "\" \"" . $saveName . "\" \"" . $quickKey . "\" \"" . $quickValue . "\""  ;
      } else {
        $cmd = "java -jar //dial.jar $projDir/programs/marker2pdf.dial \"" . $markerFullPath . "\" \"" . $projDir . "\" \"" . $saveName . "\"" ;
      }
    }

    if ($cmd) {
  		print $cmd . "\n";
      system($cmd);
    }
  }
	close(LISTING);
}

sub header {

}

sub footer {

}

sub header_image {

}

sub header_box {
	my $page = shift;
	my $header_box = $page->gfx;

	$header_box->fillcolor($groupColor);
	# rect - left, bottom, width, height
	my $rect_width = $media_box[2] - ($padding * 2);
	my $ypos = ($media_box[3] * .90);
	$header_box->rect($padding,$ypos,$rect_width,36);
	$header_box->fill;
}

sub footer_box {
	my $page = shift;
	my $footer_box = $page->gfx;

	$footer_box->fillcolor($groupColor);
	# rect - left, bottom, width, height
	my $rect_width = $media_box[2] - ($padding * 2);
	$footer_box->rect($padding,30,$rect_width,12);
	$footer_box->fill;
}

sub clean_up {
	my %arg = @_;
	print "\nCleaning Temporary Files\n================================================\n";
	open(CLEAN, $arg{log}) || die "Could not open the report listing file";
	while (<CLEAN>) {
		my @line = split(/\|/, $_);
    my $fileName =  $projDir . $tmpDir . $line[0] . ".pdf";
		print "File: $fileName\n";
		unlink $fileName;
		undef %toc_HoH;
		undef @display_order;
	}
	close(CLEAN);
}

sub test_methods {
	$client = shift;
	my $ccyymm = "201705";
	my $saveName = "TEST_TITLE_P.pdf";
	#my $saveName = "TEST_TITLE_L.pdf";
	# print @media_box;
	#create_cover($ccyymm,$saveName);
	gen_separator("THE BEST TITLE",$saveName);
	return 0;
}

1;
__END__

=head1 NAME

ReportsPackage - Perl extension

=head1 SYNOPSIS

  use ReportsPackage;


=head1 DESCRIPTION

ReportsPackage, created by Keith Butler. This module provides
core methods for generating client specific Reports Packages

gen_reports(): processes content in reportListing

combine_multi(): combines markers that need to be combined on one page

gen_toc($reportLog,\%toc_HoH,\@display_order): generates TOC, expects to be passed a Hash of Hashes containing Table of Content entries and the order they should be displayed

merge_pdfs($reportLog): Merges ALL PDFs that have been created in reportLog

gen_bookmarks(\%toc_HoH,\@display_order): Adds Bookmarks to final PDF, expects to be passed a Hash of Hashes containing Table of Content entries and the order they should be displayed

=head2 EXPORT

None by default.


=head1 HISTORY

=over 8

=item 0.01

Original version; created by h2xs 1.23 with options

  -ACXn
	ReportsPackage

=back


=head1 SEE ALSO

This module has a dependency on PDF::AP2 and DI's dial scripting
language.

=head1 AUTHOR

Keith Butler, E<lt>keith@thundersteed.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2017 by ThunderSteed

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
