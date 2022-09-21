#!/usr/bin/env ruby
# frozen_string_literal: true

# 予測ツール
# https://github.com/yukifuruse1217/COVIDhealthBurden
# 医療需要予測ツール_オミクロンとブースター考慮版v3_20220103.xlsx
# の計算をrubyで実装。

def health_burden_json(patients_summary, positive_rate, hospitalized_numbers, now)

  patients_data_archived = JSON.parse(File.read(File.join(__dir__, '../../data_archived/data.json')))['patients']['data']

  # 直近１週間の陽性者data
  last7days_archived = patients_data_archived.select { |d| Date.parse(d['確定日']) > Date.parse(LAST_DATE).days_ago(7) }
  last7days = patients_summary.select { |d| Date.parse(d['date']) > Date.parse(LAST_DATE).days_ago(7) }


  ages = {
    s00: '10歳未満',
    s10: '10歳台',
    s20: '20歳台',
    s30: '30歳台',
    s40: '40歳台',
    s50: '50歳台',
    s60: '60歳台',
    s70: '70歳台以上'
  }

  b3 = {
    s00: (Rational(last7days_archived.select { |d| ['10歳未満'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['10歳未満'].to_i }.to_s)) / Rational('7'),
    s10: (Rational(last7days_archived.select { |d| ['10代'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['10代'].to_i }.to_s)) / Rational('7'),
    s20: (Rational(last7days_archived.select { |d| ['20代'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['20代'].to_i }.to_s)) / Rational('7'),
    s30: (Rational(last7days_archived.select { |d| ['30代'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['30代'].to_i }.to_s)) / Rational('7'),
    s40: (Rational(last7days_archived.select { |d| ['40代'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['40代'].to_i }.to_s)) / Rational('7'),
    s50: (Rational(last7days_archived.select { |d| ['50代'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['50代'].to_i }.to_s)) / Rational('7'),
    s60: (Rational(last7days_archived.select { |d| ['60代'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['60代'].to_i }.to_s)) / Rational('7'),
    s70: (Rational(last7days_archived.select { |d| ['70代', '80代', '90歳以上'].include? d['年代'] }.size.to_s) + Rational(last7days.reduce(0) { |sum, d| sum + d['70代'].to_i + d['80代'].to_i + d['90歳以上'].to_i }.to_s)) / Rational('7'),
  }

  # 接種率の資料
  # https://www.kantei.go.jp/jp/headline/kansensho/vaccine.html

  # ワクチン２回接種率（％） ※３回接種者を含む
  b4 = {
    s00: Rational('0'),
    s10: Rational('84.8'),
    s20: Rational('85.9'),
    s30: Rational('83.3'),
    s40: Rational('87.0'),
    s50: Rational('91.8'),
    s60: (Rational('91.4') + Rational('89.2')) / Rational('2'),
    s70: (Rational('98.0') + Rational('95.5') + Rational('101.9') + Rational('103.3')) / Rational('4')
  }

  # ワクチン３回接種率（％）
  b5 = {
    s00: Rational('0'),
    s10: Rational('50.1'),
    s20: Rational('58.0'),
    s30: Rational('60.0'),
    s40: Rational('69.3'),
    s50: Rational('81.4'),
    s60: (Rational('86.1') + Rational('86.3')) / Rational('2'),
    s70: (Rational('95.3') + Rational('92.2') + Rational('97.3') + Rational('96.0')) / Rational('4')
  }

  # デルタ株：（ワクチンなしで）酸素投与を要する率（％）
  b7 = {
    s00: Rational('1'),
    s10: Rational('1'),
    s20: Rational('1.5'),
    s30: Rational('5'),
    s40: Rational('10'),
    s50: Rational('15'),
    s60: Rational('25'),
    s70: Rational('30')
  }

  # デルタ株：（ワクチンなしの）重症化率（％）
  b10 = {
    s00: Rational('0.1'),
    s10: Rational('0.1'),
    s20: Rational('0.1'),
    s30: Rational('0.6'),
    s40: Rational('1.5'),
    s50: Rational('4'),
    s60: Rational('8'),
    s70: Rational('11')
  }

  # デルタ株と比べたときの流行株の重症化率（％）
  b14 = Rational('60')

  # 中等症の入院期間（日数）
  b18 = {
    s00: Rational('9'),
    s10: Rational('9'),
    s20: Rational('9'),
    s30: Rational('9'),
    s40: Rational('9'),
    s50: Rational('10'),
    s60: Rational('11'),
    s70: Rational('14')
  }

  # 重症者の入院期間（重症病床を占有していないときも含む日数）
  b21 = {
    s00: Rational('14'),
    s10: Rational('14'),
    s20: Rational('14'),
    s30: Rational('14'),
    s40: Rational('14'),
    s50: Rational('15'),
    s60: Rational('17'),
    s70: Rational('20')
  }

  # 検査陽性者数の今週/先週比
  b24 = Rational(positive_rate[-7..].reduce(0) { |a, v| a + v['positive_count'].to_i }) / Rational(positive_rate[-14..-8].reduce(0) { |a, v| a + v['positive_count'].to_i })

  # 現在の重症者数
  b28 = Rational(hospitalized_numbers[-1]['重症'].to_s)

  # 現在の全療養者数
  b29 = Rational(hospitalized_numbers[-1]['入院']) + Rational(hospitalized_numbers[-1]['宿泊療養']) + Rational(hospitalized_numbers[-1]['自宅療養']) + Rational(hospitalized_numbers[-1]['調整中'])

  # 現在の酸素投与を要する人の数（重症者を含む）
  # 岩手県は酸素投与が必要な中等症1,2の数を公表していない。
  # 第47回本部員会議の資料で、オミクロンの現在、中等症(1なの2なの)が1.3%という資料が出た。
  # つまり、76人の入院患者に対して中等症は1人ということ。
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220123_01_3.pdf
  #
  # 第48回本部員会議の資料で、中等症(1なの2なの?)が 2.3% という資料が出た。
  # つまり、177 人の入院患者に対して中等症は 4 人ということ。
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220201_01_3.pdf
  #
  # 第49回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/1/15 - 2022/1/31 の 246 例について 4.1% という資料が出た。
  # つまり、246 人の入院患者に対して中等症は 10 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220218_01_3.pdf
  #
  # 第49回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/2/1 - 2022/2/16 の 353 例について 9.7% という資料が出た。
  # つまり、353 人の入院患者に対して中等症は 34 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220218_01_3.pdf
  #
  # 第50回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/2/10 - 2022/2/16 の 140 例について 13.5% という資料が出た。
  # つまり、140 人の入院患者に対して中等症は 19 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220225_01_2.pdf
  #
  # 第50回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/2/17 - 2022/2/23 の 141 例について 9.2% という資料が出た。
  # つまり、141 人の入院患者に対して中等症は 13 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220225_01_2.pdf
  #
  # 第51回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/2/24 - 2022/3/2 の 115 例について 5.2% という資料が出た。
  # つまり、141 人の入院患者に対して中等症は 6 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220304_01_3.pdf
  #
  # 第52回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/3/3 - 2022/3/9 の 130 例について 9.2% という資料が出た。
  # つまり、130 人の入院患者に対して中等症は 12 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220318_01_3.pdf
  #
  # 第52回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/3/10 - 2022/3/16 の 111 例について 2.7% という資料が出た。
  # つまり、111 人の入院患者に対して中等症は 3 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220318_01_3.pdf
  #
  # 第53回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/3/12 - 2022/3/18 の 124 例について 7.3% という資料が出た。
  # つまり、124 人の入院患者に対して中等症は 9 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220329_01_3.pdf
  #
  # 第53回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/3/19 - 2022/3/25 の 74 例について 9.5% という資料が出た。
  # つまり、74 人の入院患者に対して中等症は 7 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220329_01_3.pdf
  #
  # 第54回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/3/24 - 2022/3/30 の 74 例について 9.5% という資料が出た。
  # つまり、74 人の入院患者に対して中等症は 7 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220408_01_4.pdf
  #
  # 第54回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/3/31 - 2022/4/06 の 61 例について 3.3% という資料が出た。
  # つまり、61 人の入院患者に対して中等症は 2 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220408_01_4.pdf
  #
  # 第55回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/4/12 - 2022/4/18 の 63 例について 6.3% という資料が出た。
  # つまり、63 人の入院患者に対して中等症は 4 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220428_01_3.pdf
  #
  # 第55回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/4/19 - 2022/4/25 の 60 例について 0.0% という資料が出た。
  # つまり、60 人の入院患者に対して中等症は 0 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220428_01_3.pdf
  #
  # 第56回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/4/26 - 2022/5/2 の 30 例について 6.7% という資料が出た。
  # つまり、30 人の入院患者に対して中等症は 2 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220513_02_2.pdf
  #
  # 第56回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/5/3 - 2022/5/9 の 44 例について 15.9% という資料が出た。
  # つまり、44 人の入院患者に対して中等症は 7 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220513_02_2.pdf
  #
  # 第57回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/5/12 - 2022/5/18 の 34 例について 11.8% という資料が出た。
  # つまり、34 人の入院患者に対して中等症は 4 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220530_01_3.pdf
  #
  # 第57回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/5/19 - 2022/5/25 の 56 例について 17.9% という資料が出た。
  # つまり、56 人の入院患者に対して中等症は 10 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220530_01_3.pdf
  #
  # 第58回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/6/1 - 2022/7/6 の 119 例について 17% という資料が出た。
  # つまり、119 人の入院患者に対して中等症は 20 人ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220708_01_3.pdf
  #
  # 第59回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/7/7 - 2022/7/13 の 62 例について 5 人 という資料が出た。
  # つまり、8.0 % ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220714_01_4.pdf
  #
  # 第60回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/7/8 - 2022/7/14 の 48 例について 4 人 という資料が出た。
  # つまり、8.3 % ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220722_01_3.pdf
  #
  # 第60回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/7/15 - 2022/7/21 の 93 例について 6 人 という資料が出た。
  # つまり、6.4 % ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220722_01_3.pdf
  #
  # 第61回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/7/25 - 2022/8/7 の 209 例について 34 人 という資料が出た。
  # つまり、16.3 % ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220809_01_3.pdf
  #
  # 第62回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/8/1 - 2022/8/29 の 274 例について 39 人 という資料が出た。
  # つまり、14.2 % ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220831_01_02.pdf
  #
  # 第63回本部員会議の資料で、中等症(1なの2なの?)が
  # 2022/9/1 - 2022/9/19 の 100 例について 27 人 という資料が出た。
  # つまり、27.0 % ということ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220921_01_3.pdf
  #
  # 第50回本部員会議の資料で、酸素投与を受けた患者が 8.5 % という数字が出ている
  # ただしオミクロン前のデータ
  # https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220225_04_2.pdf
  #
  # NIIDの資料では、2022/01/17の時点では、中等症1が1.1%、中等症2が0.4%
  # 40.6 が不明に割り振られているので分かっている分で計算すると、中等症2は (0.4) / (1.1 + 0.4 + 58.1) * 100 = 0.67 %
  # https://www.mhlw.go.jp/content/10900000/000884972.pdf#page=86
  #
  # 先行した沖縄県のデータでは
  # https://www.mhlw.go.jp/content/10900000/000877245.pdf#page=8
  # 2022/01/04時点では 中等症2は3.7%となっている。(NIIDより多い)
  #
  # NIIDの 0.67 % を採用して、全療養者数から中等症2の数を算出しておく。
  b27 = (b29 * Rational('0.67') / Rational('100')) + b28

  # ２回接種：感染予防
  b32 = Rational('30')

  # ２回接種：入院・重症化予防
  b33 = Rational('70')

  # ３回接種：感染予防
  b34 = Rational('60')

  # ３回接種：入院・重症化予防
  b35 = Rational('85')

  # 血中酸素濃度低下の前に治療薬の投与を受けられる割合（％）
  b39 = Rational('0')

  # 酸素需要を避けられる効果（％）
  b40 = Rational('70')

  # シナリオ変数
  c44 = Rational('5')

  # exp B
  b45 = Rational((b24**Rational('1', '7')).to_s)

  # exp C
  c45 = if c44 == Rational('5')
          b45
        elsif c44 == Rational('6')
          Rational('1')
        elsif c44 == Rational('7')
          Rational((Rational('0.85')**Rational('1', '5')).to_s)
        end

  # ２回感染→入院ワクチン
  b48 = Rational((Rational('1') - (b33 / Rational('100'))), (Rational('1') - (b32 / Rational('100'))))

  # ３回感染→入院ワクチン
  b49 = Rational((Rational('1') - (b35 / Rational('100'))), (Rational('1') - (b34 / Rational('100'))))

  # ワクチン２回
  b52 = ages.keys.to_h { |k| [k, Rational((b4[k] - b5[k]) / Rational('100'))] }

  # ワクチン３回
  b53 = ages.keys.to_h { |k| [k, Rational(b5[k] / Rational('100'))] }

  # ワクチン０回
  b51 = ages.keys.to_h { |k| [k, Rational(Rational('1') - b52[k] - b53[k])] }

  # sensitive0
  b55 = b51

  # sensitive2
  b56 = ages.keys.to_h { |k| [k, Rational(b52[k] * (Rational('1') - (b32 / Rational('100'))))] }

  # sensitive3
  b57 = ages.keys.to_h { |k| [k, Rational(b53[k] * (Rational('1') - (b34 / Rational('100'))))] }

  # sensitiveSum
  b59 = ages.keys.to_h { |k| [k, Rational(b55[k] + b56[k] + b57[k])] }

  # オリジナル中等症（入院必要）率
  b61 = ages.keys.to_h { |k| [k, Rational((b7[k] / Rational('100')) * (b14 / Rational('100')))] }

  # ＋ワクチン効果の入院率
  b64 = ages.keys.to_h do |k|
    [k, Rational(
      ((b55[k] / b59[k]) * b61[k]) +
        ((b56[k] / b59[k]) * b61[k] * b48) +
        ((b57[k] / b59[k]) * b61[k] * b49)
    )]
  end

  # ＋治療薬
  b65 = ages.keys.to_h { |k| [k, Rational(b64[k] * (Rational('1') - (b39 / Rational('100' * b40) / Rational('100'))))] }

  # オリジナル重症率
  b67 = ages.keys.to_h { |k| [k, Rational(((b10[k] / Rational('100')) * b14) / Rational('100'))] }

  # オリジナル重症/オリジナル入院
  b68 = ages.keys.to_h { |k| [k, b61[k] == Rational('0') ? Rational('0') : Rational(b67[k] / b61[k])] }

  # modify重症
  b69 = ages.keys.to_h { |k| [k, Rational(b68[k] * b65[k])] }

  # deltaCheck
  b72 = {
    s00: Rational('1'),
    s10: Rational('1'),
    s20: Rational('1'),
    s30: Rational('1'),
    s40: Rational('1'),
    s50: Rational('2'),
    s60: Rational('3'),
    s70: Rational('4')
  }

  # delta1-div3
  b74 = ages.keys.to_h { |k| [k, Rational(b18[k] / Rational('3'))] }

  #  delta2-div3
  b75 = ages.keys.to_h { |k| [k, Rational((b21[k] - b18[k]) / Rational('3'))] }

  # I
  _m98 = [ages.keys.to_h { |k| [k, b3[k]] }]
  (0...60).each do |i|
    _m98.push(
      ages.keys.to_h { |k| [k, Rational(_m98[i][k] * b45)] }
    )
  end
  m98 = _m98

  # Ha
  _v98 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: ((b27 - ((b28 * Rational('2')) / Rational('3'))) / Rational('9')) * Rational('4'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _v98.push(
      ages.keys.to_h do |k|
        ha = Rational(_v98[i][k] + (m98[i][k] * b65[k]) - (_v98[i][k] / b74[k]))
        [k, ha < Rational('0') ? Rational('0') : ha]
      end
    )
  end
  v98 = _v98

  # Hb
  _ae98 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: ((b27 - ((b28 * Rational('2')) / Rational('3'))) / Rational('9')) * Rational('3'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _ae98.push(
      ages.keys.to_h do |k|
        hb = _ae98[i][k] + (v98[i][k] / b74[k]) - (_ae98[i][k] / b74[k])
        [k, hb < Rational('0') ? Rational('0') : hb]
      end
    )
  end
  ae98 = _ae98

  # HcH
  _an160 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (Rational('2') * (b27 - (b28 * Rational('2') / Rational('3'))) / Rational('9')) - (Rational('6') * b28 / Rational('18')),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _an160.push(
      ages.keys.to_h do |k|
        hch = _an160[i][k] + ((ae98[i][k] / b74[k]) * (Rational('1') - b68[k])) - (_an160[i][k] / b74[k])
        [k, hch < Rational('0') ? Rational('0') : hch]
      end
    )
  end
  an160 = _an160

  # HcD
  _an222 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b28 / Rational('18')) * Rational('6'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _an222.push(
      ages.keys.to_h do |k|
        hcd = _an222[i][k] + ((ae98[i][k] / b74[k]) * b68[k]) - (_an222[i][k] / b74[k])
        [k, hcd < Rational('0') ? Rational('0') : hcd]
      end
    )
  end
  an222 = _an222

  # Da
  _aw98 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b28 / Rational('18')) * Rational('5'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _aw98.push(
      ages.keys.to_h do |k|
        da = _aw98[i][k] + (an222[i][k] / b74[k]) - (_aw98[i][k] / b75[k])
        [k, da < Rational('0') ? Rational('0') : da]
      end
    )
  end
  aw98 = _aw98

  # Db
  _bf98 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b28 / Rational('18')) * Rational('4'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _bf98.push(
      ages.keys.to_h do |k|
        db = _bf98[i][k] + (aw98[i][k] / b75[k]) - (_bf98[i][k] / b75[k])
        [k, db < Rational('0') ? Rational('0') : db]
      end
    )
  end
  bf98 = _bf98

  # Dc
  _bo98 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b28 / Rational('18')) * Rational('3'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _bo98.push(
      ages.keys.to_h do |k|
        dc = _bo98[i][k] + (bf98[i][k] / b75[k]) - (_bo98[i][k] / b75[k])
        [k, dc < Rational('0') ? Rational('0') : dc]
      end
    )
  end
  bo98 = _bo98

  # 新規陽性者数
  b98 = (0...61).map do |i|
    m98[i].merge({ sum: m98[i].values.reduce(:+) })
  end

  # 酸素需要を要する人（重症者を含む）
  b163 = (0...61).map do |i|
    a = ages.keys.to_h do |k|
      [k, v98[i][k] + ae98[i][k] + an160[i][k] + aw98[i][k] + bf98[i][k] + bo98[i][k] + an222[i][k]]
    end
    a.merge({ sum: a.values.reduce(:+) })
  end

  # 重症病床を要する人
  b228 = (0...61).map do |i|
    a = ages.keys.to_h do |k|
      [k, aw98[i][k] + bf98[i][k] + bo98[i][k] + an222[i][k]]
    end
    a.merge({ sum: a.values.reduce(:+) })
  end

  # All
  m293 = m98

  # RestA
  _v293 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b29 - b28 - b27) / Rational('30') * Rational('8'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _v293.push(
      ages.keys.to_h do |k|
        a = _v293[i][k] + (m293[i][k] * (Rational('1') - b65[k])) - (_v293[i][k] / Rational('2'))
        [k, a < Rational('0') ? Rational('0') : a]
      end
    )
  end
  v293 = _v293

  # RestB
  _ae293 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b29 - b28 - b27) / Rational('30') * Rational('7'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _ae293.push(
      ages.keys.to_h do |k|
        a = _ae293[i][k] + (v293[i][k] / Rational('2')) - (_ae293[i][k] / Rational('2'))
        [k, a < Rational('0') ? Rational('0') : a]
      end
    )
  end
  ae293 = _ae293

  # RestC
  _an293 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b29 - b28 - b27) / Rational('30') * Rational('6'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _an293.push(
      ages.keys.to_h do |k|
        a = _an293[i][k] + (ae293[i][k] / Rational('2')) - (_an293[i][k] / Rational('2'))
        [k, a < Rational('0') ? Rational('0') : a]
      end
    )
  end
  an293 = _an293

  # RestD
  _aw293 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b29 - b28 - b27) / Rational('30') * Rational('5'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _aw293.push(
      ages.keys.to_h do |k|
        a = _aw293[i][k] + (an293[i][k] / Rational('2')) - (_aw293[i][k] / Rational('2'))
        [k, a < Rational('0') ? Rational('0') : a]
      end
    )
  end
  aw293 = _aw293

  # RestE
  _bf293 = [
    {
      s00: Rational('0'),
      s10: Rational('0'),
      s20: Rational('0'),
      s30: Rational('0'),
      s40: Rational('0'),
      s50: (b29 - b28 - b27) / Rational('30') * Rational('4'),
      s60: Rational('0'),
      s70: Rational('0')
    }
  ]
  (0...60).each do |i|
    _bf293.push(
      ages.keys.to_h do |k|
        a = _bf293[i][k] + (aw293[i][k] / Rational('2')) - (_bf293[i][k] / Rational('2'))
        [k, a < Rational('0') ? Rational('0') : a]
      end
    )
  end
  bf293 = _bf293

  # 全療養者
  b293 = (0...61).map do |i|
    a = ages.keys.to_h do |k|
      [k, v293[i][k] + ae293[i][k] + an293[i][k] + aw293[i][k] + bf293[i][k] + b163[i][k]]
    end
    a.merge({ sum: a.values.reduce(:+) })
  end

  ################################################################################
  # シミュレーション結果
  ################################################################################

  # 酸素投与を要する人（重症者を含む）
  c79 = {
    week1: b163[4][:sum],
    week2: b163[11][:sum],
    week3: b163[18][:sum],
    week4: b163[25][:sum]
  }

  # 重症者（＝必要と思われる重症病床の確保数）
  h79 = {
    week1: b228[4][:sum],
    week2: b228[11][:sum],
    week3: b228[18][:sum],
    week4: b228[25][:sum]
  }

  # 全療養者
  n79 = {
    week1: b293[7][:sum],
    week2: b293[14][:sum],
    week3: b293[21][:sum],
    week4: b293[28][:sum]
  }

  # 自宅療養や療養施設を積極的に利用した場合、必要と思われる確保病床数（酸素需要者の2.5倍）
  c85 = c79.keys.to_h do |k|
    [k, c79[k] * Rational('2.5')]
  end

  # ハイリスク軽症者や、ハイリスクでなくとも中等症 I は基本的に入院させる場合、必要と思われる確保病床数（酸素需要者の4倍）
  c91 = c79.keys.to_h do |k|
    [k, c79[k] * Rational('4')]
  end

  json = {
    date: now.iso8601,
    酸素需要を要する人: c79.each.to_h { |k, v| [k, v.round] },
    重症病床を要する人: h79.each.to_h { |k, v| [k, v.round] },
    全療養者: n79.each.to_h { |k, v| [k, v.round] },
    自宅療養や療養施設を積極的に利用した場合: c85.each.to_h { |k, v| [k, v.round] },
    基本的に入院させる場合: c91.each.to_h { |k, v| [k, v.round] },
    新規陽性者数データ: b98.slice(0, 19).map { |v| v[:sum].round },
    酸素需要を要する人データ: b163.slice(0, 19).map { |v| v[:sum].round },
    重症病床を要する人データ: b228.slice(0, 19).map { |v| v[:sum].round },
    自宅療養や療養施設を積極的に利用した場合データ: b163.slice(0, 19).map { |v| (v[:sum] * Rational('2.5')).round },
    基本的に入院させる場合データ: b163.slice(0, 19).map { |v| (v[:sum] * Rational('4.0')).round },
    全療養者データ: b293.slice(0, 19).map { |v| v[:sum].round },
  }

  File.write(File.join(__dir__, '../../data/', 'health_burden.json'), JSON.pretty_generate(json))
end
