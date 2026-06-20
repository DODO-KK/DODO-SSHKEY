#!/bin/sh

set -eu

# DODO SSH key import and hardening script.
#
# Environment knobs:
#   DODO_INSTALL_KEYS=1
#   DODO_USER=root
#   DODO_KEY_URL=https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/authorized_keys
#   DODO_DISABLE_PASSWORD_LOGIN=1
#   DODO_ENABLE_FAIL2BAN=1
#   DODO_ENABLE_ABUSE_REPORTS=0
#   DODO_SPAMHAUS_REPORT_TO=
#   DODO_DISABLE_TCP_FORWARDING=0
#   DODO_CHANGE_SSH_PORT=1
#   DODO_SSH_PORT=10022
#   DODO_KEEP_OLD_SSH_PORT=1
#   DODO_CONFIGURE_PVE_FIREWALL=0
#   DODO_LANG=en|ja
#   DODO_NONINTERACTIVE=0|1

DODO_INSTALL_KEYS="${DODO_INSTALL_KEYS:-1}"
DODO_USER="${DODO_USER:-root}"
DODO_KEY_URL="${DODO_KEY_URL:-https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/authorized_keys}"
DODO_DISABLE_PASSWORD_LOGIN="${DODO_DISABLE_PASSWORD_LOGIN:-1}"
DODO_ENABLE_FAIL2BAN="${DODO_ENABLE_FAIL2BAN:-1}"
DODO_ENABLE_ABUSE_REPORTS="${DODO_ENABLE_ABUSE_REPORTS:-0}"
DODO_SPAMHAUS_REPORT_TO="${DODO_SPAMHAUS_REPORT_TO:-}"
DODO_DISABLE_TCP_FORWARDING="${DODO_DISABLE_TCP_FORWARDING:-0}"
DODO_CHANGE_SSH_PORT="${DODO_CHANGE_SSH_PORT:-1}"
DODO_SSH_PORT="${DODO_SSH_PORT:-10022}"
DODO_KEEP_OLD_SSH_PORT="${DODO_KEEP_OLD_SSH_PORT:-1}"
DODO_CONFIGURE_PVE_FIREWALL="${DODO_CONFIGURE_PVE_FIREWALL:-0}"
DODO_LANG="${DODO_LANG:-}"
DODO_NONINTERACTIVE="${DODO_NONINTERACTIVE:-0}"

PLATFORM="linux"
OS_ID="unknown"
OS_NAME="unknown"
PKG_MANAGER=""
SSH_IMPL="openssh"
UI_TOOL=""

log() {
    printf '%s\n' "[DODO-SSHKEY] $*"
}

warn() {
    printf '%s\n' "[DODO-SSHKEY][WARN] $*" >&2
}

die() {
    printf '%s\n' "[DODO-SSHKEY][ERROR] $*" >&2
    exit 1
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

can_prompt() {
    [ "$DODO_NONINTERACTIVE" != "1" ] && [ -r /dev/tty ] && [ -w /dev/tty ]
}

detect_ui_tool() {
    UI_TOOL=""
    can_prompt || return 0

    if have_cmd whiptail; then
        UI_TOOL="whiptail"
    elif have_cmd dialog; then
        UI_TOOL="dialog"
    fi
}

ui_menu() {
    title="$1"
    text="$2"
    height="$3"
    width="$4"
    menu_height="$5"
    shift 5

    if [ "$UI_TOOL" = "whiptail" ]; then
        whiptail --backtitle "Package configuration" --title "$title" --menu "$text" "$height" "$width" "$menu_height" "$@" 3>&1 1>&2 2>&3 </dev/tty
    elif [ "$UI_TOOL" = "dialog" ]; then
        dialog --backtitle "Package configuration" --title "$title" --menu "$text" "$height" "$width" "$menu_height" "$@" 3>&1 1>&2 2>&3 </dev/tty
    else
        return 127
    fi
}

ui_yesno() {
    title="$1"
    text="$2"
    height="$3"
    width="$4"
    default="${5:-1}"
    default_arg=""
    [ "$default" = "0" ] && default_arg="--defaultno"

    if [ "$UI_TOOL" = "whiptail" ]; then
        # shellcheck disable=SC2086
        whiptail --backtitle "Package configuration" --title "$title" $default_arg --yesno "$text" "$height" "$width" </dev/tty
    elif [ "$UI_TOOL" = "dialog" ]; then
        # shellcheck disable=SC2086
        dialog --backtitle "Package configuration" --title "$title" $default_arg --yesno "$text" "$height" "$width" </dev/tty
    else
        return 127
    fi
}

ui_inputbox() {
    title="$1"
    text="$2"
    default="$3"
    height="$4"
    width="$5"

    if [ "$UI_TOOL" = "whiptail" ]; then
        whiptail --backtitle "Package configuration" --title "$title" --inputbox "$text" "$height" "$width" "$default" 3>&1 1>&2 2>&3 </dev/tty
    elif [ "$UI_TOOL" = "dialog" ]; then
        dialog --backtitle "Package configuration" --title "$title" --inputbox "$text" "$height" "$width" "$default" 3>&1 1>&2 2>&3 </dev/tty
    else
        return 127
    fi
}

ui_msgbox() {
    title="$1"
    text="$2"
    height="$3"
    width="$4"

    if [ "$UI_TOOL" = "whiptail" ]; then
        whiptail --backtitle "Package configuration" --title "$title" --msgbox "$text" "$height" "$width" </dev/tty
    elif [ "$UI_TOOL" = "dialog" ]; then
        dialog --backtitle "Package configuration" --title "$title" --msgbox "$text" "$height" "$width" </dev/tty
    else
        return 127
    fi
}

tty_print() {
    printf '%s\n' "$*" >/dev/tty
}

tty_prompt() {
    prompt="$1"
    default="$2"
    answer=""

    if [ -n "$default" ]; then
        printf '%s [%s]: ' "$prompt" "$default" >/dev/tty
    else
        printf '%s: ' "$prompt" >/dev/tty
    fi

    IFS= read -r answer </dev/tty || answer=""
    [ -n "$answer" ] || answer="$default"
    printf '%s\n' "$answer"
}

prompt_yes_no() {
    prompt="$1"
    default="$2"

    while :; do
        if [ "$DODO_LANG" = "ja" ]; then
            if [ "$default" = "1" ]; then
                answer="$(tty_prompt "$prompt (y/n)" "y")"
            else
                answer="$(tty_prompt "$prompt (y/n)" "n")"
            fi
        else
            if [ "$default" = "1" ]; then
                answer="$(tty_prompt "$prompt (y/n)" "y")"
            else
                answer="$(tty_prompt "$prompt (y/n)" "n")"
            fi
        fi

        case "$answer" in
            y|Y|yes|YES|Yes) return 0 ;;
            n|N|no|NO|No) return 1 ;;
            *) tty_print "Please enter y or n." ;;
        esac
    done
}

