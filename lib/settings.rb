# frozen_string_literal: true

TARGET_MIN_ID = 4205

PDFS = {
  iwate: {
    url: 'https://www.pref.iwate.jp/kurashikankyou/iryou/covid19/1050899/1050487.html',
    selector: '#voice > ul.objectlink:nth-child(9) > li.pdf > a',
    url_replace: ['../../../../', 'https://www.pref.iwate.jp/'],
    pdf_dir: File.expand_path(File.join(__dir__, '../download/pdf/iwate')),
    csv_dir: File.expand_path(File.join(__dir__, '../download/csv/iwate'))
  },
  morioka: {
    url: 'https://www.city.morioka.iwate.jp/corona/1032075/1036827.html',
    selector: '#voice > h2 + p + ul.objectlink > li.pdf > a[href$=".pdf"]',
    url_replace: ['../../', 'https://www.city.morioka.iwate.jp/'],
    pdf_dir: File.expand_path(File.join(__dir__, '../download/pdf/morioka')),
    csv_dir: File.expand_path(File.join(__dir__, '../download/csv/morioka'))
  }
}.freeze
