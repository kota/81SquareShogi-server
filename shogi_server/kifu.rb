require 'rubygems'
require 'active_resource'

module ShogiServer # for a namespace

class Kifu < ActiveResource::Base
  self.site = 'http://localhost:3000'
  self.prefix = '/api/'
end # class

end # ShogiServer
