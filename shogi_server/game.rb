## $Id$

## Copyright (C) 2004 NABEYA Kenichi (aka nanami@2ch)
## Copyright (C) 2007-2008 Daigo Moriwaki (daigo at debian dot org)
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'shogi_server/league/floodgate'
require 'shogi_server/game_result'

module ShogiServer # for a namespace

class Game
  # When this duration passes after this object instanciated (i.e.
  # the agree_waiting or start_waiting state lasts too long),
  # the game will be rejected by the Server.
  WAITING_EXPIRATION = 120 # seconds

  @@mutex = Mutex.new
  @@time  = 0
  def initialize(game_name, player0, player1, board)
    @monitors = Array::new # array of MonitorHandler*
    @game_name = game_name
    if (@game_name =~ /-(\d+)-(\d+)$/)
      @total_time = $1.to_i
      @byoyomi = $2.to_i + 10
    end

    if (player0.sente)
      @sente, @gote = player0, player1
    else
      @sente, @gote = player1, player0
    end
    @sente.socket_buffer.clear
    @gote.socket_buffer.clear
    @board = board
    if @board.teban
      @current_player, @next_player = @sente, @gote
    else
      @current_player, @next_player = @gote, @sente
    end
    @sente.game = self
    @gote.game  = self
    @sente.opponent = @gote
    @gote.opponent = @sente
    @sente_mouse_out = 0
    @gote_mouse_out = 0

    @last_move = @board.initial_moves.empty? ? "" : "%s,T1" % [@board.initial_moves.last]
    @current_turn = @board.initial_moves.size

    @sente.status = "agree_waiting"
    @gote.status  = "agree_waiting"
    @sente.game_comment = "*"
    @gote.game_comment = "*"

    @game_id = sprintf("%s+%s+%s+%s+%s", 
                  $league.event, @game_name, 
                  @sente.name, @gote.name, issue_current_time)
    
    # The time when this Game instance was created.
    # Don't be confused with @start_time when the game was started to play.
    @prepared_time = Time.now 
    log_dir_name = File.join($league.dir, 
                             @prepared_time.strftime("%Y"),
                             @prepared_time.strftime("%m"),
                             @prepared_time.strftime("%d"))
    FileUtils.mkdir_p(log_dir_name) unless File.exist?(log_dir_name)
    @logfile = File.join(log_dir_name, @game_id + ".csa")

    $league.games[@game_id] = self

    #log_message(sprintf("game created %s", @game_id))

    @start_time = nil
    @kifu = Kifu.new({:blackid => @sente.id,:whiteid => @gote.id,:contents => ""})
    @result = nil
    @status = "created"
    @opening = "*"

    propose
    begin
      @kifu.save
    rescue
    ensure
      start
    end
  end
  attr_accessor :game_name, :total_time, :byoyomi, :sente, :gote, :game_id, :board, :current_player, :next_player, :fh, :monitors
  attr_accessor :last_move, :current_turn, :sente_mouse_out, :gote_mouse_out
  attr_reader   :result, :prepared_time, :kifu, :status, :end_time, :opening

  # Path of a log file for this game.
  attr_reader   :logfile

  def rated?
    @sente.rated? && @gote.rated?
  end

  def turn?(player)
    return player.status == "game" && @current_player == player
  end

  def monitoron(monitor_handler)
    @monitors.delete_if {|mon| mon == monitor_handler}
    @monitors.push(monitor_handler)
  end

  def monitoroff(monitor_handler)
    @monitors.delete_if {|mon| mon == monitor_handler}
    close if (is_closable_status?)
  end

  def each_monitor
    @monitors.each do |monitor_handler|
      yield monitor_handler
    end
  end

  def log_game(str)
    @kifu.contents += "#{str}\n"
  end

  def reject(rejector)
    @sente.write_safe(sprintf("REJECT:%s by %s\n", @game_id, rejector))
    @gote.write_safe(sprintf("REJECT:%s by %s\n", @game_id, rejector))
    finish
    @sente.game = nil
    @gote.game = nil
    @sente.game_name = ""
    @gote.game_name = ""
    @sente.opponent = nil
    @gote.opponent = nil
    @sente.status = "connected"
    @gote.status = "connected"
    @kifu.destroy
    close
  end

  def disconnect(killer)
    [@sente, @gote].each do |player|
      if ["agree_waiting", "start_waiting"].include?(player.status)
        reject(killer.name)
        return # return from this method
      end
    end
    
    if (killer.opponent.game != self && !@result)
      @result = GameResultDisconnectDraw.new(self, @next_player, @current_player)
      @result.process
      finish
    end

    killer.game = nil
    killer.game_name = ""
    killer.opponent = nil
    killer.status = "connected"
    if (is_closable_status?)
      close
    else
      @sente.write_safe(sprintf("##[DISCONNECT][%s]\n", killer.name)) if (@sente.game == self)
      @gote.write_safe(sprintf("##[DISCONNECT][%s]\n", killer.name)) if (@gote.game == self)
      each_monitor { |monitor_handler|
        monitor_handler.player.write_safe(sprintf("##[DISCONNECT][%s]\n", killer.name))
      }
    end
  end

  def reconnect(killer)
    if (killer.opponent && killer.opponent.opponent == killer)
      killer.opponent.opponent = nil if ["connected", "game_waiting"].include?(killer.opponent.status)
      killer.opponent.write_safe("##[DECLINE]Opponent canceled challenge.\n")
    end
    if (killer == @sente && @sente.game != self)
      killer.mytime = @sente.mytime
      killer.sente = true
      killer.opponent = @gote
      @sente = killer
      @gote.opponent = killer
      @gote.write_safe(sprintf("##[ENTER][%s]\n", killer.name)) if (@gote.game == self)
    elsif (killer == @gote && @gote.game != self)
      killer.mytime = @gote.mytime
      killer.sente = false
      killer.opponent = @sente
      @gote = killer
      @sente.opponent = killer
      @sente.write_safe(sprintf("##[ENTER][%s]\n", killer.name)) if (@sente.game == self)
    else
      return false
    end
    killer.game = self
    killer.game_name = @game_name
    if (@current_player == killer.opponent)
      @next_player = killer
    else
      @current_player = killer
    end
    if (@status == "game")
      killer.status = "game"
    elsif (@status == "finished")
      killer.status = "post_game"
    end
    each_monitor { |monitor_handler|
      monitor_handler.player.write_safe(sprintf("##[ENTER][%s]\n", killer.name))
    }
    return true
  end

  def declare(winner)
    if (@status == "game" && winner.opponent.game != self)
      @result = GameResultAbnormalWin.new(self, winner, winner.opponent)
      @result.process
      finish
    end
  end

  def finish
    begin
      log_message(sprintf("game finished %s", @game_id))

      # In a case where a player in agree_waiting or start_waiting status is
      # rejected, a GameResult object is not yet instanciated.
      # See test/TC_before_agree.rb.
      end_time = @result ? @result.end_time : Time.now
      @kifu.contents += "'$END_TIME:#{end_time.strftime("%Y/%m/%d %H:%M:%S")}\n"
      @kifu.save

      if (@result)
        if (@game_name =~ /^r_/)
          if (@current_turn > 3 && !@result.kind_of?(GameResultDraw))
            @sente.reload_before_save
            @gote.reload_before_save
            winner_rate0 = @result.winner.rate
            loser_rate0 = @result.loser.rate
            diff = winner_rate0 - loser_rate0
            diff = (32 - 16*(1 + Math.erf(diff / Math.sqrt(2) / 285))) * ([2,((@total_time/300) ** 0.8 - 1)/(9 ** 0.8 - 1) + 1].min)
            @result.winner.update_rate(diff)
            diff = 0.5 * diff if (@result.winner.provisional? && !@result.loser.provisional?)
            @result.loser.update_rate(- diff)
            @result.winner.write_safe(sprintf("##[RESULT]%d,%d,%d,%d\n", winner_rate0, @result.winner.rate, loser_rate0, @result.loser.rate))
            @result.loser.write_safe(sprintf("##[RESULT]%d,%d,%d,%d\n", loser_rate0, @result.loser.rate, winner_rate0, @result.winner.rate))
            if (!@result.winner.provisional?)
              @rate_change = RateChangeHistory.new({:player_id => @result.winner.id,:change => @result.winner.rate.to_i,:sente => @result.winner.sente,:opening => @opening})
              @rate_change.save
            end
            if (!@result.loser.provisional?)
              @rate_change = RateChangeHistory.new({:player_id => @result.loser.id,:change => - @result.loser.rate.to_i,:sente => @result.loser.sente,:opening => @opening})
              @rate_change.save
            end
            @result.winner.update_count(true)
            @result.loser.update_count(false)
            if (@sente.latest_ip_address == @gote.latest_ip_address)
              log_cheat("SELF", true)
            elsif (@sente_mouse_out > 0.5 * @current_turn && @sente_mouse_out >= 20)
              log_cheat("SOFT", true)
            elsif (@gote_mouse_out > 0.5 * @current_turn && @gote_mouse_out >= 20)
              log_cheat("SOFT", false)
            end
          else
            @sente.write_safe(sprintf("##[RESULT]%d,%d,%d,%d\n",@sente.rate,@sente.rate,@gote.rate,@gote.rate))
            @gote.write_safe(sprintf("##[RESULT]%d,%d,%d,%d\n",@gote.rate,@gote.rate,@sente.rate,@sente.rate))
          end
        elsif (@game_name =~ /^vazoo_/ && @current_turn > 2)
          @sente.reload_before_save
          @gote.reload_before_save
          if (@result.kind_of?(GameResultDraw))
            @sente.update_count34(0)
            @gote.update_count34(0)
          else
            @result.winner.update_count34(1)
            @result.loser.update_count34(-1)
          end
        end
      end
    rescue
      log_error("Could not save results in %s" % [@game_id])
      @sente.write_safe("##[ERROR] Connection to database server failed. Results were not saved.\n")
      @gote.write_safe("##[ERROR] Connection to database server failed. Results were not saved.\n")
    ensure
      @sente.status = "post_game" if @sente.status = "game"
      @gote.status = "post_game" if @gote.status = "game"

      if (@current_player.protocol == LoginCSA::PROTOCOL)
        @current_player.finish
      end
      if (@next_player.protocol == LoginCSA::PROTOCOL)
        @next_player.finish
      end
      @current_player = nil
      @next_player = nil
      @status = "finished"
    end
  end
  
  def close
    #log_message(sprintf("game closed %s", @game_id))
    @sente = nil
    @gote = nil
    $league.games.delete(@game_id)
    @status = "closed"
  end

  # class Game
  def handle_one_move(str, player, end_time)
    unless turn?(player)
      return false if str == :timeout

      #@fh.puts("'Deferred %s" % [str])
      @kifu.contents += "'Deferred %s\n" % [str]
      log_warning("Deferred a move [%s] scince it is not %s 's turn." %
                  [str, player.name])
      player.socket_buffer << str # always in the player's thread
      return nil
    end

    finish_flag = true
    @end_time = end_time
    t = [(@end_time - @start_time).floor, Least_Time_Per_Move].max
    
    move_status = nil
    if ((@current_player.mytime - t <= -@byoyomi) && 
        ((@total_time > 0) || (@byoyomi > 0)))
      status = :timeout
    elsif (str == :timeout)
      return false  # time isn't expired. players aren't swapped. continue game
    elsif (str == '%%%TIMEOUT' )
      status = :timeout
    else
      @current_player.mytime -= t
      if (@current_player.mytime < 0)
        @current_player.mytime = 0
      end

      move_status = @board.handle_one_move(str, @sente == @current_player)
      # log_debug("move_status: %s for %s's %s" % [move_status, @sente == @current_player ? "BLACK" : "WHITE", str])

