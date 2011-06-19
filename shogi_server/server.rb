require 'shogi_server/base_activeresource'

module ShogiServer # for a namespace

class Server < ShogiServer::BaseActiveResource 
  
  def start_log
    self.started_at = Time.now
    self.maintenance_at = nil
    write_population(0)
  end
  
  def write_population(n)
    self.population = n
    save
  end

end # class

end # ShogiServer
