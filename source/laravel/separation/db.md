# データベースサービスの構築

では、まずはデータベースの構築を行います。
ここでは、MySQLを使用し、以下の設定を加えていくことにします。

- データベース名: `laravelapp`
- データベースへのアクセスユーザー: `appuser`
- データベースへのアクセスパスワード: `apppass`
- データベースのホスト名: `db`

## データベースの作成

データベースはStatefulSetで管理するようにしましょう。

```{literalinclude} src/ss-db.yml
:language: yaml
```

複雑そうに見えますが、基本的にはMySQLのイメージ起動と、必要なPV/PVCの設定を行っているだけです。

## 起動状態の確認

MySQLは起動に時間を要することがわかっているので、リーディネスプローブで、受付可能かを確認してからサービス公開できるようにしておきましょう。
{command}`mysqladmin`を使って実装してみましょう。


```{literalinclude} src/ss-db-readiness.yml
:language: yaml
:diff: src/ss-db.yml
```

# サービスの作成

サービスについては、ClusterIPで普通に作成すればいいでしょう。

```{literalinclude} src/svc-db.yml
:language: yaml
```

適用することで、データベースへの接続が可能になります。

```bash
$ kubectl apply -f svc-db.yml
$ kubectl get svc

NAME          TYPE        CLUSTER-IP        EXTERNAL-IP   PORT(S)          AGE
kubernetes    ClusterIP   192.168.194.129   <none>        443/TCP          42h
laravel-app   NodePort    192.168.194.145   <none>        8000:30928/TCP   65m
db            ClusterIP   192.168.194.188   <none>        3306/TCP         70s
