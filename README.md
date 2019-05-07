# showroom-live
Automation watch for showroom live


いつ配信になるかわからないshowroom live動画を
確実に視聴できるようにするためのPowerShellスクリプトです。

Windows環境とLinux(PowerShell Core)環境でshowroom-live.ps1スクリプトは動作します。

Windows環境で使う場合は、showroom-live-ringo_kujo.bat に示したような形で起動用バッチファイルを作ると良いでしょう。


## 必要なもの
必ず必要
[streamlink](https://github.com/streamlink/streamlink)

視聴する場合に追加で必要
[VLC](https://www.videolan.org/)

## 使い方
#### 配信が始まったらVLCが起動して視聴を開始する
~~~
showroom-live.ps1 -roomurl 配信者ROOMURL
~~~

#### 配信が始まったら画面には出さずファイルに保存する
~~~
showroom-live.ps1 -roomurl 配信者ROOMURL -output -outdir "出力先ディレクトリ"
~~~
ファイル名はROOMIDに日時をつけたものを自動生成します。
なお、ルーム名にしていないのは、ファイル名にできない文字列をルーム名に指定していることが多いためです。

"-outdir"オプションをつけない場合、Windows環境ではマイビデオ、Linux環境では~/Video/ (RHEL7風)に出力します。
指定したディレクトリが存在しない場合の処理については実装していません。

## 使い方の応用
VLCには "--sout"オプションというものがあり、受信したデータを再送信する機能があります。
例えばstremalinkを `streamlink https://www.showroom-live.com/ringo-005 best --player="cvlc --sout '#rtp{sdp=rtsp://:8554/}'"` という感じで実行するとポート8554番でrtspサーバを立てることができます。
このURLを直接指定、もしくは、m3uファイルなどで間接的に読み込むことで、kodiなどのより多くのプレイヤーで視聴することも可能となります。