validate_ssh_port() {
    [ "$DODO_CHANGE_SSH_PORT" = "1" ] || return 0

    case "$DODO_SSH_PORT" in
        ''|*[!0-9]*)
            die "Invalid SSH port: $DODO_SSH_PORT"
            ;;
    esac

    if [ "$DODO_SSH_PORT" -lt 1 ] || [ "$DODO_SSH_PORT" -gt 65535 ]; then
        die "Invalid SSH port: $DODO_SSH_PORT"
    fi
}

select_language() {
    [ -n "$DODO_LANG" ] && return 0

    if ! can_prompt; then
        DODO_LANG="en"
        return 0
    fi

    if [ -n "$UI_TOOL" ]; then
        answer="$(ui_menu "Configuring dodo-sshkey" "Select display language / 表示言語を選択してください。" 13 72 2 \
            "en" "English" \
            "ja" "Japanese / 日本語")" || die "Canceled by user."
        case "$answer" in
            ja) DODO_LANG="ja" ;;
            *) DODO_LANG="en" ;;
        esac
        return 0
    fi

    tty_print ""
    tty_print "========================================"
    tty_print " DODO-SSHKEY"
    tty_print "========================================"
    tty_print "1) English"
    tty_print "2) Japanese / 日本語"

    while :; do
        answer="$(tty_prompt "Select language / 言語を選択" "1")"
        case "$answer" in
            1|en|EN|English|english) DODO_LANG="en"; return 0 ;;
            2|ja|JA|Japanese|japanese|日本語) DODO_LANG="ja"; return 0 ;;
            *) tty_print "Please select 1 or 2." ;;
        esac
    done
}

show_summary() {
    fail2ban_summary="$DODO_ENABLE_FAIL2BAN"
    if [ "$PLATFORM" = "openwrt" ] && [ "$DODO_ENABLE_FAIL2BAN" = "1" ]; then
        if [ "$DODO_LANG" = "ja" ]; then
            fail2ban_summary="1 (OpenWrt ではスキップ)"
        else
            fail2ban_summary="1 (skipped on OpenWrt)"
        fi
    fi

    if [ "$DODO_LANG" = "ja" ]; then
        tty_print ""
        tty_print "----------------------------------------"
        tty_print "設定内容"
        tty_print "----------------------------------------"
        tty_print "SSH 鍵導入: $DODO_INSTALL_KEYS"
        tty_print "対象ユーザー: $DODO_USER"
        tty_print "検出システム: $PLATFORM / $OS_NAME / $SSH_IMPL"
        tty_print "パスワードログイン無効化: $DODO_DISABLE_PASSWORD_LOGIN"
        tty_print "SSH ポート変更: $DODO_CHANGE_SSH_PORT (${DODO_SSH_PORT})"
        tty_print "旧 SSH ポート維持: $DODO_KEEP_OLD_SSH_PORT"
        if [ "$PLATFORM" = "proxmox" ]; then
            tty_print "Proxmox firewall 推奨設定: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
        tty_print "fail2ban SSH 保護: $fail2ban_summary"
        tty_print "abuse 自動通報: $DODO_ENABLE_ABUSE_REPORTS"
        tty_print "Spamhaus 追加宛先: ${DODO_SPAMHAUS_REPORT_TO:-none}"
        tty_print "TCP forwarding 無効化: $DODO_DISABLE_TCP_FORWARDING"
        tty_print "----------------------------------------"
    else
        tty_print ""
        tty_print "----------------------------------------"
        tty_print "Configuration summary"
        tty_print "----------------------------------------"
        tty_print "Import SSH keys: $DODO_INSTALL_KEYS"
        tty_print "Target user: $DODO_USER"
        tty_print "Detected system: $PLATFORM / $OS_NAME / $SSH_IMPL"
        tty_print "Disable password login: $DODO_DISABLE_PASSWORD_LOGIN"
        tty_print "Change SSH port: $DODO_CHANGE_SSH_PORT (${DODO_SSH_PORT})"
        tty_print "Keep old SSH port: $DODO_KEEP_OLD_SSH_PORT"
        if [ "$PLATFORM" = "proxmox" ]; then
            tty_print "Proxmox firewall recommended setup: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
        tty_print "fail2ban SSH protection: $fail2ban_summary"
        tty_print "Automatic abuse reports: $DODO_ENABLE_ABUSE_REPORTS"
        tty_print "Spamhaus extra destination: ${DODO_SPAMHAUS_REPORT_TO:-none}"
        tty_print "Disable TCP forwarding: $DODO_DISABLE_TCP_FORWARDING"
        tty_print "----------------------------------------"
    fi
}

summary_text() {
    fail2ban_summary="$DODO_ENABLE_FAIL2BAN"
    pve_summary=""
    if [ "$PLATFORM" = "openwrt" ] && [ "$DODO_ENABLE_FAIL2BAN" = "1" ]; then
        if [ "$DODO_LANG" = "ja" ]; then
            fail2ban_summary="1 (OpenWrt ではスキップ)"
        else
            fail2ban_summary="1 (skipped on OpenWrt)"
        fi
    fi
    if [ "$PLATFORM" = "proxmox" ]; then
        if [ "$DODO_LANG" = "ja" ]; then
            pve_summary="Proxmox firewall 推奨設定: $DODO_CONFIGURE_PVE_FIREWALL"
        else
            pve_summary="Proxmox firewall recommended setup: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
    fi

    if [ "$DODO_LANG" = "ja" ]; then
        cat <<EOF
以下の設定で実行します。

対象ユーザー: $DODO_USER
SSH 鍵導入: $DODO_INSTALL_KEYS
検出システム: $PLATFORM / $OS_NAME / $SSH_IMPL
パスワードログイン無効化: $DODO_DISABLE_PASSWORD_LOGIN
SSH ポート 10022 追加: $DODO_CHANGE_SSH_PORT
旧 SSH ポート 22 維持: $DODO_KEEP_OLD_SSH_PORT
$pve_summary
fail2ban SSH 保護: $fail2ban_summary
abuse 自動通報: $DODO_ENABLE_ABUSE_REPORTS
Spamhaus 追加宛先: ${DODO_SPAMHAUS_REPORT_TO:-none}
TCP forwarding 無効化: $DODO_DISABLE_TCP_FORWARDING

現在の SSH セッションを閉じずに、新しい接続を確認してください。
EOF
    else
        cat <<EOF
The script will run with this configuration.

Target user: $DODO_USER
Import SSH keys: $DODO_INSTALL_KEYS
Detected system: $PLATFORM / $OS_NAME / $SSH_IMPL
Disable password login: $DODO_DISABLE_PASSWORD_LOGIN
Add SSH port 10022: $DODO_CHANGE_SSH_PORT
Keep old SSH port 22: $DODO_KEEP_OLD_SSH_PORT
$pve_summary
fail2ban SSH protection: $fail2ban_summary
Automatic abuse reports: $DODO_ENABLE_ABUSE_REPORTS
Spamhaus extra destination: ${DODO_SPAMHAUS_REPORT_TO:-none}
Disable TCP forwarding: $DODO_DISABLE_TCP_FORWARDING

Keep the current SSH session open until a new connection is verified.
EOF
    fi
}

