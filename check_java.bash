#!/bin/bash

# 定数の定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Oracle Java SEの検出パターン
readonly ORACLE_JAVA_PATTERNS=(
    "Java\(TM\) SE Runtime Environment"
    "Java\(TM\) Platform, Standard Edition"
    "Oracle Corporation"
    "Oracle Java SE"
)

# システムのbinディレクトリ
readonly SYSTEM_BIN_DIRS=("/bin" "/usr/bin")

# パッケージマネージャーの定義
readonly PACKAGE_MANAGERS=(
    "rpm:rpm -qa"
    "apt:apt list --installed 2>/dev/null"
    "dpkg:dpkg -l"
    "pkginfo:pkginfo"
    "lslpp:lslpp -l"
    "swlist:swlist"
    "pkg_info:pkg_info"
)

# メッセージの定義
readonly MSG_NO_ORACLE_JAVA="${YELLOW}Oracle Java SEは検出されませんでした${NC}"
readonly MSG_FOUND_ORACLE_JAVA="${GREEN}Oracle Java SEパッケージを検出:${NC}"
readonly MSG_SEARCHING="検索中:"
readonly MSG_SEPARATOR="----------------------------------------"
readonly MSG_ERROR="${RED}エラー:${NC}"
readonly MSG_NOT_ORACLE="${YELLOW}現在のJavaはOracle Java SEではありません${NC}"

# 検出結果のカウンター
declare -i found_count=0

# エラー処理
handle_error() {
    local error_msg=$1
    echo -e "${MSG_ERROR} $error_msg" >&2
    return 1
}

