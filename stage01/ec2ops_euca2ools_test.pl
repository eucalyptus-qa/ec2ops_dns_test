#!/usr/bin/perl

require "ec2ops.pl";

my $account = shift @ARGV || "eucalyptus";
my $user = shift @ARGV || "admin";
my $use_ha_dns = shift @ARGV || "no";

# need to add randomness, for now, until account/user group/keypair
# conflicts are resolved

$rando = int(rand(10)) . int(rand(10)) . int(rand(10));
if ($account ne "eucalyptus") {
    $account .= "$rando";
}
if ($user ne "admin") {
    $user .= "$rando";
}
$newgroup = "ec2opsgroup$rando";
$newkeyp = "ec2opskey$rando";

parse_input();
print "SUCCESS: parsed input\n";

if ($cc_has_broker{"CC00"}) {
    doexit(0, "SUCCESS: VMWare detected, skipping test\n");
}

setlibsleep(2);
print "SUCCESS: set sleep time for each lib call\n";

setremote($masters{"CLC"});
print "SUCCESS: set remote host: masterclc=$masters{CLC}\n";

if ($use_ha_dns eq "yes") {
    setusednsnames(1);
    print "SUCCESS: set use_dns_names to yes\n";
    
    get_credentials();
    print "SUCCESS: got fresh credentials\n";
    
    transfer_credentials($masters{CLC}, $masters{NC00});
    print "SUCCESS: transferred credentials from $masters{CLC} to $masters{NC00}\n";
    
    setremote($masters{"NC00"});
    print "SUCCESS: set remote host: masterclc=$masters{NC00}\n";

    source_credentials();
    print "SUCCESS: sourced new credentials\n";
}

use_euca2ools();
print "SUCCESS: will be using euca2ools from now on\n";

discover_emis();
print "SUCCESS: discovered loaded image: current=$current_artifacts{instancestoreemi}, all=$static_artifacts{instancestoreemis}\n";

discover_zones();
print "SUCCESS: discovered available zone: current=$current_artifacts{availabilityzone}, all=$static_artifacts{availabilityzones}\n";

if ( ($account ne "eucalyptus") && ($user ne "admin") ) {
# create new account/user and get credentials
    create_account_and_user($account, $user);
    print "SUCCESS: account/user $current_artifacts{account}/$current_artifacts{user}\n";
    
    grant_allpolicy($account, $user);
    print "SUCCESS: granted $account/$user all policy permissions\n";
    
    get_credentials($account, $user);
    print "SUCCESS: downloaded and unpacked credentials\n";
    
    source_credentials($account, $user);
    print "SUCCESS: will now act as account/user $account/$user\n";
}
# moving along

run_ec2_describes();
print "SUCCESS: ran all ec2 describes\n";

add_keypair("$newkeyp");
print "SUCCESS: added new keypair: $current_artifacts{keypair}, $current_artifacts{keypairfile}\n";

add_group("$newgroup");
print "SUCCESS: added group: $current_artifacts{group}\n";

authorize_ssh();
print "SUCCESS: authorized ssh access to VM\n";

run_instances();
print "SUCCESS: ran instance: $current_artifacts{instance}\n";

wait_for_instance();
print "SUCCESS: instance went to running: $current_artifacts{instancestate}\n";

$fails = docleanup();
if ($fails) {
    doexit(1, "FAILURE: cleanup failures non-zero\n");
}

doexit(0, "EXITING SUCCESS\n");
