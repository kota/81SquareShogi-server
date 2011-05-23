require 'shogi_server/config'
require 'rubygems'
require 'active_resource'

module ShogiServer # for a namespace

class Kifu < ActiveResource::Base
  self.site = RAILS_SITE
  self.prefix = '/api/'
end # class

end # ShogiServer
