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

end # ShogiServer

