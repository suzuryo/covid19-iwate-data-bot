# iwate.stopcovid19.jp で使う json を書き出す CLI スクリプト

## 1. 環境構築

- ruby 3.0.1

```
$ bundle
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

## 3. 岩手県と盛岡市のサイトからTSVを生成する

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

## 4.1 twitter.com/iwatevscovid19 からTSVを生成する

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


## 4.2 ./input/tweets.txt からTSVを生成する

その日の15時にLINEで届くメッセージをコピペして `./input/tweets.txt` を作成してから

```
bundle exec bin/tweet2tsv.rb --from-files
```

を実行すると、

```
./tsv/tweet.tsv
```

が生成される。
