# Laravel環境の基礎を構築するためのDockerfile
FROM php:8
# composerコマンドを持ち込む
COPY --from=composer/composer /usr/bin/composer /usr/bin/composer
# 作業用ユーザーを用意する
RUN useradd -m -d /home/worker -s /bin/bash worker
# Laravelプロジェクトのインストール時に使うツール
RUN apt-get update; apt-get install -y git zip unzip
WORKDIR /app
RUN chown -R worker:worker /app
USER worker
# さしあたり仮サーバーを立ち上げておく
CMD ["php", "-S", "0.0.0.0:80", "-t", "/app/public"]
