# .env持ち込み問題とConfigMap

データベースが分離して動くために、前項ではMySQLデータベースを稼働させました。
しかし、データベースを開発時のSQLite以外を使おうとした場合、問題になるのはapp上に配置する {file}`.env` です。
このファイルには、データベース利用時にアカウント情報を設定することになるため、標準的な {file}`.gitignore` では管理対象外として含まれていません。

このためにK8sがサポートしている機能として、2つ紹介しておきます。

- ConfigMap: 設定ファイルをK8sのリソースとして管理する
- Secret: ConfigMapの暗号化版

今回は取り扱いの簡単なConfigMapを使って、 {file}`.env` を管理してみましょう。

## .envファイルの編集

`app`ディレクトリにある {file}`.env` を**移動**し、今回作成中のマニフェストのおいているディレクトリに配置してください。

そして、移動してきた {file}`.env` に対して、以下のように修正を加えてみましょう(システム設計演習の時とほぼ同じです)。

```{literalinclude} src/.env
:diff: src/.env-old
```

## ConfigMapの作成

ConfigMapは今までのYAMLファイルを使って作成することができます。
ファイル名を {file}`cm-dotenv.yml` として以下のように作成してください。

1. ファイル作成後、cmなどとタイプすると、ConfigMapリソースのスニペットが選択できるので、まずは展開する
2. `metadata.name` を `dotenv` にする
3. `data` にある `key` を `.env` とし、`value`の部分に `|` 記号を入れる
4. 次の行以下に、{file}`.env` の内容を貼り付け、インデントを設定する

結果として以下のようになります。冒頭10行のみにしていますが、インデントは末尾まで揃えるように注意してください。

```{literalinclude} src/cm-dotenv.yml
:linenos:
:lines: 1-10
```

このマニフェストを適用すると、ConfigMapが作成されます。

```bash
$ kubectl apply -f cm-dotenv.yml
$ kubectl get cm     # ConfigMapの確認
NAME               DATA   AGE
kube-root-ca.crt   1      42h
dotenv             1      49s
```

cm/dotenvの内容については、`kubectl describe`で確認できます。

```bash
$ kubectl describe cm/dotenv

Name:         dotenv
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
.env:
----
APP_NAME=Laravel
APP_ENV=local
APP_KEY=base64:qawsedrftgyhujikolp...
APP_DEBUG=true
APP_TIMEZONE=UTC
APP_URL=http://localhost


APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US
...(以下略)
```

````{note}
実はファイルから直接作ることもできます。複数のファイルをひとまとめに設定したいときはこちらの方が便利です。

```bash
# cm/sampleとして作成
$ kubectl create configmap sample --from-file .env
```
````

## ConfigMapを利用する

作成はしたものの、いきなりConfigMapを使うことができません。
ConfigMapを使うためには、Podのマニフェストに設定する必要があります。
そもそもどのように見えるかを先に検証しましょう。

```{literalinclude} src/pod-cmview.yml
:language: yaml
:linenos:
:emphasize-lines: 17-20,22-24
```

ConfigMapはボリュームとして見せかけることができます。
PVCの時と同じように、`volumes`で指定する際に、`configMap`を指定します。

このようにすると、ConfigMapの内容が`/mnt`以下で利用できるようになります。

```bash
$ kubectl apply -f pod-cmview.yml
$ kubectl exec pod/cmview -- cat /mnt/.env
$ kubectl delete pod/cmview # 削除
```

さらに、ConfigMapの中の特定のキーだけを抽出してファイル単位でのマウントも可能です(`subPath`キー)。

```{literalinclude} src/pod-cmview-file.yml
:language: yaml
:diff: src/pod-cmview.yml
```

これにより、`/tmp/dotenv`ファイルとして、ConfigMap中の`.env`の内容が入ります。

この仕組みを使えば、`.env`ファイルをイメージに含めずに、リソースとして活用できます。

## ConfigMapを使ったデプロイメント

それでは、この仕組みを使ってデプロイメントを書き換えてみます。

```{literalinclude} src/deploy-app-simple-cm.yml
:diff: ../simple/src/deploy-app-simple.yml
```
