#!/usr/bin/perl -w

# - ログインする
# - 引数で与えたファイルもしくはSTDINから，命令を読みこんで実行する
# - ログアウトする

# 命令
# - サーバに送るもの: /^%+-[A-Z]/ そのまま送る
# - 拡張命令
#   nop " \n" を送る
#   read 1行読む (なければblockする)
#   read_all blockせずに読めるだけ読む
#   sleep x

# TODO:
# - LOGOUT しないで disconnect するような行儀の悪いプログラムのサポート

# 実行例
# (echo '%%CHAT hello'; echo 'sleep 10'; echo '%%CHAT hello2'; echo 'read_all' echo 'LOGOUT') | ./scenario_x1.pl


use CsaClient;
use IO::Handle;
use strict;

my $host = "wdoor.c.u-tokyo.ac.jp";
my $port = $ENV{PORT} ? $ENV{PORT} : '4081';
my $user = $ENV{SHOGIUSER} ? $ENV{SHOGIUSER} : "scenariotest$$";
my $pass = $ENV{SHOGIPASS} ? $ENV{SHOGIPASS} : "scenariotest$$";

$| = 1;

my $client = new CsaClient($user, $pass);
$client->connect($host, $port);
# $client->login();
$client->login_x1();

while (<>) {
    chomp;
    if (/^sleep ([0-9]+)/) {
	sleep $1;
    } elsif (/^LOGOUT/) {
	last;
    } elsif (/^([A-Z%].+)/) {
	$client->send("$1\n");
    } elsif (/^([+-].+)/) {
	$client->send("$1\n");
	$client->read();
    } elsif (/^read_all/) {
	while ($client->try_read()) {
	}
    } elsif (/^read/) {
	$client->read();
    } elsif (/^nop/) {
	$client->send(" \r");
	$client->read();
    } elsif (/^wait_opponent/) {
        my ($sente, $initial_filename, $opname, $timeleft, $byoyomi)
	  = $client->wait_opponent($$);
    } else {
	warn "ignored $_\n";
    }
}

$client->logout();
$client->disconnect();
exit 0;

