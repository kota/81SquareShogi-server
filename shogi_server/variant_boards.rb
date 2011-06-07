## Extended functionality of 81-Dojo

require 'shogi_server/board'
require 'shogi_server/variant_pieces'

module ShogiServer # for a namespace

# Board for Mini-shogi.
#
class VAMINIBoard < Board
  def initial
    @gote_ou = Piece55OU::new(self, 3, 3, false)
    PieceKI::new(self, 4, 3, false)
    PieceGI::new(self, 5, 3, false)
    PieceKA::new(self, 6, 3, false)
    PieceHI::new(self, 7, 3, false)
    Piece55FU::new(self, 3, 4, false)

    @sente_ou = Piece55OU::new(self, 7, 7, true)
    PieceKI::new(self, 6, 7, true)
    PieceGI::new(self, 5, 7, true)
    PieceKA::new(self, 4, 7, true)
    PieceHI::new(self, 3, 7, true)
    Piece55FU::new(self, 7, 6, true)

    @teban = true
    @gote_base_point = 0
  end
end

# Board for GoroGoro-shogi.
#
class VA5656Board < Board
  def initial
    @gote_ou = Piece56OU::new(self, 5, 3, false)
    PieceKI::new(self, 4, 3, false)
    PieceKI::new(self, 6, 3, false)
    PieceGI::new(self, 3, 3, false)
    PieceGI::new(self, 7, 3, false)
    Piece56FU::new(self, 4, 5, false)
    Piece56FU::new(self, 5, 5, false)
    Piece56FU::new(self, 6, 5, false)

    @sente_ou = Piece56OU::new(self, 5, 8, true)
    PieceKI::new(self, 4, 8, true)
    PieceKI::new(self, 6, 8, true)
    PieceGI::new(self, 3, 8, true)
    PieceGI::new(self, 7, 8, true)
    Piece56FU::new(self, 4, 6, true)
    Piece56FU::new(self, 5, 6, true)
    Piece56FU::new(self, 6, 6, true)

    @teban = true
    @gote_base_point = 0
  end
end

# Board for Dobutsu-shogi.
#
class VAZOOBoard < Board
  def initial
    @gote_ou = PieceOU::new(self, 8, 1, false)
    PieceZE::new(self, 7, 1, false)
    PieceZG::new(self, 9, 1, false)
    PieceZC::new(self, 8, 2, false)

    @sente_ou = PieceOU::new(self, 8, 4, true)
    PieceZG::new(self, 7, 4, true)
    PieceZE::new(self, 9, 4, true)
    PieceZC::new(self, 8, 3, true)

    @teban = true
    @gote_base_point = 0
  end
  
  def handle_one_move(str, sente=nil)
    if (str =~ /^([\+\-])(\d)(\d)(\d)(\d)([A-Z]{2})/)
      sg = $1
      x0 = $2.to_i
      y0 = $3.to_i
      x1 = $4.to_i
      y1 = $5.to_i
      name = $6
    elsif (str =~ /^%TORYO/)
      return :toryo
    else
      return :illegal
    end
    
    if (((x0 == 0) || (y0 == 0)) && # source is not from hand
        ((x0 != 0) || (y0 != 0)))
      return :illegal
    elsif ((x1 == 0) || (y1 == 0)) # destination is out of board
      return :illegal
    end
    
    if (sg == "+")
      sente = true if sente == nil           # deprecated
      return :illegal unless sente == true   # black player's move must be black
      hands = @sente_hands
    else
      sente = false if sente == nil          # deprecated
      return :illegal unless sente == false  # white player's move must be white
      hands = @gote_hands
    end
    
    ## source check
    if ((x0 == 0) && (y0 == 0))
      return :illegal if (! have_piece?(hands, name))
    elsif (! @array[x0][y0])
      return :illegal           # no piece
    elsif (@array[x0][y0].sente != sente)
      return :illegal           # this is not mine
    elsif (@array[x0][y0].name != name)
      return :illegal if (@array[x0][y0].promoted_name != name) # can't promote
    end

    ## destination check
    if (@array[x1][y1] &&
        (@array[x1][y1].sente == sente)) # can't capture mine
      return :illegal
    elsif ((x0 == 0) && (y0 == 0) && @array[x1][y1])
      return :illegal           # can't put on existing piece
    end

    tmp_board = deep_copy
    move_result = tmp_board.move_to(x0, y0, x1, y1, name, sente)
    return :illegal if (move_result == :illegal)
    return :outori if (move_result == :outori)
    return :try_lose if (tmp_board.his_try?(sente))
    return :try_win if (tmp_board.safe_try?(sente))
    tmp_board.update_sennichite(sente)
#    os_result = tmp_board.oute_sennichite?(sente)
#    return os_result if os_result # :oute_sennichite_sente_lose or :oute_sennichite_gote_lose
    return :sennichite if tmp_board.sennichite?

    move_to(x0, y0, x1, y1, name, sente)

    update_sennichite(sente)
    return :normal
  end
  
  def sennichite?
    if (@history[to_s] >= 3) # already 2 times
      return true
    end
    return false
  end
  
  def his_try?(sente)        # sente is loosing
    if (sente)
      return true if (@gote_ou.y == 4)
    else
      return true if (@sente_ou.y == 1)
    end
    return false
  end
  
  def safe_try?(sente)        # sente is winning
    return false if (checkmated?(sente))
    if (sente)
      return true if (@sente_ou.y == 1)
    else
      return true if (@gote_ou.y == 4)
    end
    return false
  end
end

end # ShogiServer

