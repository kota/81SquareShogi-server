require 'shogi_server/command'
require 'rubygems'
require 'active_resource'

module ShogiServer # for a namespace

class Server < ActiveResource::Base
  self.site = RAILS_SITE
  self.prefix = '/api/'
  
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
