#!/usr/bin/perl
#===============================================================================
#
#         FILE: rd6006_op.pl
#
#        USAGE: rd6006_op.pl  [-h] [-d] [-m /dev/device] [-u unit] [-O=off] [-P=on_before] [-v v_set] [ -i i_set ] [-V d_v] [-I d_i] [-n n_read] [-t t_read]
#
#  DESCRIPTION: simple RD6006 interactions via modbus
#
# REQUIREMENTS: --- Device::Modbus::RTU::Client, Getopt::Long, Time:HiRes, Device::RD6006 (local)
#       AUTHOR: atu
#      VERSION: 1.0
#      CREATED: 03/14/20 23:46:23
#      LICENSE: GPLv3
#===============================================================================

use Getopt::Long qw(:config no_ignore_case ); # auto_help
use Time::HiRes qw( usleep );

use Device::RD6006;


use strict;
use warnings;
use utf8;

my $v_max = 60.0;
my $i_max = 6.0;
my $sleep_cmd_resp = 50000; # sleep time in us between cmd and responce

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
}

if( $debug > 0 ) {
  while( my ($key,$val) = each( %opts )  ) {
    print( STDERR "# $key = " . $$val . "\n" );
  }
}

my $pwr1 = Device::RD6006->new( $tty, $unit );

print( STDERR "v_scale= ", $pwr1->{v_scale}, "\n" );

if( ! $pwr1->check_Signature() ) {
  die( "Error: bad signature" );
}



if( $on_before ) {
  if( $v_set > 0 ) {
    $pwr1->set_V( $v_set );
  }
  $pwr1->On();
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
    $pwr1->set_V( $v_cur );
  }

  # set I if req
  if( $i_set >=0 && $i_cur >=0 && $i_cur < $i_max ) {
    if( $it == 0 || abs($d_i) > 1e-6 ) {
      $pwr1->set_I( $i_cur );
    }
  }

  usleep( $t_read * 1e6 );

  if( ! $pwr1->readMainRegs() ) {
    die( "Fail to read registers" );
  }
  #
  # my $v_set_r = 0.010 * @$v[8];
  # my $i_set_r = 0.001 * @$v[9];
  # my $v_out   = 0.010 * @$v[10];
  # my $i_out   = 0.001 * @$v[11];
  # my $w_out   = 0.010 * @$v[13];
  # my $err_x   = @$v[16];
  # my $is_on   = @$v[18] ? 1 : 0;

  my $s = sprintf( "%5.2f   %5.3f %5.2f   %5.3f %6.2f   %1d    %2d\n",
          $pwr1->get_V(), $pwr1->get_I(), $pwr1->get_V_set(), $pwr1->get_I_set(),
          $pwr1->get_W(), $pwr1->get_OnOff(), $pwr1->get_Error() );

  print( $s );
  if( $debug > 0 ) {
    print( STDERR $s );
  }

  $v_cur += $d_v;
  $i_cur += $d_i;
}

if( $off_after ) {
  $pwr1->Off();
}

# --------------------------------------------------------------------------------------

# vim: shiftwidth=2
