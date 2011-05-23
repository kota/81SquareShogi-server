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

require 'shogi_server/handicapped_boards'
require 'shogi_server/variant_boards'

module ShogiServer # for a namespace

######################################################
# Processes the LOGIN command.
#
class Login
  def Login.good_login?(str)
    tokens = str.split
    if (((tokens.length == 3) || 
        ((tokens.length == 4) && tokens[3] == "x1")) &&
        (tokens[0] == "LOGIN") &&
        (good_identifier?(tokens[1])))
      return true
    else
      return false
    end
  end

  def Login.good_game_name?(str)
    if ((str =~ /^(.+)-\d+-\d+$/) && (good_identifier?($1)))
      return true
    else
      return false
    end
  end

  # Check if a game name str is a handicapped game.
  # @return a subclass of Board coresponding to the handicapped game; false,
  # otherwise.
  #
  def Login.handicapped_game_name?(str)
    return false unless good_game_name?(str)
    ret = nil
    
    case str
    when %r!^hclance_!
      ret = HCKYBoard
    when %r!^hcbishop_!
      ret = HCKABoard
    when %r!^hcrook_!
      ret = HCHIBoard
    when %r!^hcrooklance_!
      ret = HCHIKYBoard
    when %r!^hcrooksilver_!
      ret = HCHIGIBoard
    when %r!^hc2p_!
      ret = HC2PBoard
    when %r!^hc4p_!
      ret = HC4PBoard
    when %r!^hc6p_!
      ret = HC6PBoard
    when %r!^hc8p_!
      ret = HC8PBoard
    when %r!^hc10p_!
      ret = HC10PBoard
    when %r!^hctombo_!
      ret = HCTOMBOBoard
    when %r!^hcfu3_!
      ret = HCFU3Board
    when %r!^hcnaked_!
      ret = HCNAKEDBoard
    when %r!^vamini_!
      ret = VAMINIBoard
    when %r!^va5656_!
      ret = VA5656Board
    when %r!^vazoo_!
      ret = VAZOOBoard
    else
      ret = false
    end
    return ret
  end

  def Login.good_identifier?(str)
    if str =~ /\A[\w\d_@\-\.]{1,#{Max_Identifier_Length}}\z/
      return true
    else
      return false
    end
  end

  def Login.factory(str, player)
    (login, player.name, password, ext) = str.chomp.split
    if ext
      return Loginx1.new(player, password)
    else
      return LoginCSA.new(player, password)
    end
  end

  attr_reader :player
  
  # the first command that will be executed just after LOGIN.
  # If it is nil, the default process will be started.
  attr_reader :csa_1st_str

  def initialize(player, password)
    @player = player
    @csa_1st_str = nil
    parse_password(password)
  end

  def process
    @player.write_safe(sprintf("LOGIN:%s:%d:%d:%d:%d:%d:%d:%d:%d OK\n",
                               @player.name, @player.rate, @player.country_code,
                               @player.wins, @player.losses, @player.streak, @player.streak_best,
                               @player.wins34, @player.losses34))
    log_message(sprintf("user %s run in %s mode", @player.name, @player.protocol))
    @player.update_ip_address(@player.socket.peeraddr[2])
  end

  def incorrect_duplicated_player(str)
    @player.write_safe("LOGIN:incorrect\n")
    @player.write_safe(sprintf("username %s is already connected\n", @player.name)) if (str.split.length >= 4)
    sleep 3 # wait for sending the above messages.
    @player.name = "%s [duplicated]" % [@player.name]
    @player.finish
  end
end

######################################################
# Processes LOGIN for the CSA standard mode.
#
class LoginCSA < Login
  PROTOCOL = "CSA"

  def initialize(player, password)
    @gamename = nil
    super
    @player.protocol = PROTOCOL
  end

  def parse_password(password)
    if Login.good_game_name?(password)
      @gamename = password
      @player.set_password(nil)
    elsif password.split(",").size > 1
      @gamename, *trip = password.split(",")
      @player.set_password(trip.join(","))
    else
      @player.set_password(password)
      @gamename = Default_Game_Name
    end
    @gamename = self.class.good_game_name?(@gamename) ? @gamename : Default_Game_Name
  end

  def process
    super
    @csa_1st_str = "%%GAME #{@gamename} *"
  end
end

######################################################
# Processes LOGIN for the extented mode.
#
class Loginx1 < Login
  PROTOCOL = "x1"

  def initialize(player, password)
    super
    @player.protocol = PROTOCOL
  end
  
  def parse_password(password)
    @player.set_password(password)
  end

  def process
    super
    @player.write_safe(sprintf("##[LOGIN] +OK %s\n", PROTOCOL))
    res = sprintf("##[LOBBY_IN]%s,%d,%s,%d,%d,%d,%d,%d\n", @player.name, @player.rate, @player.provisional?, @player.country_code,
                                                        @player.wins, @player.losses, @player.streak, @player.streak_best)
    $league.players.each do |name, p|
      p.write_safe(res)
    end
    if ($offline_message.include?(@player.name.downcase))
      $offline_message[@player.name.downcase].chomp.split("\n").each do |line|
        @player.write_safe("##[OFFLINE_PM]%s\n" % [line.chomp])
      end
      @player.write_safe("##[OFFLINE_PM] +OK\n")
      $offline_message.delete(@player.name.downcase)
    end
  end
end

end # ShogiServer
