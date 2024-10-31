# シンプルなデプロイメントとサービスの作成

では、作成したイメージを利用する形で、K8sのデプロイメントによる公開を行ってみましょう。

## デプロイメントの作成

スニペットを使って、デプロイメントのマニフェストファイルを作成します。

```{literalinclude} src/deploy-app-simple.yml
:language: yaml
```

これまで見てきたデプロイメントと変わりありませんが一応補足をしておきます。

- イメージ名は先程pushしているDocker Hub上のイメージを使用します、サンプルではユーザー名の部分が含まれていませんので、適宜書き換えてください
- ポート番号はLaravel(`artisan serve`)のデフォルトである8000番を指定した状態になってます

実際に適用し、様子を見てみましょう。

```bash
$ kubectl apply -f deploy-app-sample.yml
deployment.apps/laravel-app created
```

完了したら、デプロイメントの状態とポッドの状態ぐらいは見ておきましょう。

```bash
$ kubectl get deploy,pod # カンマ(,)で区切ると複数のリソース種別を渡せます
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/laravel-app   1/1     1            1           4m29s

NAME                               READY   STATUS    RESTARTS   AGE
pod/laravel-app-77cb9956bb-bq275   1/1     Running   0          4m29s
```

特に難しい事をしていませんから、問題無くデプロイメントは完了しています。
とりあえずポートフォワードで確認してみましょう。

```bash
$ kubectl port-forward deployment/laravel-app 8000:8000
```

これで http://127.0.0.1:8000/ でアクセスできると思います。
確認したらポートフォワードは停止しておきましょう。

## サービスの作成

サービスの作成は、先程のデプロイメントをひっかける形でノードポートで作成すればいいでしょう。

```{literalinclude} src/service-app-simple.yml
:language: yaml
```

こちらも適用してみます。

```bash
$ kubectl apply -f service-app-sample.yml
service/laravel-app created
$ kubectl get svc
NAME          TYPE        CLUSTER-IP        EXTERNAL-IP   PORT(S)          AGE
kubernetes    ClusterIP   192.168.194.129   <none>        443/TCP          41h
laravel-app   NodePort    192.168.194.145   <none>        8080:30928/TCP   3s
```

この場合は、30928が転送ポートになっているので、 http://127.0.0.1:30928/ でアクセスできます。
