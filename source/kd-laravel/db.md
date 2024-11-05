# データベース部分(db)

データベース自体は、MySQLのイメージを使って起動すればいいので特に難しい事は無いでしょう。
ここでは、以下の方針で作成することにしましょう。

- 名前はdb
- データベース名はapp
- アクセスユーザーはappuser/apppass
- CPUは500ms、メモリは512MB上限

## 基本のマニフェストを作ってみる

これぐらいの設定で、StatefulSetでのマニフェストを考えてみましょう。
するとこんな感じになると思います。

```{literalinclude} src/ss-db-1st.yml
:caption: ss-db.yaml
:language: yaml
```

```{code-block}
:caption: データベース部分の適用と確認

$ kubectl apply -f ss-db.yml
$ kubectl get statefulset,pod

NAME                  READY   AGE
statefulset.apps/db   1/1     11m

NAME       READY   STATUS    RESTARTS   AGE
pod/db-0   1/1     Running   0          77s
```

これでデータベースのStatefulSetが作成されました。

## サービスを作ってみる

では、次にデータベース向けのサービスを作成しましょう。
Pod間での接続しかありませんので、ClusterIPで接続すればいいので、こうなります。

```{literalinclude} src/svc-db.yml
:caption: svc-db.yml
:language: yaml
```

こちらも同様に適用し、確認してみましょう。

```{code-block}
:caption: データベースのサービス作成と確認

$ kubectl apply -f svc-db.yml
$ kubectl get svc
NAME         TYPE        CLUSTER-IP        EXTERNAL-IP   PORT(S)    AGE
kubernetes   ClusterIP   192.168.194.129   <none>        443/TCP    2d18h
db           ClusterIP   192.168.194.157   <none>        3306/TCP   72s
```

実際に疎通できるかですが、他のPodを一時的に起動して接続してみるといいでしょう。

```{code-block}
:caption: データベースへの接続テスト
:language: bash

$ kubectl run -it --rm --image=alpine -- bash
/ # nc -z -v  -w1 db 3306       # nc(netcat)で単純接続
db (192.168.194.157:3306) open  <- これが出ればOK
/ # apk add --no-cache mariadb-client mariadb-connector-c
/ # mysqladmin ping -u appuser --password=apppass -h db
mysqld is alive <- これがでればOK
/ # exit
```

```{note}
{command}`kubectl run`は現在では非推奨のため、そのうち使えなくなる可能性はありますが、
一時的にPodを起動してコマンドを実行するのに便利なので、ここでは使っています。

- {command}`nc` コマンドで、指定ポートへの接続を単純にテストしています
    - `-z`: 接続のみ行う
    - `-v`: 詳細表示(接続できたかが表示される)
    - `-w1`: タイムアウト時間(1秒)
- {command}`mysqladmin`コマンドは、`mariadb-client`パッケージでインストールしています
    - 依存関係で`mariadb-connector-c`も入れる必要があります
```


## サービス起動のウェイトを付ける

授業内でも述べているように、MySQLのサーバーは、起動をしてもすぐにクエリを受け付けるわけではありません。そのため、StatefulSetのPodが起動しても、すぐにアプリケーションが接続しようとすると、エラーになることがあります。

そのため、プローブを導入して、外部への受付ができるまではサービス側も待つようにした方がいいでしょう。

ということで、サービスにプローブ(リーディネスプローブ)を追加してみましょう。

```{literalinclude} src/ss-db.yml
:diff: src/ss-db-1st.yml
:caption: ss-db.yml(差分) プローブの追加
```

プローブを導入したので、再度適用を試みますが、ここでツールを一つ紹介。
{command}`kubectl endpoints` というものがあります。
サービスを渡すことで、そのサービスに割り付けられたアドレスを表示してくれます。
サービスが紐付け対象となるPodが無いときには、割り付けが無くなりますし、プローブを導入した場合は、プローブが成功するまでは割り当てが発生しません。

```{code-block}
:caption: エンドポイント確認とサービス適用(1/2)

$ kubectl get endpoints db # 現状確認
NAME   ENDPOINTS            AGE
db     192.168.194.4:3306   65m <- 割り当てあり

$ kubectl delete statefulset/db pvc/db-data-db-0 # リソース削除

NAME   ENDPOINTS   AGE
db     <none>      67m <- 削除後に見ると割り当て無しになる
```

ここで、端末をひとつ追加し、片方の端末でendpointsの監視を行います。

```{code-block}
:caption: エンドポイント確認とサービス適用(2/2 端末1)

$ kubectl get endpoints -w db
NAME   ENDPOINTS   AGE
db     <none>      68m
```

この状態で変化待ちとなるので、もうひとつの端末でStatefulSetを再適用してみます。

```{code-block}
:caption: エンドポイント確認とサービス適用(2/2 端末2)

$ kubectl apply -f ss-db.yml
$ kubectl get pods -w # Podレベルでの状態待ち観測
statefulset.apps/db created
NAME   READY   STATUS    RESTARTS   AGE
db-0   0/1     Pending   0          1s
db-0   0/1     Pending   0          7s
db-0   0/1     ContainerCreating   0          7s
db-0   0/1     Running             0          9s
db-0   1/1     Running             0          47s <- 起動完了
```

しばらくして、READYが1/1になったところで、サービス側にも変化が生じます。

```{code-block}
:caption: エンドポイント確認とサービス適用(2/2 端末1)
:emphasize-lines: 4-5

kubectl get endpoints -w db
NAME   ENDPOINTS   AGE
db     <none>      68m
db                 70m
db     192.168.194.7:3306   71m
```

このように、サービスの紐付けが行われ、エンドポイントが割り当てられることが確認できます。
他のコンテナに正常に接続できるようにするためにも、提供できないときはサービスを閉じておく等も必要です。
