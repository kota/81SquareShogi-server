package CsaClient;
use IO::Handle;
use Socket;
use strict;
use POSIX;

### TODO:
### CSA or X1
### logging or not

sub new ($$$) {
    my ($pkg, $name, $password) = @_;

    my $this = { name => $name,
		 password => $password,
		 verbose => 0,
		 in_game => 0,
	       };
    bless $this;
    return $this;
}

sub send ($$)
{
    my ($this, $message) = @_;

    my $socket = $this->{socket};
    die "not connected"
    unless $socket;
    print $socket "$message";
    if ($message ne "\n") {
      print STDERR "SEND:$message";
    } else {
      print STDERR '.';
    }
}

my $read_error = 0;
sub try_read_in_sec ($$)
{
    my ($this,$sec) = @_;
    my $socket = $this->{socket};
    my ($rin, $rout);
    my $line = undef;

    $rin = '';
    vec($rin,fileno($socket),1) = 1;
    while (1) {
      my $nfound = select($rout=$rin, undef, undef, $sec);
      return undef
	    unless ($nfound);
      my $line = $this->read_force();
      if (! defined $line) {
	      ++$read_error;
	      die "connection closed?"
		    if ($read_error > 10);
	    } else {
	      $read_error = 0;
	    }
	    return $line
	    unless ($line eq "\n");
	# print STDERR "read again\n";
    }
}

sub try_read ($)
{
    my ($this) = @_;
    return $this->try_read_in_sec(0.001);
}

sub read ($)
{
    my ($this) = @_;
    my $line;
    while (1) {
      return $line
	    if (defined ($line = $this->try_read_in_sec(531.0)));
      $this->send("\n");
    }
}

sub read_force ($)
{
    my ($this) = @_;
    my $socket = $this->{socket};
    # equivalent to "my $line = <$socket>;"
    my $line = undef;
    my $char;
    while (sysread($socket, $char, 1) == 1) {
      $line .= $char;
      last
      if ($char eq "\n");
    }

    if (defined $line) {
      if ($line ne "\n") {
        print STDERR "RECV:$line";
      } else {
        print STDERR ",";
      }
    } else {
	    warn "read force from server failed! $!"
    }
    return $line;
}

