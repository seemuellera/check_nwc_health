#! /usr/bin/perl

use strict;

my $CELSIUS = 1;
my $PERFDATA = 1;
my $EXTENDEDINFO = 1;
my $HWINFO = 1;
my $NOINSTLEVEL = 'unknown';

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;
use constant DEPENDENT  => 4;

my @modes = (
  ['device::hardware::health',
      'hardware-health', undef,
      'Check the status of environmental equipment (fans, temperatures, power)' ],
  ['device::hardware::load',
      'cpu-load', undef,
      'Check the CPU load of the device' ],
  ['device::hardware::memory',
      'memory-usage', undef,
      'Check the memory usage of the device' ],
#  ['device::interfaces::traffic',
#      'interface-traffic', undef,
#      'Check the in- and outgoing traffic on interfaces' ],
  ['device::interfaces::usage',
      'interface-usage', undef,
      'Check the utilization of interfaces' ],
  ['device::interfaces::errors',
      'interface-errors', undef,
      'Check the error-rate of interfaces (errors+discards per sec)' ],
  ['device::interfaces::operstatus',
      'interface-status', undef,
      'Check the status of interfaces' ],
  ['device::interfaces::list',
      'list-interfaces', undef,
      'Show the interfaces of the device and update the name cache' ],
  ['device::shinken::interface',
      'create-shinken-service', undef,
      'Create a Shinken service definition' ],
);
my $modestring = "";
my $longest = length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0]);
my $format = "       %-".
  (length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0])).
  "s\t(%s)\n";
foreach (@modes) {
  $modestring .= sprintf $format, $_->[1], $_->[3];
}
$modestring .= sprintf "\n";


my $plugin = Nagios::MiniPlugin->new(
    shortname => '',
    usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
        '--hostname <network-component> --community <snmp-community>'.
        '  ...]',
    version => '4.0',
    blurb => 'This plugin checks various parameters of network components ',
    url => 'http://labs.consol.de/nagios/check_nwc_health',
    timeout => 60,
    shortname => '',
);
$plugin->add_arg(
    spec => 'blacklist|b=s',
    help => '--blacklist
   Blacklist some (missing/failed) components',
    required => 0,
    default => '',
);
#$plugin->add_arg(
#    spec => 'customthresholds|c=s',
#    help => '--customthresholds
#   Use custom thresholds for certain temperatures',
#    required => 0,
#);
#$plugin->add_arg(
#    spec => 'perfdata=s',
#    help => '--perfdata=[short]
#   Output performance data. If your performance data string becomes
#   too long and is truncated by Nagios, then you can use --perfdata=short
#   instead. This will output temperature tags without location information',
#    required => 0,
#);
$plugin->add_arg(
    spec => 'hostname|H=s',
    help => '--hostname
   Hostname or IP-address of the switch or router',
    required => 0,
);
$plugin->add_arg(
    spec => 'port=i',
    help => '--port
   The SNMP port to use (default: 161)',
    required => 0,
    default => 161,
);
$plugin->add_arg(
    spec => 'protocol|P=s',
    help => '--protocol
   The SNMP protocol to use (default: 2c, other possibilities: 1,3)',
    required => 0,
    default => '2c',
);
$plugin->add_arg(
    spec => 'community|C=s',
    help => '--community
   SNMP community of the server (SNMP v1/2 only)',
    required => 0,
    default => 'public',
);
$plugin->add_arg(
    spec => 'username=s',
    help => '--username
   The securityName for the USM security model (SNMPv3 only)',
    required => 0,
);
$plugin->add_arg(
    spec => 'authpassword=s',
    help => '--authpassword
   The authentication password for SNMPv3',
    required => 0,
);
$plugin->add_arg(
    spec => 'authprotocol=s',
    help => '--authprotocol
   The authentication protocol for SNMPv3 (md5|sha)',
    required => 0,
);
$plugin->add_arg(
    spec => 'privpassword=s',
    help => '--privpassword
   The password for authPriv security level',
    required => 0,
);
$plugin->add_arg(
    spec => 'privprotocol=s',
    help => '--privprotocol
   The private protocol for SNMPv3 (des|aes|aes128|3des|3desde)',
    required => 0,
);
$plugin->add_arg(
    spec => 'snmpwalk=s',
    help => '--snmpwalk
   A file with the output of a snmpwalk (used for simulation)',
    required => 0,
);
$plugin->add_arg(
    spec => 'warning=s',
    help => '--warning
   The warning threshold',
    required => 0,
);
$plugin->add_arg(
    spec => 'mode=s',
    help => "--mode
   A keyword which tells the plugin what to do
$modestring",
    required => 1,
);
$plugin->add_arg(
    spec => 'name=s',
    help => "--name
   The name of an interface",
    required => 0,
);
$plugin->add_arg(
    spec => 'regexp',
    help => "--regexp
   A flag indicating that --name is a regular expression",
    required => 0,
);
$plugin->add_arg(
    spec => 'units=s',
    help => "--units
   One of %, KB, MB, GB. (used for e.g. mode interface-usage)",
    required => 0,
);
$plugin->add_arg(
    spec => 'lookback=s',
    help => "--lookback
   The amount of time you want to look back when calculating average rates.
   Use it for mode interface-errors or interface-usage. Without --lookback
   the time between two runs of check_nwc_health is the base for calculations.
   If you want your checkresult to be based for example on the past hour,
   use --lookback 3600. ",
    required => 0,
);
$plugin->add_arg(
    spec => 'critical=s',
    help => '--warning
   The critical threshold',
    required => 0,
);
$plugin->add_arg(
    spec => 'servertype=s',
    help => '--servertype
   The type of the network device: cisco (default). Use it if auto-detection
   is not possible',
    required => 0,
);

