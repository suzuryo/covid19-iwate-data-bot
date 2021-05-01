# frozen_string_literal: true

require_relative './site/iwate'
require_relative './site/morioka'
require_relative './settings'

module Site2Tsv
  # Site
  class Site
    def initialize(site: nil, id: TARGET_MIN_ID)
      @url = site[:url].to_s
      @selector = site[:selector].to_s
      @id = id.to_i
    end

    def data
      case @url
      when SITES[:iwate][:regex]
        Iwate.new(url: @url, selector: @selector, id: @id).data
      when SITES[:morioka][:regex]
        Morioka.new(url: @url, selector: @selector, id: @id).data
      else
        nil
      end
    end

  end
end