custom_menu() {
    if [ -n "$UI_TOOL" ]; then
        if [ "$DODO_LANG" = "ja" ]; then
            DODO_USER="$(ui_inputbox "Configuring dodo-sshkey" "authorized_keys を設定するユーザーを入力してください。" "$DODO_USER" 9 72)" || return 1
            if ui_yesno "Configuring dodo-sshkey" "SSH パスワードログインを無効化しますか？" 9 72 "$DODO_DISABLE_PASSWORD_LOGIN"; then
                DODO_DISABLE_PASSWORD_LOGIN="1"
            else
                DODO_DISABLE_PASSWORD_LOGIN="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "SSH ポート 10022 を追加しますか？ 推奨設定ではロックアウト防止のため 22 も維持します。" 11 78 "$DODO_CHANGE_SSH_PORT"; then
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                if ui_yesno "Configuring dodo-sshkey" "ロックアウト防止のため旧 SSH ポート 22 も維持しますか？" 9 78 "$DODO_KEEP_OLD_SSH_PORT"; then
                    DODO_KEEP_OLD_SSH_PORT="1"
                else
                    DODO_KEEP_OLD_SSH_PORT="0"
                fi
            else
                DODO_CHANGE_SSH_PORT="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "fail2ban で SSH ブルートフォース対策を有効化しますか？" 9 78 "$DODO_ENABLE_FAIL2BAN"; then
                DODO_ENABLE_FAIL2BAN="1"
            else
                DODO_ENABLE_FAIL2BAN="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "fail2ban ban 時に abuse メールを自動送信しますか？" 9 78 "$DODO_ENABLE_ABUSE_REPORTS"; then
                DODO_ENABLE_ABUSE_REPORTS="1"
                DODO_SPAMHAUS_REPORT_TO="$(ui_inputbox "Configuring dodo-sshkey" "Spamhaus など追加レポート宛先を入力してください。空欄でも構いません。" "$DODO_SPAMHAUS_REPORT_TO" 10 78)" || return 1
            else
                DODO_ENABLE_ABUSE_REPORTS="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "SSH TCP forwarding も無効化しますか？ 通常のトンネルやポート転送を利用している場合は No を選択してください。" 11 78 "$DODO_DISABLE_TCP_FORWARDING"; then
                DODO_DISABLE_TCP_FORWARDING="1"
            else
                DODO_DISABLE_TCP_FORWARDING="0"
            fi
        else
            DODO_USER="$(ui_inputbox "Configuring dodo-sshkey" "Enter the user for authorized_keys." "$DODO_USER" 9 72)" || return 1
            if ui_yesno "Configuring dodo-sshkey" "Disable SSH password login?" 9 72 "$DODO_DISABLE_PASSWORD_LOGIN"; then
                DODO_DISABLE_PASSWORD_LOGIN="1"
            else
                DODO_DISABLE_PASSWORD_LOGIN="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "Add SSH port 10022? Recommended mode keeps port 22 as a lockout fallback." 11 78 "$DODO_CHANGE_SSH_PORT"; then
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                if ui_yesno "Configuring dodo-sshkey" "Keep old SSH port 22 as a lockout fallback?" 9 78 "$DODO_KEEP_OLD_SSH_PORT"; then
                    DODO_KEEP_OLD_SSH_PORT="1"
                else
                    DODO_KEEP_OLD_SSH_PORT="0"
                fi
            else
                DODO_CHANGE_SSH_PORT="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "Enable fail2ban SSH brute-force protection?" 9 78 "$DODO_ENABLE_FAIL2BAN"; then
                DODO_ENABLE_FAIL2BAN="1"
            else
                DODO_ENABLE_FAIL2BAN="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "Send automatic abuse emails on fail2ban bans?" 9 78 "$DODO_ENABLE_ABUSE_REPORTS"; then
                DODO_ENABLE_ABUSE_REPORTS="1"
                DODO_SPAMHAUS_REPORT_TO="$(ui_inputbox "Configuring dodo-sshkey" "Extra report destination such as Spamhaus. Leave empty to skip." "$DODO_SPAMHAUS_REPORT_TO" 10 78)" || return 1
            else
                DODO_ENABLE_ABUSE_REPORTS="0"
            fi
            if ui_yesno "Configuring dodo-sshkey" "Also disable SSH TCP forwarding? Choose No if you use SSH tunnels or port forwarding." 11 78 "$DODO_DISABLE_TCP_FORWARDING"; then
                DODO_DISABLE_TCP_FORWARDING="1"
            else
                DODO_DISABLE_TCP_FORWARDING="0"
            fi
        fi
        return 0
    fi

    if [ "$DODO_LANG" = "ja" ]; then
        DODO_USER="$(tty_prompt "authorized_keys を設定するユーザー" "$DODO_USER")"
        if prompt_yes_no "SSH パスワードログインを無効化しますか" "$DODO_DISABLE_PASSWORD_LOGIN"; then
            DODO_DISABLE_PASSWORD_LOGIN="1"
        else
            DODO_DISABLE_PASSWORD_LOGIN="0"
        fi
        if prompt_yes_no "SSH ポートを 10022 に変更しますか" "$DODO_CHANGE_SSH_PORT"; then
            DODO_CHANGE_SSH_PORT="1"
            DODO_SSH_PORT="10022"
            if prompt_yes_no "ロックアウト防止のため旧 SSH ポート 22 も維持しますか" "$DODO_KEEP_OLD_SSH_PORT"; then
                DODO_KEEP_OLD_SSH_PORT="1"
            else
                DODO_KEEP_OLD_SSH_PORT="0"
            fi
        else
            DODO_CHANGE_SSH_PORT="0"
        fi
        if prompt_yes_no "fail2ban で SSH ブルートフォース対策を有効化しますか" "$DODO_ENABLE_FAIL2BAN"; then
            DODO_ENABLE_FAIL2BAN="1"
        else
            DODO_ENABLE_FAIL2BAN="0"
        fi
        if prompt_yes_no "fail2ban ban 時に abuse メールを自動送信しますか" "$DODO_ENABLE_ABUSE_REPORTS"; then
            DODO_ENABLE_ABUSE_REPORTS="1"
            DODO_SPAMHAUS_REPORT_TO="$(tty_prompt "Spamhaus など追加レポート宛先（空欄可）" "$DODO_SPAMHAUS_REPORT_TO")"
        else
            DODO_ENABLE_ABUSE_REPORTS="0"
        fi
        if prompt_yes_no "SSH TCP forwarding も無効化しますか" "$DODO_DISABLE_TCP_FORWARDING"; then
            DODO_DISABLE_TCP_FORWARDING="1"
        else
            DODO_DISABLE_TCP_FORWARDING="0"
        fi
    else
        DODO_USER="$(tty_prompt "User for authorized_keys" "$DODO_USER")"
        if prompt_yes_no "Disable SSH password login" "$DODO_DISABLE_PASSWORD_LOGIN"; then
            DODO_DISABLE_PASSWORD_LOGIN="1"
        else
            DODO_DISABLE_PASSWORD_LOGIN="0"
        fi
        if prompt_yes_no "Change SSH port to 10022" "$DODO_CHANGE_SSH_PORT"; then
            DODO_CHANGE_SSH_PORT="1"
            DODO_SSH_PORT="10022"
            if prompt_yes_no "Keep old SSH port 22 as lockout fallback" "$DODO_KEEP_OLD_SSH_PORT"; then
                DODO_KEEP_OLD_SSH_PORT="1"
            else
                DODO_KEEP_OLD_SSH_PORT="0"
            fi
        else
            DODO_CHANGE_SSH_PORT="0"
        fi
        if prompt_yes_no "Enable fail2ban SSH brute-force protection" "$DODO_ENABLE_FAIL2BAN"; then
            DODO_ENABLE_FAIL2BAN="1"
        else
            DODO_ENABLE_FAIL2BAN="0"
        fi
        if prompt_yes_no "Send automatic abuse emails on fail2ban bans" "$DODO_ENABLE_ABUSE_REPORTS"; then
            DODO_ENABLE_ABUSE_REPORTS="1"
            DODO_SPAMHAUS_REPORT_TO="$(tty_prompt "Extra report destination such as Spamhaus (optional)" "$DODO_SPAMHAUS_REPORT_TO")"
        else
            DODO_ENABLE_ABUSE_REPORTS="0"
        fi
        if prompt_yes_no "Also disable SSH TCP forwarding" "$DODO_DISABLE_TCP_FORWARDING"; then
            DODO_DISABLE_TCP_FORWARDING="1"
        else
            DODO_DISABLE_TCP_FORWARDING="0"
        fi
    fi
}

