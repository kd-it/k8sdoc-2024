# アプリケーションサーバー(app)

アプリケーションサーバーについては、単純に使うだけであれば、特に難しい事はありません。
アプリケーションのイメージについては、ここでは `ghcr.io/kd-it/php-devcontainer/app:1729810622` を使うことにします。

```{note}
コンテナイメージの配置場所はDocker Hubだけではありません。
今回使用しているのは、GitHubが提供するコンテナレジストリサービス(GitHub Container Registry)です。
この場合、提供サーバーのホスト名からイメージへのパスを書くことで利用できます。

この資料では、ghcrへのログインやイメージの配置方法は記していません。
```

## 単体で動くサーバーでテストする

Laravelでは、`artisan`というコマンドが提供されており、そこから簡易サーバーが起動できるようになっています。
これを使って起動させることができそうなマニフェストを書いて見ましょう。今回はストレージは考えずに使うため、デプロイメントで作ることにします。

```{literalinclude} src/deploy-app.yml
:name: deploy-app.yml
:caption: deploy-app.yml(まだ外枠)
:language: yaml
```

このイメージではとりあえずサーバーは起動しているので起動後にテスト用サーバーで接続ができるかの確認をしてみます。

```{code-block} shell
:caption: テストサーバーの起動と接続テスト

$ kubectl apply -f deploy-app.yml
deployment.apps/app created

$ kubectl get deploy
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
app    1/1     1            1           34s

$ kubectl get pods -l app=app # ラベル "app: app:"を抽出
NAME                  READY   STATUS    RESTARTS   AGE
app-684b56ff7-sv58f   1/1     Running   0          74s
```

無事常駐起動できているようですので、execで中に入ってアプリケーションを起動してみましょう。

```{code-block} shell
:caption: ブートストラップアプリケーションの起動

$ kubectl exec -it deploy/app -- bash
# 初期イメージはアプリケーション自体が無いので、まず作る必要がある!
/app$ composer create-project laravel/laravel .
/app$ php artisan server --host=0.0.0.0

   INFO  Server running on [http://0.0.0.0:8000].

  Press Ctrl+C to stop the server
```

仮サーバーが8000/tcpで起動しているのがわかりました。
開発コンテナーで使う分にはポート転送は自動で行っていましたが、K8s経由の場合は経路の違いから自分でポートフォワードを行う必要があります。
こちらはこのままにして、他の端末からポートフォワードをしてみましょう。

```{code-block} shell
:caption: ポートフォワードの設定

$ kubectl port-forward deploy/app 8000:8000 # ホスト側ポートはお好みで
```

これでブラウザを使って、 http://127.0.0.1:8000/ とすると、Laravelの初期画面が出ます。

```{figure} images/laravel-in-app.png

Laravelの開発サーバーへの接続確認
```

アプリケーションサーバーが動くことはわかりました。
動かせることはわかりましたので、いちど `atisan` コマンドは停止 ({key}`Ctrl+C`) しておきましょう。
そして、 `kubectl delete -f deploy-app.yml` でリソースも削除しておきましょう。


## どのようにアプリケーションコードを注入するか?

では、アプリケーションのサーバー(app)に対して、実際のLaravelのコードを入れようと思ったらどうするといいのでしょうか。
いくつか考えられると思いますが、ここでは2つの方法を考えてみます。

- コンテナイメージに直接入れてしまう方法
- 起動時にコンテナに注入する方法

前者はappイメージ(`ghcr.io/kd-it/php-devcontainer/app:1729810622`)をベースとしたイメージを作成するというものです。
後者は、appイメージをそのまま使い、起動時にアプリケーションのコードを持ち込むという方法になります。

両方を行おうとすると話のボリュームが大きくなりすぎるので、ここでは確実に動くであろう、前者の方法で進めてみましょう。

## 準備: アプリケーションコードを入手する

まずは、アプリケーションのコードが必要になります。ここでは、Laravelの初期コードをベースにしましょう。
ローカル環境でPHP(composer)が動く環境であれば、そのまま`composer`コマンドで作れますが、ないことを想定し、dockerコンテナで作るようにしてみます。

```{code-block} shell
:caption: Laravelの初期コードを作成する

PS> mkdir src
PS> docker run --rm -v ${PWD}/src:/app -w /app composer composer create-project laravel/laravel /app/sampleapp
```

そして、作成したコードに用意されたサンプルの {file}`.env` ファイルを編集しておきましょう。データベースへ繋げるための設定を行う必要があります。

