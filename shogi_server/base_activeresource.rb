require 'rubygems'
require 'active_resource'
require 'shogi_server/activeresource_config'

module ShogiServer
  class BaseActiveResource < ActiveResource::Base
    self.site = ActiveResourceConfig::RAILS_SITE
    self.prefix = '/api/'
  end
end