interactive_menu() {
    can_prompt || {
        log "No interactive terminal detected; using environment/default settings."
        return 0
    }

    detect_ui_tool
    select_language

    if [ -n "$UI_TOOL" ]; then
        while :; do
        if [ "$DODO_LANG" = "ja" ]; then
            menu_text="$(cat <<EOF
検出: $PLATFORM / $OS_NAME
SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}

設定方案を選択してください。
EOF
)"
            answer="$(ui_menu "Configuring dodo-sshkey" "$menu_text" 19 86 6 \
                "recommended" "推奨: SSH鍵導入 + 10022追加（22維持）+ パスワードログイン無効化 + fail2ban" \
                "strict" "厳格: 推奨 + SSH TCP forwarding 無効化" \
                "pvefw" "Proxmox firewall: データセンター rules + PVE 8/9 ノード options" \
                "keys" "キーのみ: authorized_keys のみ更新" \
                "custom" "カスタム: 各項目を手動選択" \
                "cancel" "中止")" || {
                    DODO_LANG=""
                    select_language
                    continue
                }
        else
            menu_text="$(cat <<EOF
Detected: $PLATFORM / $OS_NAME
SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}

Select a setup profile.
EOF
)"
            answer="$(ui_menu "Configuring dodo-sshkey" "$menu_text" 19 86 6 \
                "recommended" "Recommended: keys + 10022 (keep 22) + disable password login + fail2ban" \
                "strict" "Strict: recommended + disable SSH TCP forwarding" \
                "pvefw" "Proxmox firewall: datacenter rules + PVE 8/9 node options" \
                "keys" "Keys only: update authorized_keys only" \
                "custom" "Custom: choose each option manually" \
                "cancel" "Cancel")" || {
                    DODO_LANG=""
                    select_language
                    continue
                }
        fi

        case "$answer" in
            recommended)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                ;;
            strict)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="1"
                ;;
            pvefw)
                if [ "$PLATFORM" != "proxmox" ]; then
                    if [ "$DODO_LANG" = "ja" ]; then
                        ui_msgbox "Configuring dodo-sshkey" "この機能は Proxmox VE でのみ利用できます。メインメニューに戻ります。" 9 78 || true
                    else
                        ui_msgbox "Configuring dodo-sshkey" "This feature is only available on Proxmox VE. Returning to the main menu." 9 78 || true
                    fi
                    continue
                fi
                DODO_INSTALL_KEYS="0"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="1"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                ;;
            keys)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                ;;
            custom)
                DODO_INSTALL_KEYS="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                custom_menu || continue
                ;;
            cancel)
                DODO_LANG=""
                select_language
                continue
                ;;
        esac

        summary="$(summary_text)"
        ui_yesno "Configuring dodo-sshkey" "$summary" 21 86 1 || continue
        return 0
        done
    fi

    if [ "$DODO_LANG" = "ja" ]; then
        tty_print ""
        tty_print "========================================"
        tty_print " DODO-SSHKEY セットアップ"
        tty_print "========================================"
        tty_print "検出: $PLATFORM / $OS_NAME / SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}"
        tty_print ""
        tty_print "1) 推奨: SSH鍵導入 + SSHポート10022（22も維持）+ パスワードログイン無効化 + fail2ban"
        tty_print "2) 厳格: 推奨 + SSH TCP forwarding 無効化"
        tty_print "3) Proxmox firewall: データセンター rules + PVE 8/9 ノード options"
        tty_print "4) キーのみ: authorized_keys のみ更新"
        tty_print "5) カスタム: 各項目を手動選択"
        tty_print "6) 中止"
    else
        tty_print ""
        tty_print "========================================"
        tty_print " DODO-SSHKEY Setup"
        tty_print "========================================"
        tty_print "Detected: $PLATFORM / $OS_NAME / SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}"
        tty_print ""
        tty_print "1) Recommended: keys + SSH port 10022 (keep 22) + disable password login + fail2ban"
        tty_print "2) Strict: recommended + disable SSH TCP forwarding"
        tty_print "3) Proxmox firewall: datacenter rules + PVE 8/9 node options"
        tty_print "4) Keys only: update authorized_keys only"
        tty_print "5) Custom: choose each option"
        tty_print "6) Cancel"
    fi

    while :; do
        if [ "$DODO_LANG" = "ja" ]; then
            answer="$(tty_prompt "設定方案を選択" "1")"
        else
            answer="$(tty_prompt "Select profile" "1")"
        fi

        case "$answer" in
            1)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                break
                ;;
            2)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="1"
                break
                ;;
            3)
                if [ "$PLATFORM" != "proxmox" ]; then
                    tty_print "This option is only available on Proxmox VE."
                    continue
                fi
                DODO_INSTALL_KEYS="0"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="1"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                break
                ;;
            4)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="1"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                break
                ;;
            5)
                DODO_INSTALL_KEYS="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                custom_menu
                break
                ;;
            6)
                die "Canceled by user."
                ;;
            *)
                tty_print "Please select 1-6."
                ;;
        esac
    done

    show_summary
    if [ "$DODO_LANG" = "ja" ]; then
        prompt_yes_no "この設定で実行しますか" "1" || die "Canceled by user."
    else
        prompt_yes_no "Continue with this configuration" "1" || die "Canceled by user."
    fi
}