#      if :toryo != move_status
        # Thinking time includes network traffic
        @sente.write_safe(sprintf("%s,T%d\n", str, t))
        @gote.write_safe(sprintf("%s,T%d\n", str, t))
        @kifu.contents += "#{str}\nT#{t}\n"
        @last_move = sprintf("%s,T%d", str, t)
        @current_turn += 1 unless [:toryo, :kachi_win].include?(move_status)
        
        if (@game_name =~ /^(r|nr)_/ && @opening == "*" && @current_turn >= 10 && @current_turn <= 24)
          @opening = @board.opening
          @opening = "unknown" if (@opening == "*" && @current_turn == 24)
        end

        @monitors.each do |monitor_handler|
          monitor_handler.write_one_move(@kifu.id, self)
        end
#      end # if
        # if move_status is :toryo then a GameResult message will be sent to monitors   
      if [:illegal, :uchifuzume, :oute_kaihimore].include?(move_status)
        @kifu.contents += "'ILLEGAL_MOVE(#{str})\n"
      end
    end

    @result = nil
    if (status == :timeout)
      # current_player losed
      @result = GameResultTimeoutWin.new(self, @next_player, @current_player)
    elsif (move_status == :illegal)
      @result = GameResultIllegalMoveWin.new(self, @next_player, @current_player)
    elsif (move_status == :kachi_win)
      @result = GameResultKachiWin.new(self, @current_player, @next_player)
    elsif (move_status == :kachi_lose)
      @result = GameResultIllegalKachiWin.new(self, @next_player, @current_player)
    elsif (move_status == :toryo)
      @result = GameResultToryoWin.new(self, @next_player, @current_player)
    elsif (move_status == :outori)
      # The current player captures the next player's king
      @result = GameResultOutoriWin.new(self, @current_player, @next_player)
    elsif (move_status == :oute_sennichite_sente_lose)
      @result = GameResultOuteSennichiteWin.new(self, @gote, @sente) # Sente is checking
    elsif (move_status == :oute_sennichite_gote_lose)
      @result = GameResultOuteSennichiteWin.new(self, @sente, @gote) # Gote is checking
    elsif (move_status == :sennichite)
      @result = GameResultSennichiteDraw.new(self, @current_player, @next_player)
    elsif (move_status == :uchifuzume)
      # the current player losed
      @result = GameResultUchifuzumeWin.new(self, @next_player, @current_player)
    elsif (move_status == :oute_kaihimore)
      # the current player losed
      @result = GameResultOuteKaihiMoreWin.new(self, @next_player, @current_player)
    elsif (move_status == :try_lose)
      @result = GameResultTryWin.new(self, @next_player, @current_player)
    elsif (move_status == :try_win)
      @result = GameResultTryWin.new(self, @current_player, @next_player)
    else
      finish_flag = false
    end
    @result.process if @result
    finish() if finish_flag
    @current_player, @next_player = @next_player, @current_player
    @start_time = Time::new
    return finish_flag
  end

  def compensate_delay(delay)
    @start_time += delay
    log_message(sprintf("Gave additional thinking time of %d to %s", delay, @current_player.name))
  end

  def is_startable_status?
    return (@sente && @gote &&
            (@sente.status == "start_waiting") &&
            (@gote.status  == "start_waiting"))
  end
  
  def is_closable_status?
    return (@sente && @gote &&
            (@sente.game != self) &&
            (@gote.game != self) &&
            (@monitors.length == 0))
  end

  def start
    log_message(sprintf("game started %s", @game_id))
    res = sprintf("##[START][%s]\n", @game_id)
    $league.players.each do |name, p|
      p.write_safe(res)
    end
    @sente.status = "game"
    @gote.status  = "game"
    @sente.write_safe(sprintf("START:%s:%d\n", @game_id, @kifu.id))
    @gote.write_safe(sprintf("START:%s:%d\n", @game_id, @kifu.id))
    @sente.mytime = @total_time
    @gote.mytime = @total_time
    @start_time = Time::new
    @end_time = @start_time
    @status = "game"
    @board.update_sennichite(@next_player)
  end

  def propose
    @kifu.contents += "V2\n"
    @kifu.contents += "N+#{@sente.name}\n"
    @kifu.contents += "N-#{@gote.name}\n"
    @kifu.contents += "To_Move:#{@board.teban ? '+' : '-'}\n"
    @kifu.contents += "$EVENT:#{@game_id}\n"

    @kifu.contents += "I+#{@sente.provisional? ? '*' : ''}#{@sente.rate.to_i},#{@sente.country_code},#{@sente.exp34}\n"
    @kifu.contents += "I-#{@gote.provisional? ? '*' : ''}#{@gote.rate.to_i},#{@gote.country_code},#{@gote.exp34}\n"

    @sente.write_safe(propose_message("+"))
    @gote.write_safe(propose_message("-"))

    now = Time::new.strftime("%Y/%m/%d %H:%M:%S")
    @kifu.contents += "$START_TIME:#{now}\n"
    @kifu.contents += "#{@board.to_s.chomp}\n"

    if rated?
      black_name = @sente.rated? ? @sente.player_id : @sente.name
      white_name = @gote.rated?  ? @gote.player_id  : @gote.name
      #@fh.puts("'rating:%s:%s" % [black_name, white_name])
      @kifu.contents += "'rating:%s:%s\n" % [black_name, white_name]
    end
    unless @board.initial_moves.empty?
      #@fh.puts "'buoy game starting with %d moves" % [@board.initial_moves.size]
      @kifu.contents +=  "'buoy game starting with %d moves\n" % [@board.initial_moves.size]
      @board.initial_moves.each do |move|
        #@fh.puts move
        #@fh.puts "T1"
        @kifu.contents += "#{move}\n"
        @kifu.contents += "T1\n"
      end
    end
  end

  def to_s
    return sprintf("%s %d %d %d %d %d %s %s %s %d %s",
                   @game_id,
                   @current_turn,
                   @sente.provisional? ? 0 : @sente.rate,
                   @gote.provisional? ? 0 : @gote.rate,
                   @sente.country_code,
                   @gote.country_code,
                   @status == "finished" ? @result.black_result : @status,
                   @sente.game == self,
                   @gote.game == self,
                   @monitors.length,
                   @opening)
  end

  def to_s34
    return sprintf("%s %d %d %d %d %d %s %s %s %d",
                   @game_id,
                   @current_turn,
                   @sente.exp34,
                   @gote.exp34,
                   @sente.country_code,
                   @gote.country_code,
                   @status == "finished" ? @result.black_result : @status,
                   @sente.game == self,
                   @gote.game == self,
                   @monitors.length)
  end

  def show()
    str0 = <<EOM
