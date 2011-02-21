require 'MeCab'

class Mecab_Parser
  include ::Ferret_Parser

  def initialize(arg)
    @wakati = ::MeCab::Tagger.new('-O wakati')
  end

  def parse(str)
    @wakati.parse(convert_str(str).to_s).strip
  end
end