# システム情報の取得
get_system_info() {
    local platform=$(uname -s)
    local hostname=$(hostname 2>/dev/null)
    local ip_address=$(hostname -I 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$hostname" ]; then
        handle_error "ホスト名の取得に失敗しました"
        return 1
    fi
    
    echo "ホスト名: $hostname"
    if [ -n "$ip_address" ]; then
        echo "IPアドレス: $ip_address"
    fi
    echo "$platform"
}

# 実行確認
confirm_execution() {
    local hostname=$(hostname)
    local ip_address=$(hostname -I 2>/dev/null | cut -d' ' -f1)
    
    echo "=== 実行確認 ==="
    echo "ホスト名: $hostname"
    if [ -n "$ip_address" ]; then
        echo "IPアドレス: $ip_address"
    fi
    echo
    echo "このホストでOracle Java SEの検索を実行します。"
    echo "検索には時間がかかる場合があります。"
    echo
    read -p "実行を続行しますか？ (y/N): " answer
    case "$answer" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            echo "実行を中止しました。"
            exit 1
            ;;
    esac
}

# Oracle Java SEの検出
is_oracle_java() {
    local java_info=$1
    local java_path=$2
    
    # HotSpotはOracle Java SEの特徴の一つだが、それだけでは不十分
    if ! echo "$java_info" | grep -i "HotSpot" > /dev/null; then
        return 1
    fi
    
    # Oracle Java SEの特徴的な識別子を確認
    for pattern in "${ORACLE_JAVA_PATTERNS[@]}"; do
        if echo "$java_info" | grep -iE "$pattern" > /dev/null; then
            if [ -n "$java_path" ]; then
                echo -e "${GREEN}Oracle Java SE を検出:${NC}"
                echo "  場所: $java_path"
                echo "  バージョン情報:"
                echo "$java_info" | while read -r line; do
                    echo "    $line"
                done
                echo "$MSG_SEPARATOR"
            fi
            return 0
        fi
    done
    return 1
}

# システムのJava確認
check_system_java() {
    echo "1. パス（PATH）上のJava実行ファイルの確認:"
    if ! command -v java &> /dev/null; then
        echo -e "$MSG_NO_ORACLE_JAVA"
        echo "$MSG_SEPARATOR"
        return 1
    fi

    local java_info
    java_info=$(java -version 2>&1) || handle_error "Javaのバージョン情報の取得に失敗しました"
    local java_version=$(echo "$java_info" | awk -F '"' '/version/ {print $2}')
    
    if is_oracle_java "$java_info" "$(which java)"; then
        found_count+=1
    else
        echo -e "$MSG_NOT_ORACLE"
        echo "バージョン: $java_version"
        echo "ベンダー情報:"
        echo "$java_info" | while read -r line; do
            echo "  $line"
        done
    fi
    echo "$MSG_SEPARATOR"
}

# JAVA_HOMEの確認
check_java_home() {
    echo "2. JAVA_HOME環境変数が指すJavaの確認:"
    if [ -n "$JAVA_HOME" ]; then
        echo "JAVA_HOME: $JAVA_HOME"
        if [ -x "$JAVA_HOME/bin/java" ]; then
            local java_info=$("$JAVA_HOME/bin/java" -version 2>&1)
            if is_oracle_java "$java_info" "$JAVA_HOME/bin/java"; then
                found_count+=1
            else
                echo -e "$MSG_NOT_ORACLE"
            fi
        else
            echo -e "$MSG_NO_ORACLE_JAVA"
        fi
    else
        echo -e "$MSG_NO_ORACLE_JAVA"
    fi
    echo "$MSG_SEPARATOR"
}

# パッケージマネージャーでのOracle Java SE検索
check_package_manager() {
    local package_manager=$1
    local command=$2

    echo "3. パッケージマネージャー（$package_manager）によるOracle Java SEパッケージの確認:"
    local found_packages=""
    
    # パッケージの検索
    for pattern in "${ORACLE_JAVA_PATTERNS[@]}"; do
        local packages
        packages=$($command 2>/dev/null | grep -iE "$pattern") || continue
        if [ -n "$packages" ]; then
            found_packages="$found_packages
$packages"
        fi
    done

    if [ -n "$found_packages" ]; then
        echo -e "$MSG_FOUND_ORACLE_JAVA"
        echo "$found_packages" | while read -r package; do
            if [ -n "$package" ]; then
                echo "  $package"
                found_count+=1
            fi
        done
    else
        echo -e "$MSG_NO_ORACLE_JAVA"
    fi
    echo "$MSG_SEPARATOR"
}

# システムのbinディレクトリかどうかを確認
is_system_bin_dir() {
    local dir=$1
    for bin_dir in "${SYSTEM_BIN_DIRS[@]}"; do
        if [[ "$dir" == *"$bin_dir"* ]]; then
            return 0
        fi
    done
    return 1
}

# カスタムJavaの検索
search_custom_java() {
    local found_oracle=0
    
    # updatedbが利用可能な場合はlocateを使用
    if command -v updatedb &> /dev/null && command -v locate &> /dev/null; then
        echo "locateを使用して検索を高速化します..."
        sudo updatedb
        locate java | while read -r java_path; do
            if [ -x "$java_path" ] && [ -f "$java_path" ]; then
                local dir=$(dirname "$java_path")
                if ! is_system_bin_dir "$dir"; then
                    local java_info=$("$java_path" -version 2>&1)
                    if is_oracle_java "$java_info" "$java_path"; then
                        found_oracle=1
                        found_count+=1
                    fi
                fi
            fi
        done
    else
        # locateが利用できない場合はfindを使用
        find "/" -name "java" -type f -executable 2>/dev/null | while read -r java_path; do
            if [ -x "$java_path" ] && [ -f "$java_path" ]; then
                local dir=$(dirname "$java_path")
                if ! is_system_bin_dir "$dir"; then
                    local java_info=$("$java_path" -version 2>&1)
                    if is_oracle_java "$java_info" "$java_path"; then
                        found_oracle=1
                        found_count+=1
                    fi
                fi
            fi
        done
    fi

    if [ $found_oracle -eq 0 ]; then
        echo -e "$MSG_NO_ORACLE_JAVA"
        echo "$MSG_SEPARATOR"
    fi
}

# ディストリビューションの判定
get_distribution() {
    local platform=$1
    local package_manager=$2
    
    case "$package_manager" in
        "apt")
            echo "Ubuntu/Debian"
            ;;
        "rpm")
            echo "RHEL/CentOS"
            ;;
        "pkginfo")
            echo "Oracle Solaris"
            ;;
        "lslpp")
            echo "IBM AIX"
            ;;
        "swlist")
            echo "HP-UX"
            ;;
        "pkg_info")
            echo "macOS"
            ;;
        *)
            echo "$platform"
            ;;
    esac
}

