# Google Sheets で管理しているデータから json を書き出す CLI スクリプト

data の json を手動管理するのは大変なので、Google Sheetsに入力して、このスクリプトを動かせば、
iwate.stopcovid19.jp のビルドに必要な json が生成される。

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
ruby bin/googlesheet2json.rb
```

実行すると

```
./data/alertsummary.json
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

## 3. 岩手県と盛岡市のサイトからTSVを生成プログラムの実行

```
ruby bin/site2tsv.rb
```

実行すると、pref.iwateとcity.moriokaからデータをスクレイピングして

```
./tsv/site.tsv
```

が生成される。

## 4. twitter.com/iwatevscovid19 からTSVを生成プログラムの実行

```
ruby bin/tweet2tsv.rb
```

- TWITTER_BEARER_TOKEN を取得して .env に設定する

実行すると、twitter.com/iwatevscovid19 のつぶやき群からデータを取得して

```
./tsv/tweet.tsv
```

が生成される。
