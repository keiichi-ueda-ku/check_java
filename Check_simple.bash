#!/bin/bash

# スクリプトの目的:
# このスクリプトは、Linuxサーバ上でOracle Javaがインストールされているかどうかを
# 確認し、インストールされている場合はその場所を表示します。スクリプトはroot権限
# で実行する必要があります。

# 使い方:
# 1. スクリプトを実行するサーバにコピーします。
# 2. ターミナルを開きます。
# 3. スクリプトを実行します: sudo ./check_oracle_java.sh [-L]

# オプション:
# -L: シンボリックリンクをたどって検索します。

# root権限で実行されているか確認
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# シンボリックリンクをたどるかどうかのオプションを設定
follow_symlinks=false
if [[ "$1" == "-L" ]]; then
    follow_symlinks=true
fi

# Oracle Javaのインストールを確認する関数
check_java() {
    echo "Searching for Java installations, please wait..."
    if $follow_symlinks; then
        java_paths=$(find / -L -type f -name "java" -executable 2>/dev/null)
    else
        java_paths=$(find / -type f -name "java" -not -type l -executable 2>/dev/null)
    fi

    if [[ -z "$java_paths" ]]; then
        echo "Java is not installed"
    else
        for path in $java_paths; do
            if "$path" -version 2>&1 | grep -qE "Java HotSpot|Oracle"; then
                echo "Oracle Java found at \"$path\""
            else
                echo "Java found at \"$path\" but not Oracle Java"
            fi
        done
    fi
}

# Javaのインストールをチェック
check_java

