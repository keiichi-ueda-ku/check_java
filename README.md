# Oracle Java SE 検出スクリプト

このスクリプトは、システム上にOracle Java SEがインストールされているかどうかを検出するためのツールです。

## 機能

1. パス（PATH）上のJava実行ファイルの確認
2. JAVA_HOME環境変数が指すJavaの確認
3. パッケージマネージャーによるOracle Java SEパッケージの確認
4. ファイルシステム全体でのOracle Java SE実行ファイルの検索（オプション）

## 使用方法

1. スクリプトに実行権限を付与:
```bash
chmod +x check_java.bash
```

2. スクリプトを実行:
```bash
sudo ./check_java.bash
```

## 出力例

```
検証対象ホスト情報:
ホスト名: DESKTOP-IHCL2ML
IPアドレス: 172.18.202.35
プラットフォーム: Linux
----------------------------------------
1. パス（PATH）上のJava実行ファイルの確認:
Oracle Java SEは検出されませんでした
----------------------------------------
2. JAVA_HOME環境変数が指すJavaの確認:
Oracle Java SEは検出されませんでした
----------------------------------------
3. パッケージマネージャー（apt）によるOracle Java SEパッケージの確認:
Oracle Java SEは検出されませんでした
----------------------------------------
これまでの確認でOracle Java SEは検出されませんでした。
ファイルシステム全体でのOracle Java SE実行ファイルの検索を実行しますか？
※ この検索には時間がかかる場合があります
検索を実行しますか？ (y/N): y
Oracle Java SEは検出されませんでした
----------------------------------------

=== Detection Results Summary (検出結果サマリー) ===
Target Host (検証対象ホスト):
  Hostname (ホスト名): DESKTOP-IHCL2ML
  IP Address (IPアドレス): 172.18.202.35
  Platform (プラットフォーム): Linux
----------------------------------------
Check Results (検査結果):
  1. Java in PATH: Not Detected (未検出)
  2. Java in JAVA_HOME: Not Detected (未検出)
  3. Package Manager: Not Detected (未検出)
  4. File System Search: Not Detected (未検出)
----------------------------------------
No Oracle Java SE detected (Oracle Java SEは検出されませんでした)
----------------------------------------
```

## 注意事項

- スクリプトの実行には管理者権限（sudo）が必要です
- ファイルシステム全体の検索は時間がかかる場合があります
- 検索を実行するかどうかは、ユーザーが選択できます

## 対応プラットフォーム

- Linux (apt, rpm)
- Oracle Solaris (pkginfo)
- IBM AIX (lslpp)
- HP-UX (swlist)
- macOS (pkg_info)

## 検出方法の詳細

1. パス（PATH）上のJava実行ファイルの確認
   - システムのPATHに設定されているJava実行ファイルを確認
   - バージョン情報とベンダー情報を解析

2. JAVA_HOME環境変数が指すJavaの確認
   - JAVA_HOME環境変数が設定されている場合、そのパスを確認
   - Oracle Java SEを指しているかどうかを判定

3. パッケージマネージャーによるOracle Java SEパッケージの確認
   - システムのパッケージマネージャーを使用してインストール済みパッケージを確認
   - Oracle Java SEに関連するパッケージを検索

4. ファイルシステム全体でのOracle Java SE実行ファイルの検索
   - 上記の3種類の検査でOracle Java SEが見つからない場合に実行
   - システム全体を検索してOracle Java SEの実行ファイルを探す
   - 時間がかかる可能性があるため、実行前に確認を求める

## 検出結果サマリー

スクリプトは最後に検出結果のサマリーを表示します：

1. 検証対象ホストの情報
   - ホスト名
   - IPアドレス
   - プラットフォーム

2. 各検査の結果
   - 4種類の検査それぞれの結果（検出/未検出）

3. 最終的な検出結果
   - Oracle Java SEの検出有無
   - 検出された場合は検出数も表示

## ライセンス

MIT License

## 付録：Oracle Java SEのアンインストール手順（Ubuntu）

### 手動インストールの場合

1. JAVA_HOMEの設定を削除
```bash
# .bashrcから以下の行を削除
export JAVA_HOME=/usr/lib/jvm/jdk-*
export PATH=$JAVA_HOME/bin:$PATH
```

2. インストールディレクトリの削除
```bash
sudo rm -rf /usr/lib/jvm/jdk-*
```

3. 設定の反映
```bash
source ~/.bashrc
```

### 注意事項

- アンインストール前に、Oracle Java SEに依存するアプリケーションがないことを確認してください
- システムのJava環境に影響を与える可能性があります
- 必要に応じて、代替のJavaディストリビューション（OpenJDKなど）をインストールすることを検討してください