need_root() {
    [ "$(id -u)" = "0" ] || die "This script must be run as root."
}

detect_platform() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
    fi

    if [ -r /etc/openwrt_release ] || [ "$OS_ID" = "openwrt" ]; then
        PLATFORM="openwrt"
        SSH_IMPL="dropbear"
    elif [ -d /etc/config ] && [ -f /etc/config/dropbear ]; then
        PLATFORM="openwrt"
        SSH_IMPL="dropbear"
    elif have_cmd pveversion || [ -d /etc/pve ]; then
        PLATFORM="proxmox"
        SSH_IMPL="openssh"
    else
        PLATFORM="linux"
        if have_cmd sshd || [ -f /etc/ssh/sshd_config ]; then
            SSH_IMPL="openssh"
        elif have_cmd dropbear || [ -f /etc/config/dropbear ]; then
            SSH_IMPL="dropbear"
        fi
    fi

    if have_cmd apt-get; then
        PKG_MANAGER="apt"
    elif have_cmd dnf; then
        PKG_MANAGER="dnf"
    elif have_cmd yum; then
        PKG_MANAGER="yum"
    elif have_cmd zypper; then
        PKG_MANAGER="zypper"
    elif have_cmd apk; then
        PKG_MANAGER="apk"
    elif have_cmd pacman; then
        PKG_MANAGER="pacman"
    elif have_cmd opkg; then
        PKG_MANAGER="opkg"
    fi

    log "Detected platform=$PLATFORM os='$OS_NAME' pkg=$PKG_MANAGER ssh=$SSH_IMPL"
}

pkg_install() {
    [ $# -gt 0 ] || return 0
    [ -n "$PKG_MANAGER" ] || {
        warn "No supported package manager found; skipping package install: $*"
        return 0
    }

    case "$PKG_MANAGER" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        yum)
            yum install -y "$@"
            ;;
        zypper)
            zypper --non-interactive install "$@"
            ;;
        apk)
            apk add --no-cache "$@"
            ;;
        pacman)
            pacman -Sy --noconfirm --needed "$@"
            ;;
        opkg)
            opkg update
            opkg install "$@" || warn "Some OpenWrt packages were unavailable: $*"
            ;;
    esac
}

ensure_fetcher() {
    if have_cmd curl || have_cmd wget; then
        return 0
    fi

    log "Installing curl/wget support..."
    case "$PKG_MANAGER" in
        apk) pkg_install curl ca-certificates ;;
        opkg) pkg_install curl ca-bundle ;;
        *) pkg_install curl ca-certificates ;;
    esac
}

download_keys() {
    tmp_file="$(mktemp)"

    if have_cmd curl; then
        curl -fsSL "$DODO_KEY_URL" -o "$tmp_file"
    elif have_cmd wget; then
        wget -qO "$tmp_file" "$DODO_KEY_URL"
    else
        rm -f "$tmp_file"
        die "Neither curl nor wget is available."
    fi

    [ -s "$tmp_file" ] || {
        rm -f "$tmp_file"
        die "Downloaded authorized_keys is empty."
    }

    if ! grep -Eq '^(restrict |cert-authority |command=|environment=|from=|no-|permit-|principals=|tunnel=|[[:space:]]*)*(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp|sk-ssh-ed25519|sk-ecdsa-sha2-nistp)' "$tmp_file"; then
        rm -f "$tmp_file"
        die "Downloaded file does not look like an OpenSSH authorized_keys file."
    fi

    printf '%s\n' "$tmp_file"
}

backup_file() {
    file="$1"
    if [ -f "$file" ]; then
        backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        log "Backed up $file to $backup"
    fi
}

install_keys_linux() {
    key_file="$1"
    home_dir="$(getent passwd "$DODO_USER" 2>/dev/null | awk -F: '{print $6}')"
    [ -n "$home_dir" ] || home_dir="/root"

    ssh_dir="$home_dir/.ssh"
    auth_file="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    backup_file "$auth_file"
    cp "$key_file" "$auth_file"
    chmod 600 "$auth_file"
    if id "$DODO_USER" >/dev/null 2>&1; then
        chown -R "$DODO_USER:$DODO_USER" "$ssh_dir" 2>/dev/null || chown -R "$DODO_USER" "$ssh_dir"
    fi

    log "Installed authorized_keys for $DODO_USER at $auth_file"
}

install_keys_openwrt() {
    key_file="$1"

    mkdir -p /etc/dropbear /root/.ssh
    chmod 700 /root/.ssh

    backup_file /etc/dropbear/authorized_keys
    cp "$key_file" /etc/dropbear/authorized_keys
    chmod 600 /etc/dropbear/authorized_keys

    backup_file /root/.ssh/authorized_keys
    cp "$key_file" /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    log "Installed authorized_keys for OpenWrt Dropbear."
}

restart_service() {
    service_name="$1"

    if have_cmd systemctl && [ -d /run/systemd/system ]; then
        systemctl restart "$service_name" 2>/dev/null && return 0
        if [ "$service_name" = "sshd" ]; then
            systemctl restart ssh 2>/dev/null && return 0
        elif [ "$service_name" = "ssh" ]; then
            systemctl restart sshd 2>/dev/null && return 0
        fi
    fi

    if have_cmd service; then
        service "$service_name" restart 2>/dev/null && return 0
        if [ "$service_name" = "sshd" ]; then
            service ssh restart 2>/dev/null && return 0
        elif [ "$service_name" = "ssh" ]; then
            service sshd restart 2>/dev/null && return 0
        fi
    fi

    if [ -x "/etc/init.d/$service_name" ]; then
        "/etc/init.d/$service_name" restart && return 0
    fi

    return 1
}

sshd_config_test() {
    if have_cmd sshd; then
        sshd -t
    elif [ -x /usr/sbin/sshd ]; then
        /usr/sbin/sshd -t
    else
        warn "sshd binary not found; cannot validate sshd_config before restart."
        return 0
    fi
}