```{code-block} diff
:caption: .envファイルの編集

--- .env.prev   2024-11-07 09:33:15.303200566 +0900
+++ .env        2024-11-07 09:34:01.568176051 +0900
@@ -21,12 +21,12 @@
 LOG_DEPRECATIONS_CHANNEL=null
 LOG_LEVEL=debug

-DB_CONNECTION=sqlite
-# DB_HOST=127.0.0.1
+DB_CONNECTION=mysql
+DB_HOST=db
 # DB_PORT=3306
-# DB_DATABASE=laravel
-# DB_USERNAME=root
-# DB_PASSWORD=
+DB_DATABASE=app
+DB_USERNAME=appuser
+DB_PASSWORD=apppass

 SESSION_DRIVER=database
 SESSION_LIFETIME=120
 ```

```{note}
本来 {file}`.env`ファイルは公開しない方がいい情報です。
こういうファイルはconfigmapやsecretに入れて、それを参照するようにするのが一般的です。

ですが、今回はわかりやすさ優先でこの方式にしています。
```

## コンテナイメージに直接入れる

では、コンテナイメージに直接入れることを考えてみましょう。
この場合、{file}`Dockerfile`にて、アプリケーションコードを適切な場所にコピーすればOKです。

```{literalinclude} src/Dockerfile
:caption: Dockerfile(アプリケーションコードをコピーする)
:language: dockerfile
```

配置としては以下のようになっていることを想定します。
カレントディレクトリも`Dockerfile`のある場所としています。

```
.  ← カレントディレクトリ
├── Dockerfile
└── sampleapp
```

この`Dockerfile`でイメージを作って、想定通りの場所にあるかを確認してみましょう。

```{code-block} shell
:caption: テストビルドと確認
PS> docker build -t testapp .
PS> docker run --rm testapp ls /app # /appにsampleappのコードがあることを確認
README.md           composer.json       package.json        resources           tests
app                 composer.lock       phpunit.xml         routes              vendor
artisan             config              postcss.config.js   storage             vite.config.js
bootstrap           database            public              tailwind.config.js
```

これでイメージにアプリケーションコードが入っていることが確認できました。
正式なイメージ名で作り直して、それでデプロイメントを作れば良さそうですが、その前にやっておくべき作業があります。

### 余計なデータを持ち込まないようにする

アプリケーションコードを先程入れましたが、入れる必要がない・入れてはいけないデータがあったりします。

- `vendor` ディレクトリ
  - ここにあるものは環境に合わせて`composer`コマンドで取得できるものです
- `database/database.sqlite` ファイル(SQLiteのデータベースファイル)
  - 今回はMySQLベースでdbホストが動いているので不要

特に `vendor` は容量が大きいので、`Dockerfile`での`COPY`命令で持ち込むのもよくありません。

そこで、`Dockerfile`にて参照しないようにするため、`.dockerignore`というファイルを用意しておきます。
このファイルの中で、対象外とするファイルやディレクトリを指定できます。

```{literalinclude} src/.dockerignore
:caption: .dockerignore(Dockerで持ち込まないファイル)
```

`storage/logs`のところが少し混み合っていますが、これは以下のように解釈されます。

- `storage/logs`にあるものは持ち込まない
- ただし `storage/logs/.gitignore` は持ち込む

このディレクトリはいわゆるログ置場のため、場合によっては(ローカル開発の影響で)ログファイルが存在することがあるので、それは無視させます。ただし最初からおかれている`.gitignore`は対象外として取り込み対象としておこうという流れです。
これで再度テストイメージを作り、検証してみます。

```
.
├── .dockerignore
├── Dockerfile
└── sampleapp
```

```{code-block} shell
:caption: テストビルドと確認(ファイル除外設定込み)

PS> docker build -t testapp .
PS> docker run --rm testapp ls /app # vendor消えた?
README.md           composer.json       package.json        resources           tests
app                 composer.lock       phpunit.xml         routes              vite.config.js
artisan             config              postcss.config.js   storage
bootstrap           database            public              tailwind.config.js
PS> docker run --rm testapp ls /app/database # database.sqlite消えた?
factories   migrations  seeders
PS> docker run --rm testapp ls -a /app/storage/logs # logs消えた?
.           ..          .gitignore
```

ログディレクトリは余計な要素が消えたかがよくわかりませんので、ダミーデータを入れて再度確認してみましょう。

```{code-block} shell
PS> echo "dummy" > sampleapp/storage/logs/dummy.logs
PS> docker build -t testapp .
PS> docker run -t --rm testapp ls -a /app/storage/logs # dummy.log消えた?
.           ..          .gitignore ← 消えている
PS> rm sampleapp/storage/logs/dummy.logs # 後始末
```

これで、不要なデータを持ち込まないようにすることができました。
改めてイメージを作りましょう。こちらはDocker Hubにおくことを考慮して、ユーザー名を付けたイメージとしておきます。
また、後で変更が行われることも想定して、タグも付けておきます。
今回は `in-v1` としておきます。

- アプリケーション動作時のユーザーはvscodeとなっているので事前にパーミッション等を変更しておきます
- `vendor`を持ち込まなかった分、ビルド時に`composer install`を行うようにしておきます

