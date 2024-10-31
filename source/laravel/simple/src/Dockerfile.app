# Laravel環境の基礎を構築するためのDockerfile
FROM php:8
# composerコマンドを持ち込む
COPY --from=composer/composer /usr/bin/composer /usr/bin/composer
# 作業用ユーザーを用意する
RUN useradd -m -d /home/worker -s /bin/bash worker
# Laravelプロジェクトのインストール時に使うツール
RUN apt-get update; apt-get install -y git zip unzip
WORKDIR /app
COPY app /app
RUN chown -R worker:worker /app
USER worker
# artisan serveの使うポート番号を指定
EXPOSE 8000
# artisan serveで仮サーバーを起動させる(要注意)
CMD [ "/bin/sh", "entrypoint.sh" ]
