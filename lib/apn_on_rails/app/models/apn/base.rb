require 'mongoid'
require 'active_model'

module APN
  class Base
    class Errors < ActiveModel::Errors
    end

    def self.table_name # :nodoc:
      self.to_s.gsub("::", "_").tableize
    end
  end
end