```{literalinclude} src/Dockerfile.in-composer
:caption: Dockerfile(アプリケーションコードをコピーする)
:name: Dockerfile
:language: dockerfile
```

```{code-block} shell
PS> docker build --push -t DockerHubユーザー名/app:in-v1 . # 作成と同時にpushで配置
```

これでイメージが作成されました。

### デプロイメントを作成する

次に、デプロイメントを作成してみましょう。

```{literalinclude} src/deploy-app-in-v1.yml
:language: yaml
```

このマニフェストを適用し、ポートフォワードで繋げてみましょう。
ただし、Webサーバー(`artisan serve`)が動いていないので、こちらを立ち上げておきましょう。

```{code-block} shell
PS> kubectl apply -f deploy-app-in-v1.yml
deployment.apps/app created <- configuredの場合もある(前のリソースが残っていた場合)
PS> kubectl exec -it deploy/app -- bash
/ # php artisan serve --host=0.0.0.0

# <<< 別の端末でポートフォワードを起動 >>>
PS> kubectl port-forward deploy/app 8000:8000
```

この状態でブラウザで様子を見てみましょう。

```{figure} images/app-1st-error.png

初回アクセス時の様子
```

エラーが出てしまいました。これは、データベースがないためです。
マイグレーションを行う必要がありますが、だからといって`Dockerfile`ではできません。
でしたら、`initContainers`にて実行させてみたらどうでしょう。
DBの初期化は二度目以降はむだかと思いますが、マイグレーション情報は記録されているので、重複実行は行われません。
シーダーは今回ありませんのでここでは無視しておきます。

```{literalinclude} src/deploy-app-in-v1.1.yml
:name: deploy-app-in-v1.yml
:language: yaml
:diff: src/deploy-app-in-v1.yml
```

裏でポッドの変更を確認してみると、以下のような形で入れ替わります。

```{code-block} shell
PS> kubectl get pods -w
NAME                  READY   STATUS    RESTARTS        AGE
db-0                  1/1     Running   1 (7h11m ago)   22h
app-5c78bcf89-dq2fh   1/1     Running   0               18m # 古いポッド
app-799cf86db-j2zdf   0/1     Pending   0               0s  # 新しいポッド
app-799cf86db-j2zdf   0/1     Pending   0               0s
app-799cf86db-j2zdf   0/1     Init:0/1   0               1s # 新: 初期化中
app-799cf86db-j2zdf   0/1     Init:0/1   0               8s
app-799cf86db-j2zdf   0/1     PodInitializing   0               12s # 新: 本体ポッド起動中
app-799cf86db-j2zdf   1/1     Running           0               13s # 新: 起動完了
app-5c78bcf89-dq2fh   1/1     Terminating       0               19m # 旧: 終了処理
app-5c78bcf89-dq2fh   0/1     Terminating       0               19m
```

```{note}
`kubectl port-forward`をまだ実行中だった場合、以前のポッドに繋げようとしてエラーになることがあります。
一度`Ctrl+C`でポートフォワーディングを止めてから再度ポートフォワードを実行してください。
```

これで、エラーが出ずに最初のページが出るようになりました。

```{figure} images/laravel-in-app-outerDB.png
今度こそ出ました
```

一応デプロイメントを再起動したケースを考えてみましょう。
マイグレーションは一度行ったものはスキップするので、問題なく動作するはずです。

```{code-block} shell
PS> kubectl rollout restart deployment/app # デプロイメントの再起動
```

同様にポッド状態をモニターすると、以下のようになります。

```{code-block}
app-7f7959589-kg6vc   0/1     Pending           0               0s  <--入れ替わりのポッドが起動
app-7f7959589-kg6vc   0/1     Pending           0               0s
app-7f7959589-kg6vc   0/1     Init:0/1          0               0s
app-7f7959589-kg6vc   0/1     Init:0/1          0               3s
app-7f7959589-kg6vc   0/1     PodInitializing   0               5s  <--初期化完了して本体起動
app-7f7959589-kg6vc   1/1     Running           0               10s <--無事起動
app-799cf86db-j2zdf   1/1     Terminating       0               7m52s <--古いポッドが終了
```

ポートフォワードをして読み込み直しても特に問題はおこらないので、確認してみましょう。
表示が確認できたら、適宜 `Ctrl+C` でポートフォワーディングは止めておきましょう。

## 起動時にコンテナに注入する方法は?

起動時にコンテナにアプリケーションコードを注入する方法はどうでしょうか?
アプリケーションのコードは、継続的に開発(保守)が行われれば、徐々にコードが変わっていきます。
それをいちいちイメージに作り直すのは面倒と考えることもできます。

この場合は、戦略として、`initContainers`を使って、コンテナ起動時にアプリケーションコードを注入する方法が考えられます。
どのように行えば良いかについては、自分で検討して自分で実装してみましょう。