BEGIN Game_Summary
Protocol_Version:1.1
Protocol_Mode:Server
Format:Shogi 1.0
Declaration:Jishogi 1.1
Game_ID:#{@game_id}
Name+:#{@sente.name}
Name-:#{@gote.name}
Rematch_On_Draw:NO
To_Move:+
BEGIN Time
Time_Unit:1sec
Total_Time:#{@total_time}
Byoyomi:#{@byoyomi}
Least_Time_Per_Move:#{Least_Time_Per_Move}
Remaining_Time+:#{@sente.mytime}
Remaining_Time-:#{@gote.mytime}
Last_Move:#{@last_move}
Current_Turn:#{@current_turn}
END Time
BEGIN Position
EOM

    str1 = <<EOM
END Position
END Game_Summary
EOM

    return str0 + @board.to_s + str1
  end

  def propose_message(sg_flag)
    str = <<EOM
BEGIN Game_Summary
Protocol_Version:1.1
Protocol_Mode:Server
Format:Shogi 1.0
Declaration:Jishogi 1.1
Game_ID:#{@game_id}
Name+:#{@sente.name}
Name-:#{@gote.name}
Your_Turn:#{sg_flag}
Rematch_On_Draw:NO
To_Move:#{@board.teban ? "+" : "-"}
BEGIN Time
Time_Unit:1sec
Total_Time:#{@total_time}
Byoyomi:#{@byoyomi}
Least_Time_Per_Move:#{Least_Time_Per_Move}
END Time
BEGIN Position
#{@board.to_s.chomp}
END Position
END Game_Summary
EOM
    return str
  end

  def prepared_expire?
    if @prepared_time && (@prepared_time + WAITING_EXPIRATION < Time.now)
      return true
    end

    return false
  end
  
  private
  
  def issue_current_time
    time = Time::new.strftime("%Y%m%d%H%M%S").to_i
    @@mutex.synchronize do
      while time <= @@time do
        time += 1
      end
      @@time = time
    end
  end

  def log_cheat(type, sente)
    log_message(sprintf("CHEAT-%s:%s(%s|%s),M%d/%d,%s,%s(%s)", type, 
                                          sente ? @sente.name : @gote.name,
                                          sente ? @sente.latest_ip_address : @gote.latest_ip_address,
                                          sente ? @sente.rate.to_i.to_s : @gote.rate.to_i.to_s,
                                          sente ? @sente_mouse_out : @gote_mouse_out,
                                          @current_turn,
                                          sente ? @result.black_result : @result.gote_result,
                                          sente ? @gote.name : @sente.name,
                                          sente ? @gote.rate.to_i.to_s : @sente.rate.to_i.to_s))
  end 