$plugin->getopts();
if ($plugin->opts->community) {
  if ($plugin->opts->community =~ /^snmpv3(.)(.+)/) {
    my $separator = $1;
    my ($authprotocol, $authpassword, $privprotocol, $privpassword, $username) =
        split(/$separator/, $2);
    $plugin->override_opt('authprotocol', $authprotocol) 
        if defined($authprotocol) && $authprotocol;
    $plugin->override_opt('authpassword', $authpassword) 
        if defined($authpassword) && $authpassword;
    $plugin->override_opt('privprotocol', $privprotocol) 
        if defined($privprotocol) && $privprotocol;
    $plugin->override_opt('privpassword', $privpassword) 
        if defined($privpassword) && $privpassword;
    $plugin->override_opt('username', $username) 
        if defined($username) && $username;
    $plugin->override_opt('protocol', '3') ;
  }
}
if ($plugin->opts->snmpwalk) {
  $plugin->override_opt('hostname', 'snmpwalk.file') 
}
$plugin->{messages}->{unknown} = []; # wg. add_message(UNKNOWN,...)

$plugin->{info} = []; # gefrickel

if ($plugin->opts->mode =~ /^my-([^\-.]+)/) {
  my $param = $plugin->opts->mode;
  $param =~ s/\-/::/g;
  push(@modes, [$param, $plugin->opts->mode, undef, 'my extension']);
} elsif ((! grep { $plugin->opts->mode eq $_ } map { $_->[1] } @modes) &&
    (! grep { $plugin->opts->mode eq $_ } map { defined $_->[2] ? @{$_->[2]} : () } @modes)) {
  printf "UNKNOWN - mode %s\n", $plugin->opts->mode;
  $plugin->opts->print_help();
  exit 3;
}

$SIG{'ALRM'} = sub {
  printf "UNKNOWN - check_nwc_health timed out after %d seconds\n", 
      $plugin->opts->timeout;
  exit $ERRORS{UNKNOWN};
};
alarm($plugin->opts->timeout);

$NWC::Device::plugin = $plugin;
$NWC::Device::mode = (
    map { $_->[0] }
    grep {
       ($plugin->opts->mode eq $_->[1]) ||
       ( defined $_->[2] && grep { $plugin->opts->mode eq $_ } @{$_->[2]})
    } @modes
)[0];
my $server = NWC::Device->new( runtime => {

    plugin => $plugin,
    options => {
        servertype => $plugin->opts->servertype,
        verbose => $plugin->opts->verbose,
        scrapiron => 0,
        customthresholds => $plugin->opts->get('customthresholds'),
        blacklist => $plugin->opts->blacklist,
        celsius => $CELSIUS,
        perfdata => $PERFDATA,
        extendedinfo => $EXTENDEDINFO,
        hwinfo => $HWINFO,
        noinstlevel => $NOINSTLEVEL,
    },
},);
#$server->dumper();
if (! $plugin->check_messages()) {
  $server->init();
  #$plugin->add_message(OK, $server->identify()) if $HWINFO;
  if (! $plugin->check_messages()) {
    #$plugin->add_message(OK, 'hardware working fine');
    $plugin->add_message(OK, $server->get_summary()) 
        if $server->get_summary();
    $plugin->add_message(OK, $server->get_extendedinfo()) 
        if $server->get_extendedinfo();
  } 
} else {
  $plugin->add_message(CRITICAL, 'wrong device');
}
my ($code, $message) = $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", join("\n", @{$NWC::Device::info})
    if $plugin->opts->verbose >= 1;
#printf "%s\n", Data::Dumper::Dumper($plugin->{info});
$plugin->nagios_exit($code, $message);

