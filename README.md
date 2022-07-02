# iwate.stopcovid19.jp で使う json を書き出す CLI スクリプト

## 1. 環境構築

```
docker compose build
```

## 2. JSON生成プログラムの実行

- Google Sheets でデータを管理する (今のところ一般に非公開)
- Google Sheets API を利用するための OAuth 用の credentials.json が必要
- 初回起動時に token.yaml が生成される

```
docker compose run --rm runner ./bin/googlesheet2json.rb
```

実行すると

```
./data/alert.json
./data/confirmed_case_age.json
./data/confirmed_case_area.json
./data/daily_positive_detail.json
./data/data.json
./data/health_burden.json
./data/main_summary.json
./data/news.json
./data/patient_municipalities.json
./data/positive_rate.json
./data/positive_status.json
./data/self_disclosures.json
./data/urls.json
```

が生成される。


## 3. Twitterに書き込まれたpng画像からtesseractでOCRしてTSVを生成する

- .env に Twitter API v2 を利用するための TWITTER_BEARER_TOKEN が必要

```
docker compose run --rm runner ./bin/image2tsv.rb
```

を実行すると、

```
./tsv/images.tsv
```

が生成される。


## 4. 岩手県と盛岡市のサイトからPDFをダウンロードしてTSVを生成する

```
docker compose run --rm runner ./bin/pdf2tsv.rb
```

を実行すると

```
./tsv/pdf.tsv
```

が生成される。


## 5. iwate-ninshou.jp から GoogleMyMap に読み込ませるCSVを生成する

```
docker compose run --rm runner ./bin/iwateNinshouRestaurant2csv.rb
```

を実行すると、

```
./tsv/restaurant.csv
```

が生成される。
