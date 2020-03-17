#!/usr/bin/perl
#===============================================================================
#
#         FILE: rd6006_op.pl
#
#        USAGE: rd6006_op.pl  [-h] [-d] [-m /dev/device] [-u unit] [-O=off] [-v v_set] [ -i i_set ] [-V d_v] [-I d_i] [-n n_read] [-t t_read]
#
#  DESCRIPTION: simple RD6006 interactions via modbus
#
# REQUIREMENTS: --- Device::Modbus::RTU::Client, Getopt::Std, Time:HiRes
#       AUTHOR: atu
#      VERSION: 1.0
#      CREATED: 03/14/20 23:46:23
#      LICENSE: GPLv3
#===============================================================================

use Getopt::Std;
use Device::Modbus::RTU::Client;
use Time::HiRes qw( usleep );
use Data::Dumper;

use strict;
use warnings;
use utf8;

my $v_max = 60.0;
my $i_max = 6.0;

my $tty = '/dev/ttyUSB0';
my $debug = 0;
my $v_set = -1.0; # flag : no set
my $i_set = -1.0;
my $n_read = 1;
my $t_read = 1.0;
my $d_v = 0.0;
my $d_i = 0.0;
my $off_after = 0;


my %option = ();
if( ! getopts( "hdOv:i:m:n:t:u:V:I:", \%option ) ) {
  die( "Option error. Try use -h.\n" );
};
if( $option{"h"} ) {
  print("Usage: rd6006_op [-h] [-d] [-m /dev/device] [-u unit] [-v v_set] [ -i i_set ] [-V d_v] [-I d_i] [-n n_read] [-t t_read]\n");
  exit(0);
};
if( $option{"d"} ) {
  $debug++;
  printf("Debug: debug level is now %d\n", $debug );
};
if( $option{"m"} ) {
  $tty = $option{"m"};
  if( $debug > 0 ) {
    printf("Debug: device is <%s>\n", $tty );
  }
};
if( $option{"v"} ) {
  $v_set = $option{"v"};
  if( $debug > 0 ) {
    printf("Debug: set voltage to  %f\n", $v_set );
  }
  if( $v_set < 0 || $v_set > $v_max ) {
      die( "Bad set voltage: " . $v_set );
  }
};
if( $option{"i"} ) {
  $i_set = $option{"i"};
  if( $debug > 0 ) {
    printf("Debug: set current to  %f\n", $i_set );
  }
  if( $i_set < 0 || $i_set > $i_max ) {
      die( "Bad set current " . $i_set );
  }
};
if( $option{"n"} ) {
  $n_read = $option{"n"};
  if( $debug > 0 ) {
    printf("Debug: n_read: %d\n", $n_read );
  }
};
if( $option{"t"} ) {
  $t_read = $option{"t"};
  if( $debug > 0 ) {
    printf("Debug: t_read %d\n", $t_read );
  }
};
if( $option{"V"} ) {
  $d_v = $option{"V"};
  if( $debug > 0 ) {
    printf("Debug: d_v = %f\n", $d_v );
  }
};
if( $option{"I"} ) {
  $d_i = $option{"I"};
  if( $debug > 0 ) {
    printf("Debug: d_i = %f\n", $d_i );
  }
};
if( $option{"O"} ) {
  $off_after = 1;
  if( $debug > 0 ) {
    printf("Debug: off_after = %d\n", $off_after );
  }
};


my $client = Device::Modbus::RTU::Client->new(
  port     => $tty,
  baudrate => 115200,
  parity   => 'none',
);

for( my $it = 0; $it < $n_read; ++$it ) {

  my $v_cur = $v_set + $d_v * $it;
  my $i_cur = $i_set + $d_i * $it;

  if( $debug > 0 ) {
    printf( "# %d %f %f\n" , $it, $v_cur, $i_cur );
  }

  if( $v_set >=0 && $v_cur >=0 && $v_cur < $v_max ) {
    my $req_v = $client->write_single_register( unit => 1, address  => 8, value => int( $v_cur * 100 ) );
    $client->send_request( $req_v ) || die "Send error (set_v): $!";
    my $resp_v = $client->receive_response;
    usleep( 100000 );
  }

  if( $i_set >=0 && $i_cur >=0 && $i_cur < $i_max ) {
    my $req_i = $client->write_single_register( unit => 1, address  => 9, value => int( $i_cur * 1000 ) );
    $client->send_request( $req_i ) || die "Send error (set_i): $!";
    my $resp_i = $client->receive_response;
  }

  usleep( $t_read * 1e6 );

  my $req = $client->read_holding_registers(
    unit     => 1,
    address  => 0,
    quantity => 20,
  );

  $client->send_request( $req ) || die "Send error (read): $!";

  my $resp = $client->receive_response;

  # if( $debug > 1 ) {
  #   print( Dumper ( $resp ) );
  # }

  if( ! $resp->success ) {
    die( "Fail to receive response" );
  }

  my $v= $resp->values;
  # if( $debug > 0 ) {
  #   print( Dumper ( $v ) );
  # }

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

  printf( "%5.2f %5.3f %5.2f %5.3f %6.2f %1d %2d\n", $v_out, $i_out, $v_set_r, $i_set_r, $w_out, $is_on, $err_x );
}

if( $off_after ) {
  my $req_off = $client->write_single_register( unit => 1, address  => 18, value => 0 );
  $client->send_request( $req_off ) || die "Send error (off): $!";
  my $resp_off = $client->receive_response;
}

