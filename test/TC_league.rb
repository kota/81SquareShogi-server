$:.unshift File.join(File.dirname(__FILE__), "..")
require 'test/unit'
require 'fileutils'
require 'shogi_server'
require 'shogi_server/player'
require 'shogi_server/league'

class TestPersistent < Test::Unit::TestCase
  def setup
    @filename = File.join(".", "test.yaml")
    if File.exists?(@filename)
      FileUtils.rm(@filename)
    end
    @persistent = ShogiServer::League::Persistent.new(@filename)
    @p = ShogiServer::BasicPlayer.new
    @p.name = "gps_normal"
    @p.player_id = "gps_normal_dummy_id"
  end

  def test_empty_yaml
    count = 0
    @persistent.each_group do |group, players|
      count += 1
    end
    assert_equal(count, 0)
    FileUtils.rm(@filename)
    count = 0
    @persistent.each_group do |group, players|
      count += 1
    end
    assert_equal(count, 0)
  end

  def test_load_player
    filename = File.join(".", "players.yaml")
    persistent = ShogiServer::League::Persistent.new(filename)
    p = ShogiServer::BasicPlayer.new
    p.player_id = "gps_normal+e293220e3f8a3e59f79f6b0efffaa931"
    persistent.load_player(p)

    assert_equal(p.name, "gps_normal")
    assert_in_delta(p.rate, -1752.0, 0.1)
    assert_equal(p.modified_at.to_s, "Thu May 08 23:50:54 +0900 2008")
    assert_equal(p.rating_group, 0)
    assert_in_delta(p.win, 3384.04877829976,  0.00001)
    assert_in_delta(p.loss, 906.949084230512, 0.00001)
  end

  def test_get_players
    filename = File.join(".", "players.yaml")
    persistent = ShogiServer::League::Persistent.new(filename)
    players = persistent.get_players
    assert_equal(players.size, 295)
  end
end


class TestLeague < Test::Unit::TestCase
  def setup
    @league = ShogiServer::League.new
    @league.dir = "."
    @league.setup_players_database

    @p = ShogiServer::BasicPlayer.new
    @p.name = "test_name"
  end

  def teardown
  end

  def test_add_player
    assert(!@league.find(@p.name))
    @league.add(@p)
    assert(@league.find(@p.name))
    @league.delete(@p)
    assert(!@league.find(@p.name))
  end

  def test_reload
    @league.reload
    assert(true)
  end
end
