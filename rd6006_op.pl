#!/usr/bin/perl
#===============================================================================
#
#         FILE: rd6006_op.pl
#
#        USAGE: rd6006_op.pl  [-h] [-d] [-m /dev/device] [-u unit] [-O=off] [-P=on_before] [-v v_set] [ -i i_set ] [-V d_v] [-I d_i] [-n n_read] [-t t_read]
#
#  DESCRIPTION: simple RD6006 interactions via modbus
#
# REQUIREMENTS: --- Device::Modbus::RTU::Client, Getopt::Long, Time:HiRes
#       AUTHOR: atu
#      VERSION: 1.0
#      CREATED: 03/14/20 23:46:23
#      LICENSE: GPLv3
#===============================================================================

use Getopt::Long qw(:config no_ignore_case ); # auto_help
use Device::Modbus::RTU::Client;
use Time::HiRes qw( usleep );

# use Data::Dumper;

use strict;
use warnings;
use utf8;

sub MB_wr1; # (addr, val, "action" )
sub MB_set_v; # ( V_volt )

my $v_max = 60.0;
my $i_max = 6.0;
my $sleep_cmd_resp = 50000; # sleep time in ms between cmd and responce

my $help_need = 0;
my $tty = '/dev/ttyUSB0';
my $unit = 1;
my $debug = 0;
my $v_set = -1.0; # flag : no set
my $i_set = -1.0;
my $n_read = 1;
my $t_read = 1.0;
my $d_v = 0.0;
my $d_i = 0.0;
my $reverse_at = -1;
my $off_after = 0;
my $on_before = 0;

STDOUT->autoflush( 1 );

my %opts = (
    #  'h|help'   => \$help_need,
  'd|debug+'       => \$debug,
  'u|unit=o'       => \$unit,
  'm|tty=s'        => \$tty,
  'n|n_read=o'     => \$n_read,
  't|t_read=f'     => \$t_read,
  'v|v_set=f'      => \$v_set,
  'i|i_set=f'      => \$i_set,
  'V|d_v=f'        => \$d_v,
  'I|d_i=f'        => \$d_i,
  'r|reverse_at=i' => \$reverse_at,
  'P|on_before'    => \$on_before,
  'O|off_after'    => \$off_after
);

my $opt_rc = GetOptions ( %opts );

if( $help_need || !$opt_rc ) {
  print( STDERR "Usage: rd6006_op [options]\n Options:\n\n");
  while( my ($key,$val) = each( %opts )  ) {
    print( STDERR " -" . $key . "\n" );
  }
  exit(0);
};

if( $debug > 0 ) {
  while( my ($key,$val) = each( %opts )  ) {
    print( STDERR "# $key = " . $$val . "\n" );
  }
}




my $client = Device::Modbus::RTU::Client->new(
  port     => $tty,
  baudrate => 115200,
  parity   => 'none',
);

if( $on_before ) {
  # TODO: set v if set
  if( $v_set > 0 ) {
    MB_set_v( $v_set );
  }
  MB_wr1( 18, 1, "On" );
}

printf( "# v_out i_out v_set_r i_set_r w_out is_on err_x \n" );

my $v_cur = $v_set;
my $i_cur = $i_set;

for( my $it = 0; $it < $n_read; ++$it ) {

  if( $it == $reverse_at ) {
    $d_v = -$d_v;
    $d_i = -$d_i;
  }

  if( $debug > 0 ) {
    print STDERR sprintf( "# %d %f %f\n" , $it, $v_cur, $i_cur );
  }

  # set V
  if( $v_set >=0 && $v_cur >=0 && $v_cur < $v_max ) {
    MB_set_v( $v_cur );
  }

  # set I if req
  if( $i_set >=0 && $i_cur >=0 && $i_cur < $i_max ) {
    if( $it == 0 || abs($d_i) > 1e-6 ) {
      MB_set_I( $i_cur );
    }
  }

  usleep( $t_read * 1e6 );

  my $req = $client->read_holding_registers( unit => $unit, address  => 0, quantity => 20 );

  $client->send_request( $req ) || die "Send error (read): $!";

  my $resp = $client->receive_response;


  if( ! $resp->success ) {
    die( "Fail to receive response" );
  }

  my $v= $resp->values;

  if( @$v[0] != 60062 ) {
    die( "Bad device ID: " . @$v[0] );
  }

  my $v_set_r = 0.010 * @$v[8];
  my $i_set_r = 0.001 * @$v[9];
  my $v_out   = 0.010 * @$v[10];
  my $i_out   = 0.001 * @$v[11];
  my $w_out   = 0.010 * @$v[13];
  my $err_x   = @$v[16];
  my $is_on   = @$v[18] ? 1 : 0;

  my $s = sprintf( "%5.2f   %5.3f %5.2f   %5.3f %6.2f   %1d    %2d\n",
          $v_out, $i_out, $v_set_r, $i_set_r, $w_out, $is_on, $err_x );

  print( $s );
  if( $debug > 0 ) {
    print( STDERR $s );
  }

  $v_cur += $d_v;
  $i_cur += $d_i;
}

if( $off_after ) {
  MB_wr1( 18, 0, "Off" );
}

# --------------------------------------------------------------------------------------


sub MB_wr1 # (addr, val, "action" )
{
  my $addr = $_[0];
  my $val  = $_[1];
  my $act_str  = $_[2];
  my $req = $client->write_single_register( unit => $unit, address  => $addr, value => $val );
  $client->send_request( $req ) || die "Send error: $act_str: addr: $addr rc= $!";
  usleep( $sleep_cmd_resp );
  my $resp = $client->receive_response;
  if( ! $resp->success ) {
    die( "Fail to receive response on $act_str" );
  }
  return $resp;
}

sub MB_set_v # ( V_volt )
{
  return MB_wr1( 8, $_[0] * 100, "V_set" );
}

sub MB_set_I # ( I_A )
{
  return MB_wr1( 9, $_[0] * 1000, "I_set" );
}

