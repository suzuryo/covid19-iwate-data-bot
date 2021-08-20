# frozen_string_literal: true

TARGET_MIN_ID = 849

SITES = {
  iwate: {
    url: 'https://www.pref.iwate.jp/kurashikankyou/iryou/covid19/1045737/index.html',
    selector: '#voice > table > tbody > tr > td:nth-child(1) a',
    regex: %r{^https://www.pref.iwate.jp}
  },
  morioka: {
    url: 'http://www.city.morioka.iwate.jp/kenkou/kenko/1031971/1032075/1036303/index.html',
    selector: '#voice > ul > li > a',
    regex: %r{^http://www.city.morioka.iwate.jp}
  }
}.freeze

# NotValidUrlError
class NotValidUrlError < StandardError
end

# String
class String
  def iwate?
    !!(SITES[:iwate][:regex].match self)
  end

  def morioka?
    !!(SITES[:morioka][:regex].match self)
  end
end