write_openssh_hardening_block() {
    config="/etc/ssh/sshd_config"
    [ -f "$config" ] || die "OpenSSH config not found at $config"

    backup_file "$config"
    tmp_config="$(mktemp)"
    block_file="$(mktemp)"

    {
        echo "# BEGIN DODO-SSHKEY hardening"
        echo "PubkeyAuthentication yes"
        if [ "$DODO_CHANGE_SSH_PORT" = "1" ]; then
            if [ "$DODO_KEEP_OLD_SSH_PORT" = "1" ]; then
                echo "Port 22"
            fi
            echo "Port $DODO_SSH_PORT"
        fi
        echo "PermitEmptyPasswords no"
        echo "MaxAuthTries 3"
        echo "MaxSessions 4"
        echo "MaxStartups 10:30:60"
        echo "LoginGraceTime 20"
        echo "ClientAliveInterval 300"
        echo "ClientAliveCountMax 2"
        echo "X11Forwarding no"
        echo "AllowAgentForwarding no"
        echo "LogLevel VERBOSE"
        if [ "$DODO_DISABLE_TCP_FORWARDING" = "1" ]; then
            echo "AllowTcpForwarding no"
        fi
        if [ "$DODO_DISABLE_PASSWORD_LOGIN" = "1" ]; then
            echo "PasswordAuthentication no"
            echo "KbdInteractiveAuthentication no"
            echo "PermitRootLogin prohibit-password"
        fi
        echo "# END DODO-SSHKEY hardening"
    } >"$block_file"

    awk -v block_file="$block_file" -v change_ssh_port="$DODO_CHANGE_SSH_PORT" '
        BEGIN {
            in_block = 0
            inserted = 0
            in_match = 0
            while ((getline line < block_file) > 0) {
                block = block line "\n"
            }
            close(block_file)
        }
        /^[[:space:]]*# BEGIN DODO-SSHKEY hardening/ { in_block = 1; next }
        /^[[:space:]]*# END DODO-SSHKEY hardening/ { in_block = 0; next }
        in_block { next }
        /^[[:space:]]*Match[[:space:]]/ {
            if (inserted == 0) {
                printf "%s", block
                inserted = 1
            }
            in_match = 1
            print
            next
        }
        change_ssh_port == "1" && in_match == 0 && /^[[:space:]]*Port[[:space:]]+/ {
            print "# DODO-SSHKEY disabled old SSH port: " $0
            next
        }
        { print }
        END {
            if (inserted == 0) {
                printf "%s", block
            }
        }
    ' "$config" >"$tmp_config"

    cp "$tmp_config" "$config"
    rm -f "$tmp_config" "$block_file"

    if ! sshd_config_test; then
        latest_backup="$(ls -t "$config".bak.* 2>/dev/null | head -n 1 || true)"
        [ -n "$latest_backup" ] && cp "$latest_backup" "$config"
        die "sshd_config validation failed; restored previous config."
    fi

    restart_service sshd || warn "Could not restart sshd/ssh automatically. Please restart SSH manually."
    log "OpenSSH hardening applied."
}

open_firewall_for_ssh_port() {
    [ "$DODO_CHANGE_SSH_PORT" = "1" ] || return 0

    port="$DODO_SSH_PORT"
    log "Opening TCP $port in local firewall where supported..."

    if have_cmd ufw && ufw status 2>/dev/null | grep -qi active; then
        ufw allow "$port/tcp" || warn "Failed to update ufw for TCP $port."
    fi

    if have_cmd firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="$port/tcp" || warn "Failed to update firewalld permanent rule for TCP $port."
        firewall-cmd --reload || warn "Failed to reload firewalld."
    fi

    if have_cmd iptables; then
        iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
            iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
            warn "Failed to add temporary iptables allow rule for TCP $port."
    fi

    if have_cmd ip6tables; then
        ip6tables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
            ip6tables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    fi

    if have_cmd pve-firewall; then
        warn "If Proxmox firewall is enabled, also allow TCP $port in datacenter/node firewall rules."
    fi
}

