# ベースイメージを作る

Laravelを走らせるベースイメージを作成して、これを利用することにしましょう。
あとで更新する可能性もあるのでタグも用意しておきましょう。

```{literalinclude} src/Dockerfile
:language: Dockerfile
```

このDockerfileをビルドして、イメージを構築します。
ここではlaravel-builderというローカルイメージで作成することにします。
この時点ではLaravelのベースとなるソースツリーもないため、このイメージを利用してソースツリーを構築することにします。

```bash
# カレントディレクトリ(.)にDockerfileがあることを前提としています
$ docker build -t laravel-builder:v0 .
```

そして、このイメージを利用して、Laravelのソースツリーを構築します。
ローカルにソースツリーを持ち出す必要があるので、コンテナを消さないようにして一度プロジェクトを作り、コピーで取り出すことにしましょう。

```bash
# 作成したイメージでコンテナを生成し、appプロジェクトを作成
$ docker run --name=build laravel-builder:v0 \
  bash -ec "composer create-project laravel/laravel app; cd app; php artisan key:generate"

# 作成したappプロジェクト(ディレクトリ)をローカルにコピー
$ docker cp build:/app/app .
# コンテナを削除
$ docker rm build
```

これで持ち出せました。
この状態で、以下の構造になっていることを確認してください。

```
.
├── Dockerfile
└── app(ディレクトリ)
```

```{note}
コンテナ内で実行したコマンド {command}`php artisan key:generate`は、Laravelの暗号化キーを生成するためのものです。
この操作は、Laravelのセキュリティに関わるものであり、実際の運用時にも必要になります。

このキーは、{command}`composer create-project`の操作で {file}`.env`に作成されるはずですが、作成されない場合もあるため、意図的に実行して生成させています。
```

次は、Laravelのプロジェクトが走らせられるよう、Dockerfileを修正します。
Laravel環境では、{command}`artisan`コマンドを用いて、アプリケーションの設定やデータベースのマイグレーションを行います。
ここから簡易サーバーが起動できるようになっているので、これをWebサーバーとして外に見えるようにすれば、最低限の環境は構築できます。

その前に、{command}`artisan` が開くポート番号がいくつかを確認しておきましょう。

```bash
$ docker run --name=laravel -it -v $PWD/app:/app laravel-builder:v0 php artisan serve

   INFO  Server running on [http://127.0.0.1:8000].

  Press Ctrl+C to stop the server
```

ここでCtrl+Cで終了させておきましょう、ついでにコンテナも破棄しておきましょう。

```bash
$ docker rm laravel
```

これで、ポート番号が8000番であることがわかりました。
- Dockerfileを修正して、8000番を開放しましょう
- {command}`artisan`を起動するようにしましょう

```{literalinclude} src/Dockerfile.serve
:language: Dockerfile
:diff: src/Dockerfile
```

```{note}
`artisan`のオプションにて`--host 0.0.0.0`を渡しているのは、Dockerコンテナの外側からアクセスするために、外部向けのIPアドレスでも待ち受け状態にする必要があるからです。
0.0.0.0は、そのホスト(コンテナ)が利用可能な全てのIPアドレスに対する待ち受けになっています。
```

では、このイメージをビルドしてから、コンテナの起動を試みてみましょう。

```bash
# タグを付けて先程のものと別としておきましょう(あまり必要性はありませんが)
$ docker build -t laravel-builder:v1 .
# 8000番ポートの開放と、appディレクトリのマウントを行いつつ起動
$ docker run -d --name=laravel -p 8000:8000 -v $PWD/app:/app laravel-builder:v1
```

これで、ブラウザから`http://localhost:8000`にアクセスすると、Laravelの初期画面が表示されるはずです。

```{figure} images/laravel-boot.png
Laravelのスタートアップ画面
```

この状態でも、Laravelの開発が可能になっています。

