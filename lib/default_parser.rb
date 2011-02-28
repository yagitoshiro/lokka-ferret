require 'kana'
module Ferret_Parser
  attr_accessor :index

  def parse(str); str; end

  def convert_str(str) # justify width of multibyte chars
    ::Kana.kana(str, "nrKsa")
  end

  def parse_query(str)
    str.to_s.gsub(/ /, '|')
  end
end

class Default_Parser
  include Ferret_Parser
  def initialize(arg); arg; end
end