pve_update_options() {
    config="$1"
    options_file="$2"
    keys_regex="$3"
    tmp_file="$(mktemp)"

    [ -f "$config" ] || : >"$config"

    awk -v options_file="$options_file" -v keys_regex="$keys_regex" '
        BEGIN {
            in_options = 0
            inserted = 0
            while ((getline line < options_file) > 0) {
                options = options line "\n"
            }
            close(options_file)
        }
        /^\[OPTIONS\]$/ {
            print
            printf "%s", options
            in_options = 1
            inserted = 1
            next
        }
        /^\[/ {
            in_options = 0
        }
        in_options && $0 ~ keys_regex {
            next
        }
        { print }
        END {
            if (inserted == 0) {
                print ""
                print "[OPTIONS]"
                printf "%s", options
            }
        }
    ' "$config" >"$tmp_file"

    cp "$tmp_file" "$config"
    rm -f "$tmp_file"
}

pve_update_managed_rules() {
    config="$1"
    block_file="$2"
    tmp_file="$(mktemp)"

    [ -f "$config" ] || : >"$config"

    awk -v block_file="$block_file" '
        BEGIN {
            in_managed = 0
            inserted = 0
            while ((getline line < block_file) > 0) {
                block = block line "\n"
            }
            close(block_file)
        }
        /^# BEGIN DODO-SSHKEY PVE DATACENTER RULES$/ { in_managed = 1; next }
        /^# END DODO-SSHKEY PVE DATACENTER RULES$/ { in_managed = 0; next }
        in_managed { next }
        /^\[RULES\]$/ {
            print
            printf "%s", block
            inserted = 1
            next
        }
        { print }
        END {
            if (inserted == 0) {
                print ""
                print "[RULES]"
                printf "%s", block
            }
        }
    ' "$config" >"$tmp_file"

    cp "$tmp_file" "$config"
    rm -f "$tmp_file"
}

pve_firewall_validate() {
    if have_cmd pve-firewall; then
        pve-firewall compile >/dev/null
    else
        warn "pve-firewall command not found; skipping Proxmox firewall compile validation."
        return 0
    fi
}

pve_restore_file() {
    target="$1"
    backup="$2"
    existed="$3"

    if [ "$existed" = "1" ]; then
        cp "$backup" "$target"
    else
        rm -f "$target"
    fi
}

configure_pve_firewall() {
    [ "$PLATFORM" = "proxmox" ] || return 0
    [ "$DODO_CONFIGURE_PVE_FIREWALL" = "1" ] || return 0

    [ -d /etc/pve ] || {
        warn "/etc/pve not found; skipping Proxmox firewall configuration."
        return 0
    }

    node_name="$(hostname -s 2>/dev/null || hostname)"
    if [ ! -d "/etc/pve/nodes/$node_name" ] && [ -d /etc/pve/nodes ]; then
        first_node="$(ls /etc/pve/nodes 2>/dev/null | head -n 1 || true)"
        [ -n "$first_node" ] && node_name="$first_node"
    fi

    [ -d "/etc/pve/nodes/$node_name" ] || {
        warn "Proxmox node config directory not found; skipping node firewall options."
        return 0
    }

    firewall_dir="/etc/pve/firewall"
    cluster_fw="$firewall_dir/cluster.fw"
    host_fw="/etc/pve/nodes/$node_name/host.fw"

    mkdir -p "$firewall_dir"

    cluster_backup="$(mktemp)"
    host_backup="$(mktemp)"
    cluster_existed="0"
    host_existed="0"
    [ -f "$cluster_fw" ] && cluster_existed="1" && cp "$cluster_fw" "$cluster_backup"
    [ -f "$host_fw" ] && host_existed="1" && cp "$host_fw" "$host_backup"

    backup_file "$cluster_fw"
    backup_file "$host_fw"

    cluster_options="$(mktemp)"
    host_options="$(mktemp)"
    datacenter_rules="$(mktemp)"

    cat >"$cluster_options" <<EOF
enable: 1
ebtables: 1
log_ratelimit: enable=1,rate=1/second,burst=5
policy_in: DROP
policy_out: ACCEPT
policy_forward: ACCEPT
EOF

    cat >"$datacenter_rules" <<EOF
# BEGIN DODO-SSHKEY PVE DATACENTER RULES
IN ACCEPT -p tcp -dport $DODO_SSH_PORT -log nolog
IN Web(ACCEPT) -log nolog
IN ACCEPT -p tcp -dport 8006 -log nolog
# END DODO-SSHKEY PVE DATACENTER RULES
EOF

    cat >"$host_options" <<EOF
enable: 1
nosmurfs: 1
tcpflags: 0
ndp: 1
nftables: 0
log_level_in: nolog
log_level_out: nolog
log_level_forward: nolog
tcp_flags_log_level: nolog
smurf_log_level: nolog
EOF

    pve_update_options "$cluster_fw" "$cluster_options" '^(enable|ebtables|log_ratelimit|policy_in|policy_out|policy_forward):'
    pve_update_managed_rules "$cluster_fw" "$datacenter_rules"
    pve_update_options "$host_fw" "$host_options" '^(enable|nosmurfs|tcpflags|ndp|nftables|log_level_in|log_level_out|log_level_forward|tcp_flags_log_level|smurf_log_level):'

    if ! pve_firewall_validate; then
        pve_restore_file "$cluster_fw" "$cluster_backup" "$cluster_existed"
        pve_restore_file "$host_fw" "$host_backup" "$host_existed"
        rm -f "$cluster_backup" "$host_backup" "$cluster_options" "$host_options" "$datacenter_rules"
        die "Proxmox firewall validation failed; restored previous firewall config."
    fi

    if have_cmd pve-firewall; then
        pve-firewall restart || warn "pve-firewall restart failed; check Proxmox firewall status manually."
    fi

    rm -f "$cluster_backup" "$host_backup" "$cluster_options" "$host_options" "$datacenter_rules"
    log "Proxmox datacenter firewall rules and PVE 8/9 host options configured."
}

configure_openwrt_dropbear() {
    if have_cmd uci; then
        backup_file /etc/config/dropbear
        if [ "$DODO_DISABLE_PASSWORD_LOGIN" = "1" ]; then
            uci set dropbear.@dropbear[0].PasswordAuth='off' || true
            uci set dropbear.@dropbear[0].RootPasswordAuth='off' || true
        fi
        uci set dropbear.@dropbear[0].GatewayPorts='off' || true
        uci set dropbear.@dropbear[0].MaxAuthTries='3' || true
        if [ "$DODO_CHANGE_SSH_PORT" = "1" ]; then
            uci set dropbear.@dropbear[0].Port="$DODO_SSH_PORT" || true
        fi
        uci commit dropbear || true
    else
        warn "uci not found; skipping Dropbear UCI hardening."
    fi

    restart_service dropbear || warn "Could not restart Dropbear automatically."
    log "OpenWrt Dropbear hardening applied."
}

install_fail2ban_packages() {
    [ "$DODO_ENABLE_FAIL2BAN" = "1" ] || return 0

    if [ "$PLATFORM" = "openwrt" ]; then
        warn "Skipping fail2ban on OpenWrt; Dropbear UCI hardening was applied instead."
        return 0
    fi

    if have_cmd fail2ban-client; then
        return 0
    fi

    log "Installing fail2ban..."
    case "$PKG_MANAGER" in
        apt) pkg_install fail2ban whois ca-certificates || warn "Failed to install fail2ban packages." ;;
        dnf|yum) pkg_install fail2ban whois bind-utils ca-certificates || warn "Failed to install fail2ban packages. On RHEL-compatible systems, EPEL may be required." ;;
        zypper) pkg_install fail2ban whois ca-certificates || warn "Failed to install fail2ban packages." ;;
        apk) pkg_install fail2ban whois ca-certificates || warn "Failed to install fail2ban packages." ;;
        pacman) pkg_install fail2ban whois ca-certificates || warn "Failed to install fail2ban packages." ;;
        *) pkg_install fail2ban whois || warn "Failed to install fail2ban packages." ;;
    esac
}

write_abuse_reporter() {
    [ "$DODO_ENABLE_ABUSE_REPORTS" = "1" ] || return 0
    [ "$PLATFORM" != "openwrt" ] || return 0

    install -d -m 755 /usr/local/sbin /etc

    cat >/etc/dodo-sshkey-abuse.conf <<EOF
# DODO-SSHKEY abuse reporting config.
# Automatic abuse reports are disabled unless DODO_ENABLE_ABUSE_REPORTS=1 was set
# when import_key.sh generated fail2ban config.
ABUSE_REPORT_FROM="root@$(hostname -f 2>/dev/null || hostname)"
ABUSE_REPORT_CC=""
SPAMHAUS_REPORT_TO="$DODO_SPAMHAUS_REPORT_TO"
ABUSE_REPORT_DRY_RUN="0"
EOF
    chmod 600 /etc/dodo-sshkey-abuse.conf

    cat >/usr/local/sbin/dodo-fail2ban-abuse-report <<'EOF'
#!/bin/sh
set -eu

CONFIG="/etc/dodo-sshkey-abuse.conf"
[ -r "$CONFIG" ] && . "$CONFIG"

ABUSE_REPORT_FROM="${ABUSE_REPORT_FROM:-root@$(hostname -f 2>/dev/null || hostname)}"
ABUSE_REPORT_CC="${ABUSE_REPORT_CC:-}"
SPAMHAUS_REPORT_TO="${SPAMHAUS_REPORT_TO:-}"
ABUSE_REPORT_DRY_RUN="${ABUSE_REPORT_DRY_RUN:-0}"

IP=""
JAIL="sshd"

while [ $# -gt 0 ]; do
    case "$1" in
        --ip) IP="${2:-}"; shift 2 ;;
        --jail) JAIL="${2:-sshd}"; shift 2 ;;
        *) shift ;;
    esac
done

case "$IP" in
    *[!0-9a-fA-F:.]*|"") exit 0 ;;
esac

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

