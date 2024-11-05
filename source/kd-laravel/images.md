# 利用するイメージについて

『システム開発演習』においては、以下のイメージを使っています。
ソースも公開済みです。

- [kd-it/php-devcontainer](https://github.com/kd-it/php-devcontainer)
  - [イメージ作成ソース](https://github.com/kd-it/php-devcontainer/tree/main/docker/)
    - web: Webサーバー部分、PHPバックエンドに適宜繋ぐ
    - app: PHPバックエンド(php-fpmベース))

コミッターがコードをpushすることで、適宜イメージがビルドされて更新されます。

- [Packages](https://github.com/orgs/kd-it/packages?repo_name=php-devcontainer)
  - ビルド時にタイムスタンプがタグとして付くようになっています

これ以外に、[MySQLの公式イメージ](https://hub.docker.com/_/mysql)を使っています。
