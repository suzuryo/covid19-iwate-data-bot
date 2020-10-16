# Google Sheets で管理しているデータから json を書き出す CLI スクリプト

data の json を手動管理するのは大変なので、Google Sheetsに入力して、このスクリプトを動かせば、
iwate.stopcovid19.jp のビルドに必要な json が生成される。

## 1. 環境構築

- ruby 2.7.1

```
$ bundle
```

## 2. Google Sheets API への 認証情報

- Google Sheets でデータを管理する (今のところ一般に非公開)
- Google Sheets API を利用するための OAuth 用の credentials.json が必要
- 初回起動時に token.yaml が生成される

## 3. CLIプログラムの実行

```
ruby generate_data_json.rb
```

実行すると

```
./data/data.antigen_tests_summary.json
./data/data.contacts.json
./data/data.json
./data/data.patient_municipalities.json
./data/data.querents.json
./data/patient_municipalities.json
```

が生成される。

## 4. 実行タイミング

github workflows により、以下のタイミングで自動実行される。

- 10:00 UTC (19:00 JST) 時台に data/*.json が更新され デプロイ される。
- 12:00 UTC (21:00 JST) 時台に data/*.json が更新され デプロイ される。
- 14:00 UTC (23:00 JST) 時台に data/*.json が更新され デプロイ される。
