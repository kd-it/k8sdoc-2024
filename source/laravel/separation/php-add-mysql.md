# LaravelイメージのMySQL対応

現在使用しているLaravelのイメージ(ユーザー名/laravel-app:v0)は、現時点ではMySQLには対応していない状況です。
そのため、MySQL対応を行う必要があります。

## MySQL利用に設定を変更する

{file}`.env`はSQLiteの設定になっていますので、MySQLに変更しましょう。

```{literalinclude} src/.env
:diff: src/.env-old
```


## イメージの再作成(v1)

といっても、拡張機能の追加指示を1行追加してイメージを作り直すだけなので、簡単に対応できます。

```{literalinclude} ../simple/src/Dockerfile.app.v1
:diff: ../simple/src/Dockerfile.app
:language: Dockerfile
```

ということで、追加したらv1タグでイメージを作り、送信しましょう。

```bash
$ docker build -t ユーザー名/laravel-app:v1 .
$ docker push ユーザー名/laravel-app:v1
```

これで、MySQL対応のLaravelイメージが作成できました。

