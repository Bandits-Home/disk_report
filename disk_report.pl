#! /usr/bin/perl -w
############## disk_perf.pl #########################
# Author  : IT Convergence
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
# Contrib : 
# ToDo    : N/A
#######################################################
#
use strict;
use warnings;
use Carp;
use Getopt::Long;
use lib "/usr/local/nagios/libexec";
use utils qw(%ERRORS $TIMEOUT);

#### Nagios specific ####
my $output_msg = "";
my $status = 0;

# Standard options
my $o_customer  = undef; # customer abbreviation
my $o_email  = undef;

# functions
sub print_usage {
    print "Usage: $0 -c <customer abbreviation> -e <your email address>\n";
}

sub check_options { #### Check Options
    Getopt::Long::Configure ("bundling");
	GetOptions(
        'c:s'   => \$o_customer,	'customer:s'	=> \$o_customer,
        'e:s'   => \$o_email,	'email:s'	=> \$o_email
    );
    if ( !defined($o_customer) ) { print_usage(); exit $ERRORS{"UNKNOWN"}};
    if ( !defined($o_email) ) { print_usage(); exit $ERRORS{"UNKNOWN"}};
}

############################################
##############   MAIN   ####################
############################################
check_options();
chdir "/usr/local/nagios/share/perfdata";
my $command = "ls -ldm1 ".$o_customer."*";
my @folders = `$command`;
my $fileswin = "/tmp/$o_customer-win.csv";
my $filesnix = "/tmp/$o_customer-nix.csv";
# check if the file exists
if (-f $fileswin) {
        unlink $fileswin
        or croak "Cannot delete $fileswin: $!";
}
if (-f $filesnix) {
	unlink $filesnix
	or croak "Cannot delete $filesnix: $!";
}
# use a variable for the file handle
my $OUTFILE;
my $OUTFILE2;
open $OUTFILE2, '>>', $fileswin;
open $OUTFILE, '>>', $filesnix;
        print { $OUTFILE2 } "server, mount, free, warning, critical, min, max\n";
        print { $OUTFILE } "server, mount, used, warning, critical, min, max\n";
foreach (@folders){
	my $folder = $_;
	chomp $folder;
	$folder =~ s/^\s+|\s+$//g;
	my $file = $folder."/Disk.xml";
	if (-f $file){ 
		my $perf = `cat $file |grep NAGIOS_PERFDATA`;
		$perf =~ s/^\s+|\s+$//g;
		if ($perf =~ /[a-zA-Z]:\\ %/g) { 
			my $command= "echo \"$perf\" | sed 's/<NAGIOS_PERFDATA>//g' | sed 's/<\\\/NAGIOS_PERFDATA>//g'";
                	my $perf2 = `$command`;
        	        $perf2 =~ s/^\s+|\s+$//g;
	                $command = "echo \"$perf2\" | sed 's/ %/remove/g' | sed 's/=/,/g' | sed 's/G;/,/g' | sed 's/M;/,/g' | sed 's/;/,/g' | sed 's/\\n//g'|sed \"s/ /\\n/g\"";
                	my @data = `$command`;
        	        foreach (@data){
	                        if (($_ ne ' ') && ($_ !~ /remove/)) {
                	                print { $OUTFILE2 } "$folder,$_";
        	                }
	                }
		} else {
			my $command= "echo \"$perf\" | sed 's/<NAGIOS_PERFDATA>//g' | sed 's/<\\\/NAGIOS_PERFDATA>//g'";
			my $perf2 = `$command`;
			$perf2 =~ s/^\s+|\s+$//g;
			$command = "echo \"$perf2\" | sed 's/=/,/g' | sed 's/GB;/,/g' | sed 's/MB;/,/g' | sed 's/;/,/g' | sed 's/\\n//g'|sed \"s/ /\\n/g\"";
			my @data = `$command`;
			foreach (@data){
				if ($_ ne ' ') { 
					print { $OUTFILE } "$folder,$_";
				}
			}
		}
	}
}
close $OUTFILE;
close $OUTFILE2;
system("mail -a /tmp/$o_customer-win.csv -a /tmp/$o_customer-nix.csv -s \"Disk Report for: $o_customer\" $o_email < /usr/local/nagios/libexec/scripts/diskreport/disk_report_body.txt");
exit $status;