# プラットフォーム固有の情報表示
show_platform_specific_info() {
    local platform=$1
    
    case $platform in
        "Linux")
            for pkg_mgr in "${PACKAGE_MANAGERS[@]}"; do
                IFS=':' read -r name cmd <<< "$pkg_mgr"
                if command -v "$name" &> /dev/null; then
                    check_package_manager "$name" "$cmd"
                    break
                fi
            done
            ;;
        "SunOS")
            if command -v pkginfo &> /dev/null; then
                check_package_manager "pkginfo" "pkginfo"
            fi
            ;;
        "AIX")
            if command -v lslpp &> /dev/null; then
                check_package_manager "lslpp" "lslpp -l"
            fi
            ;;
        "HP-UX")
            if command -v swlist &> /dev/null; then
                check_package_manager "swlist" "swlist"
            fi
            ;;
        "Darwin")
            if command -v pkg_info &> /dev/null; then
                check_package_manager "pkg_info" "pkg_info"
            fi
            ;;
    esac
}

# 検出結果のサマリー表示
show_summary() {
    echo -e "\n=== Detection Results Summary (検出結果サマリー) ==="
    echo "Target Host (検証対象ホスト):"
    echo "  Hostname (ホスト名): $(hostname)"
    local ip_address=$(hostname -I 2>/dev/null | cut -d' ' -f1)
    if [ -n "$ip_address" ]; then
        echo "  IP Address (IPアドレス): $ip_address"
    fi
    echo "  Platform (プラットフォーム): $(uname -s)"
    echo "$MSG_SEPARATOR"
    
    echo "Check Results (検査結果):"
    echo "  1. Java in PATH: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}Detected${NC} (検出)"; else echo -e "${RED}Not Detected${NC} (未検出)"; fi)"
    echo "  2. Java in JAVA_HOME: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}Detected${NC} (検出)"; else echo -e "${RED}Not Detected${NC} (未検出)"; fi)"
    echo "  3. Package Manager: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}Detected${NC} (検出)"; else echo -e "${RED}Not Detected${NC} (未検出)"; fi)"
    echo "  4. File System Search: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}Detected${NC} (検出)"; else echo -e "${RED}Not Detected${NC} (未検出)"; fi)"
    echo "$MSG_SEPARATOR"
    
    if [ $found_count -gt 0 ]; then
        echo -e "${GREEN}Oracle Java SE detected${NC} (Oracle Java SEが検出されました)"
        echo "Detection Count (検出数): $found_count"
    else
        echo -e "${RED}No Oracle Java SE detected${NC} (Oracle Java SEは検出されませんでした)"
    fi
    echo "$MSG_SEPARATOR"
}

# メイン処理
main() {
    # システム情報の表示
    local platform=$(uname -s)
    local hostname=$(hostname 2>/dev/null)
    local ip_address=$(hostname -I 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$hostname" ]; then
        handle_error "ホスト名の取得に失敗しました"
        exit 1
    fi
    
    echo "検証対象ホスト情報:"
    echo "ホスト名: $hostname"
    if [ -n "$ip_address" ]; then
        echo "IPアドレス: $ip_address"
    fi
    echo "プラットフォーム: $platform"
    echo "$MSG_SEPARATOR"

    # パッケージマネージャーの検出
    local package_manager
    local command
    if command -v apt &>/dev/null; then
        package_manager="apt"
        command="apt list --installed"
    elif command -v rpm &>/dev/null; then
        package_manager="rpm"
        command="rpm -qa"
    elif command -v pkginfo &>/dev/null; then
        package_manager="pkginfo"
        command="pkginfo"
    elif command -v lslpp &>/dev/null; then
        package_manager="lslpp"
        command="lslpp -L"
    elif command -v swlist &>/dev/null; then
        package_manager="swlist"
        command="swlist"
    elif command -v pkg_info &>/dev/null; then
        package_manager="pkg_info"
        command="pkg_info"
    fi

    # 各チェックの実行
    check_system_java
    check_java_home
    if [ -n "$package_manager" ]; then
        check_package_manager "$package_manager" "$command"
    fi

    # ファイルシステム検索の確認
    if [ $found_count -eq 0 ]; then
        echo "これまでの確認でOracle Java SEは検出されませんでした。"
        echo "ファイルシステム全体でのOracle Java SE実行ファイルの検索を実行しますか？"
        echo "※ この検索には時間がかかる場合があります"
        read -p "検索を実行しますか？ (y/N): " answer
        if [[ $answer =~ ^[Yy]$ ]]; then
            search_custom_java
        fi
    fi

    # 結果の表示
    show_summary
}

# スクリプトの実行
main 