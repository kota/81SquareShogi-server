#!/usr/bin/perl -w

# - ログインする
# - 引数で与えたファイルから命令を読みこんで実行する
# - ログアウトする

# 命令
# - サーバに送るもの: /^%+-[A-Z]/ そのまま送る
# - 拡張命令
#   nop " \n" を送る
#   read 1行読む (なければblockする)
#   read_all blockせずに読めるだけ読む
#   sleep x

# 実行例
# replay.pl filename.csa

use CsaClient;
use IO::Handle;
use POSIX;
use Error qw(:try);
use strict;

my $host = $ENV{SERVER} ? $ENV{SERVER} : "localhost"; # "wdoor.c.u-tokyo.ac.jp";
my $port = $ENV{PORT} ? $ENV{PORT} : '4081';
my $player_id = pop(@ARGV);
my $game_id = ceil($player_id/2);
my $user = $ENV{SHOGIUSER} ? $ENV{SHOGIUSER} : "test$player_id";
my $pass = $ENV{SHOGIPASS} ? $ENV{SHOGIPASS} : "monkey";
my $sleep = $ENV{SLEEP} ? $ENV{SLEEP} : 0;
my $gentle = $ENV{GENTLE} ? $ENV{GENTLE} : 0;

$| = 1;

my $client = new CsaClient($user, $pass);
$client->connect($host, $port);
$client->login_x1();
my $tesu = 0;
while(1){
  $client->send("%%GAME replaytest$game_id-900-0 *\n");
  print STDERR "This is $player_id";
  my ($sente, $initial_filename, $opname, $timeleft, $byoyomi)
    = $client->wait_opponent($$);
  if (!$sente) {
    $client->read();
  }
  open (FILE, "test20100408.csa") or die "$!";
  while (<FILE>) {
      chomp;
      if (/^sleep ([0-9]+)/) {
  	    sleep $1;
      } elsif (/^LOGOUT/) {
  	    last;
      } elsif (/^(\+.+)/) {
        if ($sente) {
  	      $client->send("$1\n");
          $tesu++;
  	      sleep $sleep
  	      if ($sleep);
  	      $client->read_or_gameend();
        	$client->read_or_gameend()
  	      if ($gentle);
        }
      } elsif (/^(-.+)/) {
        if (!$sente) {
  	      $client->send("$1\n");
          $tesu++;
        	sleep $sleep
  	      if ($sleep);
        	$client->read_or_gameend();
         	$client->read_or_gameend()
      	  if ($gentle);
        }
      } elsif (/^(\%TORYO)/) {
        if(($sente && ($tesu % 2 == 0)) || (!$sente && ($tesu % 2 == 1))){
          print STDERR "SEND TORYO $player_id";
  	      $client->send("$1\n");
          sleep $sleep
  	      if ($sleep);
          $client->read_or_gameend();
          #$client->read_or_gameend()
      	  #if ($gentle);
        }
      } elsif (/^read_all/) {
      	while ($client->try_read()) {
  	    }
      } elsif (/^read/) {
  	    $client->read();
      } elsif (/^nop/) {
  	    $client->send(" \r");
  	    $client->read();
      } elsif (/^T[0-9]+/) {
        ;				# silently ignore
      } else {
  	    warn "ignored $_\n";
      }
  }
  close(FILE);
}
$client->logout();
$client->disconnect();
exit 0;