- {file}`app`ディレクトリをvscodeなどエディタで開き、編集する
- 変更結果はブラウザ上でそのページを開いて確認すれば良い
- マイグレーション・シーダーの操作、MVCの作成などはコンテナ内で行う必要があります
  - `docker exec -it laravel bash`で端末接続しても良い
  - `docker exec -it laravel php artisan make:model Hoge`なども可能

## モデルからデータベースを作成する

```bash
# モデル作成、ついでにマイグレーション(-m)・シーダー(-s)・コントローラー(c)の作成も行う
$ docker exec -it laravel php artisan make:model Item -msc
```

あとは最低限の所をいじっていきましょう。

### マイグレーションファイル

マイグレーションファイルは作成した日時によってファイル名が決まります。実際のファイル名は自身の環境で確認してください。

```{literalinclude} src/app/database/migrations/2024_10_30_203411_create_items_table.php
:lines: 12-19
:linenos:
:lineno-start: 12
:emphasize-lines: 6
```

作成したら、マイグレーションを適用してDB上にテーブルを作成させましょう。

```bash
$ docker exec -it laravel php artisan migrate
```


### シーダーの準備と適用

初期値が無いとわかりにくいので設定するためにシーダーも準備します。

{file}`app/database/seeders/ItemSeeder.php` は `run`メソッドの実装を修正して、名前をいくつか入れておきましょう。
```{literalinclude} src/app/database/seeders/ItemSeeder.php
:linenos:
:lines: 14-20
:lineno-start: 14
:emphasize-lines: 3-6
```

{file}`app/database/seeders/DatabaseSeeder.php` は、`ItemSeeder`を呼び出すように修正します。
```{literalinclude} src/app/database/seeders/DatabaseSeeder.php
:linenos:
:lines: 14-19
:lineno-start: 14
:emphasize-lines: 3-5
```

こちらも適用させておきましょう。

```bash
$ docker exec -it laravel php artisan db:seed

  INFO  Seeding database.

  Database\Seeders\ItemSeeder .............................................................................................................. RUNNING
  Database\Seeders\ItemSeeder ........................................................................................................... 28 ms DONE
```

ついでに内部キー(Laravelの演算時に使うもの)も設定しておくといいでしょう。

```bash
$ docker exec -it laravel php artisan key:generate
```

## ルーティングと名前一覧表示コード

ルーティングとして、初期値ではいわゆるWelcomeのビューが指定されていますので、ここをコントローラー経由にして、名前一覧が出るようにしてみます。

まずは {file}`app/routes/web.php` を修正します。

```{literalinclude} src/app/routes/web.php
:linonos:
:emphasize-lines: 4,6-9
```
※ 既存のルーティングはコメントアウトしています

次に、コントローラー({file}`app/Http/Controllers/ItemController.php`)を書き換えます。

```{literalinclude} src/app/app/Http/Controllers/ItemController.php
:linenos:
:emphasize-lines: 6,11-15
```

ビューとして`index`を指定しますので、{file}`app/resources/views/items/index.blade.php`を作成します。

```{literalinclude} src/app/resources/views/index.blade.php
```

```{note}
`html:5`のスニペットをベースに、タイトルやbody部分を書き換えてる程度です。
bladeのテンプレートエンジンを使っているため、`@foreach`などのディレクティブが使われています。
```

## ベースイメージにアプリケーションを入れる

では、ベースイメージにアプリケーションを入れてみましょう。
その前に、準備のファイルを作成します。 `.dokerignore` というファイルです。

```{literalinclude} src/app/.dockerignore
```

これは、`Dockerfile`でビルドの際に『持ち込まない』ファイルを指定するためのものです。
`/app/vendor`ディレクトリ(`Dockerfile`のあるディレクトリをルートとする)は、`composer`でインストールされたものであり、イメージに持ち込む必要がないため、ここに記述しています。

そして、`artisan serve`する前に、事前準備が必要なこともここまででわかったので、それを代行するためのスクリプトを作成します。

