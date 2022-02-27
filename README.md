# iwate.stopcovid19.jp で使う json を書き出す CLI スクリプト

## 1. 環境構築

- ruby 3.0.1
- Python 3.7.11

```
$ bundle
$ pip install -r requirements.txt
```

## 2. JSON生成プログラムの実行

- Google Sheets でデータを管理する (今のところ一般に非公開)
- Google Sheets API を利用するための OAuth 用の credentials.json が必要
- 初回起動時に token.yaml が生成される

```
bundle exec bin/googlesheet2json.rb
```

実行すると

```
./data/alert.json
./data/daily_positive_detail.json
./data/data.json
./data/main_summary.json
./data/news.json
./data/patient_municipalities.json
./data/positive_by_diagnosed.json
./data/positive_rate.json
./data/positive_status.json
./data/self_disclosures.json
```

が生成される。

## 3.1 twitter.com/iwatevscovid19 からTSVを生成する

```
bundle exec bin/tweet2tsv.rb # 普通はこれ
bundle exec bin/tweet2tsv.rb new
bundle exec bin/tweet2tsv.rb new --days NUM
```

- TWITTER_BEARER_TOKEN を取得して .env に設定する

実行すると、twitter.com/iwatevscovid19 のつぶやき群から、 NUM days のデータを取得して

```
./tsv/tweet.tsv
```

が生成される。


## 3.2 ./input/tweets.txt からTSVを生成する

その日の15時にLINEで届くメッセージをコピペして `./input/tweets.txt` を作成してから

```
bundle exec bin/tweet2tsv.rb --from-files
```

を実行すると、

```
./tsv/tweet.tsv
```

が生成される。

## 4. 岩手県と盛岡市のサイトからPDFをダウンロードしてTSVを生成する

```
bundle exec bin/pdf2tsv.rb      # 普通はこれ
bundle exec bin/pdf2tsv.rb --rm # ダウンロード済みのPDFと変換済みのCSVを削除してやり直す
```

を実行すると

```
./tsv/pdf.tsv
```

が生成される。

## 5. iwate-ninshou.jp から GoogleMyMap に読み込ませるCSVを生成する

```
bundle exec bin/iwateNinshouRestaurant2csv.rb
```

を実行すると、

```
./tsv/restaurant.csv
```

が生成される。

## 6. Twitterに書き込まれたpng画像からtesseractでOCRしてTSVを生成する

tesseractをインストールしてPATHを通して、tessdata_bestのjpn.traineddataを導入してから

```
bundle exec bin/image2tsv.rb
```

を実行すると、

```
./tsv/images.tsv
```

が生成される。


------------------------------------------------------------

## [obsoleted]. 岩手県と盛岡市のサイトからTSVを生成する

個別ページでの公表が無くなったので 2021/9/2に使えなくなった

```
bundle exec bin/site2tsv.rb # 普通はこれ
bundle exec bin/site2tsv.rb new
bundle exec bin/site2tsv.rb new --id NUM
```

実行すると、pref.iwateとcity.moriokaのサイトから、id NUM 以降のデータをスクレイピングして

```
./tsv/site.tsv
```

が生成される。