lookup_abuse_email() {
    ip="$1"
    tmp="$(mktemp)"
    : >"$tmp"

    if have_cmd whois; then
        whois "$ip" >>"$tmp" 2>/dev/null || true
        for server in whois.arin.net whois.ripe.net whois.apnic.net whois.lacnic.net whois.afrinic.net; do
            whois -h "$server" "$ip" >>"$tmp" 2>/dev/null || true
        done
    fi

    awk -F: '
        BEGIN { IGNORECASE = 1 }
        $1 ~ /(abuse-mailbox|orgabuseemail|abuseemail|abuse-c|e-mail|email)/ {
            print $0
        }
    ' "$tmp" \
        | tr ' ,;\t<>()' '\n' \
        | grep -Eio '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}' \
        | grep -Ei 'abuse|security|noc|cert' \
        | head -n 1 || true

    rm -f "$tmp"
}

send_message() {
    to="$1"
    subject="$2"
    body="$3"

    [ -n "$to" ] || return 0

    if [ "$ABUSE_REPORT_DRY_RUN" = "1" ]; then
        if have_cmd logger; then
            logger -t dodo-fail2ban-abuse-report "DRY_RUN to=$to subject=$subject ip=$IP jail=$JAIL"
        fi
        return 0
    fi

    if have_cmd sendmail; then
        {
            printf 'From: %s\n' "$ABUSE_REPORT_FROM"
            printf 'To: %s\n' "$to"
            [ -z "$ABUSE_REPORT_CC" ] || printf 'Cc: %s\n' "$ABUSE_REPORT_CC"
            printf 'Subject: %s\n' "$subject"
            printf 'Content-Type: text/plain; charset=UTF-8\n'
            printf '\n%s\n' "$body"
        } | sendmail -t
    elif have_cmd mail; then
        printf '%s\n' "$body" | mail -s "$subject" "$to"
    elif have_cmd mailx; then
        printf '%s\n' "$body" | mailx -s "$subject" "$to"
    else
        if have_cmd logger; then
            logger -t dodo-fail2ban-abuse-report "No mailer available for abuse report to=$to ip=$IP jail=$JAIL"
        fi
    fi
}

ABUSE_TO="$(lookup_abuse_email "$IP" || true)"
SUBJECT="[abuse][fail2ban] SSH brute-force/scanning source $IP"
BODY="$(cat <<BODYEOF
Hello,

This is an automated abuse report generated after repeated SSH authentication
failures were banned by fail2ban.

Source IP: $IP
Jail: $JAIL
Reporter host: $(hostname -f 2>/dev/null || hostname)
Time UTC: $(date -u '+%Y-%m-%d %H:%M:%S %Z')

Please investigate the source host for brute-force login attempts, scanning, or
compromise.

Regards,
DODO-SSHKEY fail2ban reporter
BODYEOF
)"

send_message "$ABUSE_TO" "$SUBJECT" "$BODY"

if [ -n "$SPAMHAUS_REPORT_TO" ]; then
    send_message "$SPAMHAUS_REPORT_TO" "$SUBJECT" "$BODY"
fi
EOF

    chmod 755 /usr/local/sbin/dodo-fail2ban-abuse-report
    log "Installed fail2ban abuse reporter at /usr/local/sbin/dodo-fail2ban-abuse-report"
}

configure_fail2ban() {
    [ "$DODO_ENABLE_FAIL2BAN" = "1" ] || return 0
    [ "$PLATFORM" != "openwrt" ] || return 0
    have_cmd fail2ban-client || {
        warn "fail2ban is not installed; skipping jail config."
        return 0
    }

    install -d -m 755 /etc/fail2ban/jail.d
    fail2ban_ssh_port="ssh"
    if [ "$DODO_CHANGE_SSH_PORT" = "1" ]; then
        fail2ban_ssh_port="$DODO_SSH_PORT"
        if [ "$DODO_KEEP_OLD_SSH_PORT" = "1" ]; then
            fail2ban_ssh_port="ssh,$DODO_SSH_PORT"
        fi
    fi

    action_lines='%(action_)s'
    if [ "$DODO_ENABLE_ABUSE_REPORTS" = "1" ]; then
        install -d -m 755 /etc/fail2ban/action.d
        cat >/etc/fail2ban/action.d/dodo-abuse-report.conf <<'EOF'
[Definition]
actionban = /usr/local/sbin/dodo-fail2ban-abuse-report --ip "<ip>" --jail "<name>"
EOF
        action_lines='%(action_)s
         dodo-abuse-report'
    fi

    cat >/etc/fail2ban/jail.d/dodo-sshd.conf <<EOF
[sshd]
enabled = true
port = $fail2ban_ssh_port
filter = sshd
backend = auto
logpath = %(sshd_log)s
maxretry = 3
findtime = 10m
bantime = 12h
ignoreip = 127.0.0.1/8 ::1
action = $action_lines

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
maxretry = 5
findtime = 1d
bantime = 1w
EOF

    if have_cmd systemctl && [ -d /run/systemd/system ]; then
        systemctl enable --now fail2ban 2>/dev/null || systemctl restart fail2ban 2>/dev/null || true
    else
        restart_service fail2ban || true
    fi

    fail2ban-client reload >/dev/null 2>&1 || true
    log "fail2ban SSH brute-force protection configured."
}

main() {
    need_root
    detect_platform
    interactive_menu
    validate_ssh_port

    key_file=""
    if [ "$DODO_INSTALL_KEYS" = "1" ]; then
        ensure_fetcher
        key_file="$(download_keys)"
        trap 'rm -f "$key_file"' EXIT
    fi

    if [ "$PLATFORM" = "openwrt" ] || [ "$SSH_IMPL" = "dropbear" ]; then
        if [ "$DODO_INSTALL_KEYS" = "1" ]; then
            install_keys_openwrt "$key_file"
        fi
        if [ "$DODO_DISABLE_PASSWORD_LOGIN" = "1" ] || [ "$DODO_CHANGE_SSH_PORT" = "1" ] || [ "$DODO_DISABLE_TCP_FORWARDING" = "1" ]; then
            open_firewall_for_ssh_port
            configure_openwrt_dropbear
        fi
    else
        if [ "$DODO_INSTALL_KEYS" = "1" ]; then
            install_keys_linux "$key_file"
        fi
        if [ "$PLATFORM" = "proxmox" ] && [ "$DODO_CONFIGURE_PVE_FIREWALL" = "1" ]; then
            open_firewall_for_ssh_port
            configure_pve_firewall
        fi
        if [ "$DODO_DISABLE_PASSWORD_LOGIN" = "1" ] || [ "$DODO_CHANGE_SSH_PORT" = "1" ] || [ "$DODO_DISABLE_TCP_FORWARDING" = "1" ]; then
            open_firewall_for_ssh_port
            write_openssh_hardening_block
        fi
        install_fail2ban_packages
        write_abuse_reporter
        configure_fail2ban
    fi

    log "Completed. Keep the current session open and verify a new SSH-key login before closing it."
}

main "$@"
