# 単純な構造からはじめる

Laravelは、PHPとモジュールが一通り用意できれば、簡単なシステムは構築可能です。
ということで、まずは単純な構造の単一ポッド構造で作成してみましょう。

## 必要なものは?

Laravel環境を構築するために必要なものは、以下のものとなります(ただし最低限)。

- PHPランタイム
  - 現代版はWebサーバーが組み込まれているのでWebサーバーは不要です
- composer
  - Laravelインストール用のcomposerパッケージ

データベースは? と思われるかもしれませんが、データベースはなくても動きますし、開発レベルであればSQLiteで事足りると思います。
必要になってから検討しましょう。

