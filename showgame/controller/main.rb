# Default url mappings are:
#  a controller called Main is mapped on the root of the site: /
#  a controller called Something is mapped on: /something
# If you want to override this, add a line like this inside the class
#  map '/otherurl'
# this will force the controller to be mounted on: /otherurl

$:.unshift File.join(__DIR__, "..", "..")
$:.unshift File.join(__DIR__, "..", "gen-rb")

require "shogi_server/piece"
require "shogi_server/board"
require "shogi_server/usi"

require "ShogiGraphic"
require 'thrift/transport/socket'
require 'thrift/protocol/tbinaryprotocol'

$pos2img_out_dir = File.join(".", "public", "images")

class MainController < Ramaze::Controller
  layout '/page'

  # the index action is called automatically when no other action is specified
  def index
    @title = "Welcome to Ramaze!"
  end

  def game(csa_file)
    csa_file.gsub!(" ", "+")
    dir = "/home/daigo/rubyprojects/shogi-server"
    files = Dir.glob(File.join(dir, "**", csa_file))
    if files.empty?
      redirect Rs()
    end
    board = ShogiServer::Board.new
    board.initial
    @moves = Array.new
    teban = true
    usi = ShogiServer::Usi.new
    kifu = File.open(files.first) {|f| f.read}
    kifu.each_line do |line|
      #  Ramaze::Log.warn(line)
      if /^([\+\-])(\d)(\d)(\d)(\d)([A-Z]{2})/ =~ line
        board.handle_one_move(line)
        sfen = usi.board2usi(board, teban)
        sfen = ShogiServer::Usi.escape(sfen)
        @moves << A(h(line), :href => Rs(:sfen, u(sfen)))
        teban = teban ? false : true
      end
    end
  end

  def sfen(str)
    transport = Thrift::BufferedTransport.new(Thrift::Socket.new('localhost', 9090))
    client    = ShogiGraphic::Client.new(Thrift::BinaryProtocol.new(transport))

    transport.open
    result = client.usi2png(str)
    transport.close

    Ramaze::Log.error("Failed to get an image of %s from the Thrift server" % [str]) if !result || result.empty?
    @img = "/images/%s" % [result]
  end

  def images(str)
    file = File.join($pos2img_out_dir, str)
    send_file(file, mime_type = Ramaze::Tool::MIME.type_for(file))
  end

  # the string returned at the end of the function is used as the html body
  # if there is no template for the action. if there is a template, the string
  # is silently ignored
  def notemplate
    "there is no 'notemplate.xhtml' associated with this action"
  end
end