end


class StudyGame < Game

  def initialize(game_name, sente_name, gote_name, board, moves)
    @monitors = Array::new # array of MonitorHandler*
    @game_name = game_name
    if (@game_name =~ /-(\d+)-(\d+)$/)
      @total_time = $1.to_i
      @byoyomi = $2.to_i + 10
    end

    @sente = DummyPlayer.new({:id => 0, :name => sente_name, :wins => 0, :losses => 0, :rate => 0, :exp34 => 0})
    @sente.country_code = 0
    @sente.sente = true
    @gote = DummyPlayer.new({:id => -1, :name => gote_name, :wins => 0, :losses => 0, :rate => 0, :exp34 => 0})
    @gote.country_code = 0
    @gote.sente = false
    @board = board
    @moves = moves
    if @board.teban
      @current_player, @next_player = @sente, @gote
    else
      @current_player, @next_player = @gote, @sente
    end

    @sente.opponent = @gote
    @gote.opponent = @sente

    @last_move = @board.initial_moves.empty? ? "" : "%s,T1" % [@board.initial_moves.last]
    @current_turn = @board.initial_moves.size

    @game_id = sprintf("STUDY+%s+%s+%s+%s", @game_name, @sente.name, @gote.name, issue_current_time)

    $league.games[@game_id] = self

    @start_time = nil
    @kifu = Kifu.new({:id => 0, :contents => ""})
    @result = nil
    @status = "created"
    @opening = "*"

    propose
    start
  end

  def finish
    log_message(sprintf("study game created %s", @game_id))

    end_time = @result ? @result.end_time : Time.now
    @kifu.contents += "'$END_TIME:#{end_time.strftime("%Y/%m/%d %H:%M:%S")}\n"

    @sente.status = "post_game" if @sente.status = "game"
    @gote.status = "post_game" if @gote.status = "game"

    @current_player = nil
    @next_player = nil
    @status = "finished"
  end

  def start
    @sente.status = "game"
    @gote.status  = "game"
    @sente.mytime = @total_time
    @gote.mytime = @total_time
    @start_time = Time::new
    @end_time = @start_time
    @status = "game"
    @board.update_sennichite(@next_player)
    
    unless (@moves.size == 0)
      @moves.each do |move|
        handle_one_move(move, @current_player, Time.now)
      end
    end
    
    @result = GameResultSuspend.new(self, @current_player, @next_player)
    @result.process
    finish()

    res = sprintf("##[START][%s]\n", @game_id)
    $league.players.each do |name, p|
      p.write_safe(res)
    end
  end
end

end # ShogiServer
