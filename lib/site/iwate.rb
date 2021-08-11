# frozen_string_literal: true

# id > 849 に対応

require 'active_support/core_ext/date'
require 'nokogiri'
require 'open-uri'

# SiteIwate
class Iwate
  def initialize(url: nil, selector: nil, id: nil)
    @url = url
    @selector = selector
    @id = id
  end

  def data
    uris.map do |uri|
      parse(uri, doc(uri))
    end
  end

  def uris
    raise NotValidUrlError unless @url.iwate?

    html = URI.parse(@url).open if URI.parse(@url).instance_of?(URI::HTTPS)

    Nokogiri::HTML(html).css(@selector).filter_map do |node|
      # 個別ページへのリンクから id を抽出
      m = /第(?<id>[\d,]+)例目/.match node.text

      # マッチしたものだけを採用
      next unless m

      # 指定 id よりも多いものだけを採用
      next if m[:id].delete(',').to_i < @id

      URI.parse(node.attribute('href').value.delete("\n").rstrip)
    end
  end

  def doc(uri)
    raise NotValidUrlError unless uri.to_s.iwate?

    Nokogiri::HTML(uri.open)
  end

  def parse(uri, doc)
    p uri
    patient = {}

    # id
    patient['id'] = doc.css('#voice > h2').text.match(/第(?<id>[\d,]+)例目[以降]*の患者に関する情報/)[:id].delete(',').to_i

    # リリース日
    m = doc.css('#voice > h2').text.match(/令和3年(?<month>\d+)月(?<day>\d+)日/)
    patient['リリース日'] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''

    # 確定日
    patient['確定日'] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").days_ago(1).strftime('%Y/%m/%d') : ''

    # dl の dt と dd のハッシュ
    dl = doc.css('#voice > dl > dt').map { |v| [v.text, v.next_element.text.strip.gsub("\n", '')] }.to_h

    patient['年代'] = dl['年代'].gsub(' ', '')
    patient['性別'] = dl['性別']

    patient['居住地'] = case dl['居住地']
                     when /県外/
                       patient['滞在地'] = dl['居住地'].split(/滞在地[:：]/)[1].split(/[(（]/)[0].gsub(/[)）[:space:]]/, '').rstrip
                       '県外'
                     else
                       dl['居住地'].split(/[(（]/)[0].gsub(/[)）[:space:]]/, '').rstrip
                     end

    # 1543は 「滝沢市 （県央保健所）」 って書いてあるので滝沢市に固定する
    if patient['id'] == 1543
      patient['居住地'] = '滝沢市'
    end

    patient['職業'] = dl['職業']

    m1 = dl['入院状況'].match(/(?<month>\d+)月(?<day>\d+)日/)
    patient['入院日'] = m1 ? Date.parse("2021/#{m1[:month]}/#{m1[:day]}").strftime('%Y/%m/%d') : ''

    # 無症状の場合は発症日は空
    # 有症状の場合は無症状が空
    if dl['症状'].match(/無症状/)
      # 無症状病原体保有者
      # 無症状性病原体保有者
      # の2種類の表記が存在する
      # 症状が無い場合は発症日が空
      patient['無症状'] = '無症状'
      patient['発症日'] = ''
    else
      # 無症状でない場合
      patient['無症状'] = ''
      m2 = dl['発症日'].match(/(?<month>\d+)月(?<day>\d+)日/)
      patient['発症日'] = m2 ? Date.parse("2021/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
    end

    patient['接触歴'] = dl['備考'].blank? || dl['備考'] == 'なし' ? '不明' : '判明'

    # url
    patient['url'] = uri.to_s

    patient['morioka_id'] = nil

    patient
  end
end