sub read_skip_chat ($)
{
    my ($this) = @_;
    while (1) {
	my $line = $this->read();
	return $line
	    unless ((defined $line) && ($line =~ /^\#\#\[CHAT\]/));
	$line =~ s/\#\#\[CHAT\]\[[A-Za-z0-9_@-]+\]\s+//;
	if ($line =~ /^([A-Za-z0-9_@-])+\s+(verbose|silent)/) {
	    my $command = $2;
	    if ($this->{name} =~ /$1/) {
		if ($command eq "verbose") {
		    print STDERR "verbose\n";
		    $this->{verbose} = 1;
		} else {
		    print STDERR "silent\n";
		    $this->{verbose} = 0;
		}
	    }
	}
    }
}

sub read_or_gameend ($)
{
    my ($this) = @_;
    my $line0 = $this->read_skip_chat();
    my $line = $line0;
    my @skipped;
    if ($line =~ /^\#/ || $line =~ /^\%/ ) {
      do
      {
        push(@skipped, $line);
        if ($line =~ /^\#(WIN|LOSE|DRAW|CHUDAN)/) {
      	  if ($line =~ /^\#WIN/) {
            $this->chat_com("kachi-mashita");
          } elsif ($line =~ /^\#DRAW/) {
            $this->chat_com("hikiwake-deshita");
          } elsif ($line =~ /^\#LOSE/) {
            $this->chat_com("make-mashita");
          }
          $this->{in_game} = 0;
          return (1,$line0,@skipped);
        }
        $line = $this->read_skip_chat();
	    } while ($line =~ /\#/);
      print STDERR "CsaClient: unknown path $line\n";
      return (1, $line,@skipped);	# このパスなんだろう
    }
    return (0, $line);
}

sub connect ($$$)
{
    my ($this, $host, $port) = @_;
    print STDERR "SYSTEM:connect to $host:$port\n";

    die "No port" unless $port;
    my $iaddr   = inet_aton($host)               || die "no host: $host";
    my $paddr   = sockaddr_in($port, $iaddr);

    my $proto   = getprotobyname('tcp');
    my $sock;

    socket($sock, PF_INET, SOCK_STREAM, $proto)  || die "socket: $!";
    connect($sock, $paddr)    || die "connect: $!";

    $sock->autoflush (1);
    $this->{socket} = $sock;
    print STDERR "SYSTEM:connected\n";

    sleep 1;
}

sub login_x1 ($)
{
    my ($this) = @_;
    my $user = $this->{name};
    my $pass = $this->{password};
    $this->send("LOGIN $user $pass x1\n");

    my $line;
    my $user_without_trip = $user;
    $user_without_trip =~ s/,.*//;
    do
    {
	$line = $this->read();
    }
    while ($line !~ /LOGIN:($user_without_trip|incorrect)/);

    die "ERR :$line" 
	unless $line =~ /OK/;
    do
    {
	$line = $this->read();
    }
    while ($line !~ /\#\#\[LOGIN\] \+OK x1/);
    die "ERR :$line" 
	unless $line =~ /OK/;
    print STDERR "SYSTEM:login ok\n";
}

sub login ($)
{
    my ($this) = @_;
    my $user = $this->{name};
    my $pass = $this->{password};
    $this->send("LOGIN $user $pass\n");

    my $line;
    do
    {
	$line = $this->read();
    }
    while ($line !~ /LOGIN:($user|incorrect)/);

    die "ERR :$line" 
	unless $line =~ /OK/;
}

sub logout($)
{
    my ($this) = @_;
    $this->send("LOGOUT\n");

    my $line;
    while (defined ($line = $this->try_read()))
    {
      print $line;
    }
}

sub disconnect ($)
{
    my ($this) = @_;
    close($this->{socket});
}

sub chat ($$)
{
    my ($this, $message) = @_;
    $this->send('%%CHAT ' . $message . "\n");
}
sub chat_com ($$)
{
    my ($this, $message) = @_;
    $this->chat("com: $message")
	if ($this->{verbose});
}

sub offer_game_x1 ($$$)
{
    my ($this,$gamename,$sente_string) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    $year += 1900; $mon += 1;
    print STDERR "SYSTEM:offer_game ($year-$mon-$mday $hour:$min)\n";

    my $game_string = "%%GAME $gamename $sente_string\n"; 
    $this->send($game_string);
}

sub wait_opponent ($$)
{
    print STDERR "SYSTEM: wait_opponent\n";
    my ($this, $csafile_basename) = @_;
    my $sente = -1;
    my $line;
    my $timeleft = 0;
    my $byoyomi = 0;
    my $sente_name = "unknown";
    my $gote_name  = "unknown";

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900; $mon += 1;
    my $record_base = 
    sprintf ('%s%04d%02d%02d-%02d-%02d-%02d',
    $csafile_basename,$year,$mon,$mday,$hour,$min,$sec);
    my $csafilename = "logs/$record_base-$$.init";
    $this->{record_file} = "logs/$record_base-comm-$$.csa";

    while (1)
    {
      $line = $this->read_skip_chat();
      return
	    if (! defined $line);
      if ($line =~ /^\#/) {
	      warn "unexpected $line";
	      next;
      }

      if ($line =~ /^Name\+:(.+)/)
      {
          $sente_name = $1;
      }
      elsif ($line =~ /^Name\-:(.+)/)
      {
          $gote_name = $1;
      }
      elsif ($line =~ /^Your_Turn:(?)/)
      {
          $sente = 1 if $line =~ /\+/;
          $sente = 0 if $line =~ /\-/;
          print STDERR "SYSTEM: we are $sente\n";
      }
      elsif ($line =~ /^Total_Time:(.+)/)
      {
          #we assume that Time_Unit is 1sec
          $timeleft = $1;
      }
      elsif ($line =~ /^Byoyomi:(.+)/)
      {
          $byoyomi = $1;
          $byoyomi -= int(POSIX::floor($byoyomi / 10))
      	if ($byoyomi / 10 > 0);
      }
      elsif ($line =~ /^BEGIN Position/)
      {
          print STDERR "SYSTEM:$line";
          open CSAFILE, "> $csafilename"
      	|| die "CsaClient: open $!";
          print CSAFILE "N+$sente_name\n";
          print CSAFILE "N-$gote_name\n";
          while (1)
          {
      	    $line = $this->read_skip_chat();
      	    next
      	        if ($line =~ /^Jishogi_Declaration:/);
      	    last
      	        if ($line =~ /^END Position/);
      	    print CSAFILE $line
      	        unless $line =~ /P[\+|\-]/;
          }
          close CSAFILE;
          system "cp", "$csafilename", $this->{record_file};
          chmod 0644, $this->{record_file};
      }
      last
      if ($line =~ /^END Game_Summary/);
    }
    sleep 2;
    $this->send("AGREE\n");
    $line = $this->read_skip_chat();
    $sente = -2
    if ($line =~ /^REJECT/);

    $this->{in_game} = 1
    if ($sente >= 0);
    $this->{sente} = $sente;
    return ($sente, $csafilename, ($sente ? $gote_name : $sente_name),$timeleft, $byoyomi);
}

sub record_move ($$) {
    my ($handle, $move) = @_;
    chomp $move;
    if ($move =~ /^[#%]/) {
	print $handle "'",$move."\n";
    }
    elsif ($move =~ /^(.*),(T\d+)$/) {
	print $handle $1."\n";
	print $handle $2."\n";
    }
    else {
	print $handle $move."\n";
    }
}

#
# $program : new GpsShogi したもの(など)
sub play ($$) {
    my ($this, $program) = @_;
    if (! $this->{in_game}) {
	warn "CsaClient: cannot play not in_game status\n";
	return;
    }
    $program->set_master_record($this->{record_file});
    my $record_handle;
    open $record_handle, ">> ".$this->{record_file}
	|| die "open $! " . $this->{record_file}."\n";
    $record_handle->autoflush(1);

    if ($this->{sente} == 0) {
	# op turn
	my ($gameend,$line,@skip) = $this->read_or_gameend();
	record_move($record_handle, $line);
	map { record_move($record_handle, $_) } @skip;
	if ($gameend) {
	    $program->send ('%TORYO'."\n");
	    return;
	}
	$line =~ s/,T(\d+)$//;
	$program->send ($line);
    }

    while (1) {
	# my turn
	my ($line,$gameend,@skip);
	$line = $program->read();
	last
	    if (! defined $line);

	$this->send($line)
	    if (defined $line);	# %TORYOの時は undefined
	($gameend,$line,@skip) = $this->read_or_gameend();
	record_move($record_handle, $line);
	map { record_move($record_handle, $_) } @skip;

	if ($gameend) {
	  $program->send ('%TORYO'."\n");
	  last;
	}

	# op turn
	($gameend,$line,@skip) = $this->read_or_gameend();
	record_move($record_handle, $line);
	map { record_move($record_handle, $_) } @skip;
	if ($gameend) {
	    $program->send ('%TORYO'."\n");
	    last;
	}

	$line =~ s/,T(\d+)$//;
	$program->send ($line);
	if ($line =~ /^%/) {
	    ($gameend,$line,@skip) = $this->read_or_gameend();
	    warn "game does not end $line"
		unless $gameend;
	    last
		if ($gameend);
	}
    }
    close $record_handle;
}

# END
return 1;
