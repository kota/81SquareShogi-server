## Extended functionality of 81-Dojo

require 'shogi_server/piece'

module ShogiServer # for a namespace

class Piece55FU < Piece
  def initialize(*arg)
    @point = 1
    @normal_moves = [[0, +1]]
    @promoted_moves = [[0, +1], [+1, +1], [-1, +1], [+1, +0], [-1, +0], [0, -1]]
    @name = "FU"
    @promoted_name = "TO"
    super
  end
  def room_of_head?(x, y, name)
    if (name == "FU")
      if (@sente)
        return false if (y <= 3)
      else
        return false if (y >= 7)
      end
      ## 2fu check
      c = 0
      iy = 1
      while (iy <= 9)
        if ((iy  != @y) &&      # not source position
            @board.array[x][iy] &&
            (@board.array[x][iy].sente == @sente) && # mine
            (@board.array[x][iy].name == "FU") &&
            (@board.array[x][iy].promoted == false))
          return false
        end
        iy = iy + 1
      end
    end
    return true
  end
end

class Piece55OU < Piece
  def initialize(*arg)
    @point = 0
    @normal_moves = [[0, +1], [+1, +1], [-1, +1], [+1, +0], [-1, +0], [0, -1], [+1, -1], [-1, -1]]
    @promoted_moves = []
    @name = "OU"
    @promoted_name = nil
    super
  end

  def jump_to?(x, y)
    if ((3 <= x) && (x <= 7) && (3 <= y) && (y <= 7))
      if ((@board.array[x][y] == nil) || # dst is empty
          (@board.array[x][y].sente != @sente)) # dst is enemy
        return true
      end
    end
    return false
  end
end

end # ShogiServer
