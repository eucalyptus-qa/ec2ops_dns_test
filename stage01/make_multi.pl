#!/usr/bin/perl

if (@ARGV < 3) {
    print "USAGE: make_multi.pl <original autopilot config> <number of stages to skip> <number of repeat configs>\n";
    exit 1;
}

$origfile = shift @ARGV;
$skipstage = shift @ARGV;
$numconfigs = shift @ARGV;

$storepres = 1;
$storerepeats = 0;
$storeposts = 0;

open(FH, "$origfile");
while(<FH>) {
    chomp;
    my $line = $_;

    if ($line =~ /STAGE(\d+)/) {
	$stagebuf .= "$line\n";
	$currstage = "STAGE$1";
    } elsif ($line =~ /END/) {
	$stagebuf .= "$line\n";
	if ($currstage eq "$skipstage") {
	    $storepres = 0;
	    $storerepeats = 1;
	    $storeposts = 0;
	} elsif ($currstage eq "") {
	    $storerepeats = 0;
	    $storeposts = 1;
	}

#	print "STAGEBUF ($currstage):\n----\n$stagebuf\n----\n";

	if ($storerepeats) {
	    $repeatbuf .= "$stagebuf";
	} elsif ($storepres) {
	    $prebuf .= "$stagebuf";
	} elsif ($storeposts) {
	    $postbuf .= "$stagebuf";
	}
	$stagebuf = "";
	$currstage = "";
    } else {
	$stagebuf .= "$line\n";
    }
}
close(FH);

$ofile = "/tmp/make_multi.tmp.$$";
open(OFH, ">$ofile");

print OFH "$prebuf";
if ($numconfigs > 1) {
    print OFH "\n";
    print OFH "STAGE00\n";
    print OFH "\tRUN TEST create_backup\n";
    print OFH "\tTIMEOUT 0\n";
    print OFH "\tSLEEP 10\n";
    print OFH "END\n";
}

for ($i=0; $i<$numconfigs; $i++) {
    if ($numconfigs > 1) {
	print OFH "\n";
	print OFH "STAGE00\n";
	print OFH "\tRUN TEST restore_backup\n";
	print OFH "\tTIMEOUT 0\n";
	print OFH "\tSLEEP 10\n";
	print OFH "END\n";
    }
    print OFH "$repeatbuf";
}

print OFH "$postbuf";
close(OFH);

open(OFH, ">$ofile.staged");
$count=1;
open(FH, "$ofile");
while(<FH>) {
    my $line = $_;
    if ($line =~ /\s*STAGE\d+\s+/) {
	my $num = sprintf("%02d", $count);
	$count++;
	$line =~ s/STAGE\d+/STAGE$num/;
	print OFH "$line";
    } else {
	print OFH "$line";
    }
}
close(FH);
close(OFH);
$count--;

system("cat $ofile.staged | sed \"s\/TOTAL_STAGES.*\/TOTAL_STAGES $count\/\" > $ofile.sed");
system("cat $ofile.sed; rm -f $ofile $ofile.sed $ofile.staged");



exit(0);
