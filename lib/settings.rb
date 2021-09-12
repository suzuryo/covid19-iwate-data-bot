# frozen_string_literal: true

TARGET_MIN_ID = 849

SITES = {
  iwate: {
    url: 'https://www.pref.iwate.jp/kurashikankyou/iryou/covid19/1046015/index.html',
    selector: '#voice > table > tbody > tr > td:nth-child(1) a',
    regex: %r{^https://www.pref.iwate.jp}
  },
  morioka: {
    url: 'http://www.city.morioka.iwate.jp/kenkou/kenko/1031971/1032075/1036303/index.html',
    selector: '#voice > ul > li > a',
    regex: %r{^http://www.city.morioka.iwate.jp}
  }
}.freeze

PDFS = {
  iwate: {
    url: 'https://www.pref.iwate.jp/kurashikankyou/iryou/covid19/1046698.html',
    selector: '#voice > ul.objectlink > li.pdf > a',
    url_replace: ['../../../', 'https://www.pref.iwate.jp/'],
    pdf_dir: File.expand_path(File.join(__dir__, '../download/pdf/iwate')),
    csv_dir: File.expand_path(File.join(__dir__, '../download/csv/iwate'))
  },
  morioka: {
    url: 'http://www.city.morioka.iwate.jp/kenkou/kenko/1031971/1032075/1036827.html',
    selector: '#voice > h2 + p + ul.objectlink > li.pdf > a[href$=".pdf"]',
    url_replace: ['../../../../', 'http://www.city.morioka.iwate.jp/'],
    pdf_dir: File.expand_path(File.join(__dir__, '../download/pdf/morioka')),
    csv_dir: File.expand_path(File.join(__dir__, '../download/csv/morioka'))
  }
}

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