```{literalinclude} src/app/entrypoint.sh
```

スクリプトの簡単な捕捉をしておきます。

- 利用するDBの形態がSQLiteであることを確認した場合、データベースのファイルがないのを確認して作成する
  - こうしないと、後でマイグレーションの時に確認がでてしまうことがあるためです
- {command}`composer` で {file}`vendor` ディレクトリ以下にモジュールを取得する
- {command}`artisan` を使って、アプリケーション内部で用いる鍵情報とマイグレーションを行う
  - マイグレーション時にシーダーも呼び出す
- 最後に開発サーバーを起動するが、これ以降は`sh`のプロセスは不要になるため上書きで起動(`exec`)する

これを使うように、`Dockerfile`を修正します。

```{literalinclude} src/Dockerfile.app
:language: Dockerfile
:diff: src/Dockerfile.serve
```

これまではイメージ名が`laravel-builder`でしたが、アプリケーションになっているでしょうから、`laravel-app`という名前にしておきます。
最初のバージョンとなるし**v0タグ**としておきましょう

```bash
$ docker build -t laravel-app:v0 .
```

これで、アプリケーションのイメージができました。
起動してみましょう。

```bash
# 終了時にコンテナを破棄し忘れないように--rmを付けています
$ docker run --rm --name=laravel-app -p 8000:8000 laravel-app:v0
```

これで、ブラウザで確認すると、DBに入った名前の一覧が取得できるようになっています。

```{figure} images/laravel-app.png
ブラウザで確認した結果
```

# リポジトリに上げておこう

こうやって作ったappのディレクトリは、今後の作業のためにリポジトリに上げておくようにしましょう。

## ローカルでのリポジトリ作成

```bash
$ cd app
$ git init
$ git add .
$ git commit -m "Initial commit"
```

## リモートリポジトリの作成、登録、プッシュ

リポジトリを作成したら、リモートリポジトリを作成して登録しておきましょう。

1. [GitHub](https://github.com)をブラウザで呼び出す
2. 新規リポジトリの作成を選ぶ(青い {menuselection}`New` ボタンをクリック)
3. 適当な名前でリポジトリを作成する、なお今回は**パブリックリポジトリ**にしておいてください(ここ地味に重要)
4. 作成後、リポジトリのURLをクリップボードにコピーしておいてください

次にローカルリポジトリを登録します。

```bash
$ git remote add origin <取得したリポジトリのURL>
```

そして、プッシュします。

```bash
$ git push -u origin master
```

これでブラウザで表示しているリポジトリページを見に行くと、先程のコミットが反映されてソースが入っているはずです。
ただし、Laravel環境の初期設定により、`vendor`ディレクトリや`database/database.sqlite`は含まれておりません(これで正解)。

# Docker Hubへのプッシュ

そして、作成したイメージをDocker Hubにもプッシュしましょう。
この後K8sで利用する際に、Docker Hubからイメージを取得することになるためです。
イメージ名は `<ユーザー名>/laravel-app:v0` としておきましょう。

```bash
$ docker build -t <ユーザー名>/laravel-app:v0 .
$ docker push <ユーザー名>/laravel-app:v0
```

```{figure} images/push-to-docker.png
Docker Hubにプッシュ中の様子
```

# せっかちさんへ

今回の操作で作っているLaravelのプロジェクトについては、以下のリポジトリにて公開しています。

- [kd-it/2024-as2-laravel-example](https://github.com/kd-it/2024-as2-laravel-example.git)

{file}`Dockerfile` を作成しているディレクトリにて、以下の操作を行えば、このリポジトリをクローンして、そのまま動かすことができます。

```bash
$ git clone https://github.com/kd-it/2024-as2-laravel-example.git app
$ cd app
$ cp .env.example .env # .envは公開対象ではないため含まれていません、この作業で作成してください
$ cd ..
```

```{note}
Windows環境の方は {command}`cp`の代わりに {command}`copy`を使ってください
```
