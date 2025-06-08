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
    local ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
    
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
    local ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
    
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
    # HotSpotはOracle Java SEの特徴の一つだが、それだけでは不十分
    if ! echo "$java_info" | grep -i "HotSpot" > /dev/null; then
        return 1
    fi
    
    # Oracle Java SEの特徴的な識別子を確認
    for pattern in "${ORACLE_JAVA_PATTERNS[@]}"; do
        if echo "$java_info" | grep -iE "$pattern" > /dev/null; then
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
    
    if is_oracle_java "$java_info"; then
        echo -e "${GREEN}Oracle Java SE が検出されました${NC}"
        echo "バージョン: $java_version"
        echo "ベンダー情報:"
        echo "$java_info" | while read -r line; do
            echo "  $line"
        done
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
        if [[ "$JAVA_HOME" == *"oracle"* ]] || [[ "$JAVA_HOME" == *"Oracle"* ]]; then
            echo -e "${GREEN}JAVA_HOMEはOracle Java SEを指しています${NC}"
            found_count+=1
        else
            echo -e "$MSG_NOT_ORACLE"
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
    find "/" -name "java" -type f -executable 2>/dev/null | while read -r java_path; do
        if [ -x "$java_path" ] && [ -f "$java_path" ]; then
            local dir=$(dirname "$java_path")
            if ! is_system_bin_dir "$dir"; then
                if check_oracle_java "$java_path"; then
                    found_oracle=1
                    found_count+=1
                    echo -e "${GREEN}Oracle Java SE を検出:${NC}"
                    echo "  場所: $java_path"
                    echo "  バージョン情報:"
                    "$java_path" -version 2>&1 | while read -r line; do
                        echo "    $line"
                    done
                    echo "$MSG_SEPARATOR"
                fi
            fi
        fi
    done

    if [ $found_oracle -eq 0 ]; then
        echo -e "$MSG_NO_ORACLE_JAVA"
        echo "$MSG_SEPARATOR"
    fi
}

# Oracle Javaの確認と情報表示
check_oracle_java() {
    local java_path=$1
    local java_info=$("$java_path" -version 2>&1)
    
    if is_oracle_java "$java_info"; then
        return 0
    fi
    return 1
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
    echo -e "\n=== 検出結果サマリー ==="
    echo "検証対象ホスト:"
    echo "  ホスト名: $(hostname)"
    local ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$ip_address" ]; then
        echo "  IPアドレス: $ip_address"
    fi
    echo "  プラットフォーム: $(uname -s)"
    echo "$MSG_SEPARATOR"
    
    echo "検査結果:"
    echo "  1. パス（PATH）上のJava実行ファイル: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}検出${NC}"; else echo -e "${RED}未検出${NC}"; fi)"
    echo "  2. JAVA_HOME環境変数: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}検出${NC}"; else echo -e "${RED}未検出${NC}"; fi)"
    echo "  3. パッケージマネージャー: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}検出${NC}"; else echo -e "${RED}未検出${NC}"; fi)"
    echo "  4. ファイルシステム全体: $(if [ $found_count -gt 0 ]; then echo -e "${GREEN}検出${NC}"; else echo -e "${RED}未検出${NC}"; fi)"
    echo "$MSG_SEPARATOR"
    
    if [ $found_count -gt 0 ]; then
        echo -e "${GREEN}Oracle Java SEが検出されました${NC}"
        echo "検出数: $found_count"
    else
        echo -e "${RED}Oracle Java SEは検出されませんでした${NC}"
    fi
    echo "$MSG_SEPARATOR"
}

# メイン処理
main() {
    # システム情報の表示
    local platform=$(uname -s)
    local hostname=$(hostname 2>/dev/null)
    local ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    if [ -z "$hostname" ]; then
        handle_error "ホスト名の取得に失敗しました"
        exit 1
    fi
    
    echo "ホスト名: $hostname"
    if [ -n "$ip_address" ]; then
        echo "IPアドレス: $ip_address"
    fi
    
    # パッケージマネージャーの検出
    local detected_pkg_mgr=""
    for pkg_mgr in "${PACKAGE_MANAGERS[@]}"; do
        IFS=':' read -r name cmd <<< "$pkg_mgr"
        if command -v "$name" &> /dev/null; then
            detected_pkg_mgr="$name"
            break
        fi
    done
    
    # ディストリビューション名の表示
    echo "$(get_distribution "$platform" "$detected_pkg_mgr")"
    echo "$MSG_SEPARATOR"
    
    # 3種類の検査を実行
    check_system_java
    check_java_home
    show_platform_specific_info "$platform"
    
    # ファイルシステム検索前の確認
    if [ $found_count -eq 0 ]; then
        echo "4. ファイルシステム全体でのOracle Java SE実行ファイルの検索:"
        echo "$MSG_SEPARATOR"
        echo "この検索は時間がかかる場合があります。"
        echo
        read -p "検索を実行しますか？ (y/N): " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                search_custom_java
                ;;
            *)
                echo "ファイルシステムの検索をスキップしました。"
                ;;
        esac
    fi
    
    show_summary
}

# スクリプトの実行
main 