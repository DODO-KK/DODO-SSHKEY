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
#   DODO_DISABLE_TCP_FORWARDING=1
#   DODO_CHANGE_SSH_PORT=1
#   DODO_SSH_PORT=10022
#   DODO_KEEP_OLD_SSH_PORT=0
#   DODO_CONFIGURE_PVE_FIREWALL=0
#   DODO_UPGRADE_DEBIAN13=0
#   DODO_DEBIAN13_MIRROR=global|cn
#   DODO_LANG=en|ja|zh
#   DODO_NONINTERACTIVE=0|1

DODO_INSTALL_KEYS="${DODO_INSTALL_KEYS:-1}"
DODO_USER="${DODO_USER:-root}"
DODO_KEY_URL="${DODO_KEY_URL:-https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/authorized_keys}"
DODO_DISABLE_PASSWORD_LOGIN="${DODO_DISABLE_PASSWORD_LOGIN:-1}"
DODO_ENABLE_FAIL2BAN="${DODO_ENABLE_FAIL2BAN:-1}"
DODO_ENABLE_ABUSE_REPORTS="${DODO_ENABLE_ABUSE_REPORTS:-0}"
DODO_SPAMHAUS_REPORT_TO="${DODO_SPAMHAUS_REPORT_TO:-}"
DODO_DISABLE_TCP_FORWARDING="${DODO_DISABLE_TCP_FORWARDING:-1}"
DODO_CHANGE_SSH_PORT="${DODO_CHANGE_SSH_PORT:-1}"
DODO_SSH_PORT="${DODO_SSH_PORT:-10022}"
DODO_KEEP_OLD_SSH_PORT="${DODO_KEEP_OLD_SSH_PORT:-0}"
DODO_CONFIGURE_PVE_FIREWALL="${DODO_CONFIGURE_PVE_FIREWALL:-0}"
DODO_UPGRADE_DEBIAN13="${DODO_UPGRADE_DEBIAN13:-0}"
DODO_DEBIAN13_MIRROR="${DODO_DEBIAN13_MIRROR:-global}"
DODO_LANG="${DODO_LANG:-}"
DODO_NONINTERACTIVE="${DODO_NONINTERACTIVE:-0}"

PLATFORM="linux"
OS_ID="unknown"
OS_NAME="unknown"
OS_VERSION_ID=""
PKG_MANAGER=""
SSH_IMPL="openssh"
UI_TOOL=""
UI_UTF8="0"

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

locale_is_utf8() {
    charmap="$(locale charmap 2>/dev/null || true)"
    case "$charmap" in
        *UTF-8*|*utf8*|*UTF8*) return 0 ;;
        *) return 1 ;;
    esac
}

enable_utf8_locale() {
    UI_UTF8="0"
    [ "$DODO_LANG" = "zh" ] || [ "$DODO_LANG" = "ja" ] || return 0

    if locale_is_utf8; then
        UI_UTF8="1"
        return 0
    fi

    for loc in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
        if locale -a 2>/dev/null | grep -qx "$loc"; then
            export LANG="$loc"
            export LC_ALL="$loc"
            UI_UTF8="1"
            return 0
        fi
    done

    DODO_LANG="en"
    UI_UTF8="0"
    warn "UTF-8 locale is not available; falling back to English terminal UI."
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
        answer="$(ui_menu "Configuring dodo-sshkey" "Select display language." 14 72 3 \
            "en" "English" \
            "ja" "Japanese" \
            "zh" "Chinese")" || die "Canceled by user."
        case "$answer" in
            zh) DODO_LANG="zh" ;;
            ja) DODO_LANG="ja" ;;
            *) DODO_LANG="en" ;;
        esac
        enable_utf8_locale
        return 0
    fi

    tty_print ""
    tty_print "========================================"
    tty_print " DODO-SSHKEY"
    tty_print "========================================"
    tty_print "1) English"
    tty_print "2) Japanese"
    tty_print "3) Chinese"

    while :; do
        answer="$(tty_prompt "Select language" "1")"
        case "$answer" in
            1|en|EN|English|english) DODO_LANG="en"; return 0 ;;
            2|ja|JA|Japanese|japanese) DODO_LANG="ja"; enable_utf8_locale; return 0 ;;
            3|zh|ZH|Chinese|chinese|cn|CN) DODO_LANG="zh"; enable_utf8_locale; return 0 ;;
            *) tty_print "Please select 1, 2, or 3." ;;
        esac
    done
}

show_summary() {
    fail2ban_summary="$DODO_ENABLE_FAIL2BAN"
    if [ "$PLATFORM" = "openwrt" ] && [ "$DODO_ENABLE_FAIL2BAN" = "1" ]; then
        if [ "$DODO_LANG" = "ja" ]; then
            fail2ban_summary="1 (OpenWrt ではスキップ)"
        elif [ "$DODO_LANG" = "zh" ]; then
            fail2ban_summary="1 (OpenWrt 会跳过)"
        else
            fail2ban_summary="1 (skipped on OpenWrt)"
        fi
    fi

    if [ "$DODO_LANG" = "zh" ]; then
        tty_print ""
        tty_print "----------------------------------------"
        tty_print "配置确认"
        tty_print "----------------------------------------"
        tty_print "导入 SSH key: $DODO_INSTALL_KEYS"
        tty_print "目标用户: $DODO_USER"
        tty_print "检测系统: $PLATFORM / $OS_NAME / $SSH_IMPL"
        tty_print "关闭密码登录: $DODO_DISABLE_PASSWORD_LOGIN"
        tty_print "SSH 端口改为: $DODO_CHANGE_SSH_PORT (${DODO_SSH_PORT})"
        if [ "$PLATFORM" = "proxmox" ]; then
            tty_print "Proxmox 防火墙配置: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
        tty_print "Debian 13 升级: $DODO_UPGRADE_DEBIAN13 (${DODO_DEBIAN13_MIRROR})"
        tty_print "fail2ban SSH 防护: $fail2ban_summary"
        tty_print "abuse 自动通报: $DODO_ENABLE_ABUSE_REPORTS"
        tty_print "Spamhaus 额外收件人: ${DODO_SPAMHAUS_REPORT_TO:-none}"
        tty_print "关闭 SSH TCP forwarding: $DODO_DISABLE_TCP_FORWARDING"
        tty_print "----------------------------------------"
    elif [ "$DODO_LANG" = "ja" ]; then
        tty_print ""
        tty_print "----------------------------------------"
        tty_print "設定内容"
        tty_print "----------------------------------------"
        tty_print "SSH 鍵導入: $DODO_INSTALL_KEYS"
        tty_print "対象ユーザー: $DODO_USER"
        tty_print "検出システム: $PLATFORM / $OS_NAME / $SSH_IMPL"
        tty_print "パスワードログイン無効化: $DODO_DISABLE_PASSWORD_LOGIN"
        tty_print "SSH ポート変更: $DODO_CHANGE_SSH_PORT (${DODO_SSH_PORT})"
        if [ "$PLATFORM" = "proxmox" ]; then
            tty_print "Proxmox firewall 推奨設定: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
        tty_print "Debian 13 upgrade: $DODO_UPGRADE_DEBIAN13 (${DODO_DEBIAN13_MIRROR})"
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
        if [ "$PLATFORM" = "proxmox" ]; then
            tty_print "Proxmox firewall recommended setup: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
        tty_print "Debian 13 upgrade: $DODO_UPGRADE_DEBIAN13 (${DODO_DEBIAN13_MIRROR})"
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
        elif [ "$DODO_LANG" = "zh" ]; then
            fail2ban_summary="1 (OpenWrt 会跳过)"
        else
            fail2ban_summary="1 (skipped on OpenWrt)"
        fi
    fi
    if [ "$PLATFORM" = "proxmox" ]; then
        if [ "$DODO_LANG" = "ja" ]; then
            pve_summary="Proxmox firewall 推奨設定: $DODO_CONFIGURE_PVE_FIREWALL"
        elif [ "$DODO_LANG" = "zh" ]; then
            pve_summary="Proxmox 防火墙配置: $DODO_CONFIGURE_PVE_FIREWALL"
        else
            pve_summary="Proxmox firewall recommended setup: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
    fi

    if [ -n "$UI_TOOL" ] && [ "$UI_UTF8" != "1" ]; then
        if [ "$PLATFORM" = "proxmox" ]; then
            pve_summary="Proxmox firewall setup: $DODO_CONFIGURE_PVE_FIREWALL"
        fi
        if [ "$PLATFORM" = "openwrt" ] && [ "$DODO_ENABLE_FAIL2BAN" = "1" ]; then
            fail2ban_summary="1 (skipped on OpenWrt)"
        fi
        cat <<EOF
Configuration summary

Target user: $DODO_USER
Install SSH keys: $DODO_INSTALL_KEYS
Detected system: $PLATFORM / $OS_NAME / $SSH_IMPL
Disable password login: $DODO_DISABLE_PASSWORD_LOGIN
Change SSH port to 10022: $DODO_CHANGE_SSH_PORT
$pve_summary
Debian 13 upgrade: $DODO_UPGRADE_DEBIAN13 (${DODO_DEBIAN13_MIRROR})
Enable fail2ban SSH blacklist: $fail2ban_summary
Abuse report email: $DODO_ENABLE_ABUSE_REPORTS
Spamhaus extra destination: ${DODO_SPAMHAUS_REPORT_TO:-none}
Disable SSH TCP forwarding: $DODO_DISABLE_TCP_FORWARDING

Keep this SSH session open until a new connection works.
EOF
        return 0
    fi

    if [ "$DODO_LANG" = "zh" ]; then
        cat <<EOF
将执行以下配置：

目标用户: $DODO_USER
导入 SSH key: $DODO_INSTALL_KEYS
检测系统: $PLATFORM / $OS_NAME / $SSH_IMPL
关闭密码登录: $DODO_DISABLE_PASSWORD_LOGIN
SSH 端口改为 10022: $DODO_CHANGE_SSH_PORT
$pve_summary
Debian 13 升级: $DODO_UPGRADE_DEBIAN13 (${DODO_DEBIAN13_MIRROR})
fail2ban SSH 防护: $fail2ban_summary
abuse 自动通报: $DODO_ENABLE_ABUSE_REPORTS
Spamhaus 额外收件人: ${DODO_SPAMHAUS_REPORT_TO:-none}
关闭 SSH TCP forwarding: $DODO_DISABLE_TCP_FORWARDING

请保持当前 SSH 会话不要关闭，完成后用新连接验证。
EOF
    elif [ "$DODO_LANG" = "ja" ]; then
        cat <<EOF
以下の設定で実行します。

対象ユーザー: $DODO_USER
SSH 鍵導入: $DODO_INSTALL_KEYS
検出システム: $PLATFORM / $OS_NAME / $SSH_IMPL
パスワードログイン無効化: $DODO_DISABLE_PASSWORD_LOGIN
SSH ポート 10022 へ変更: $DODO_CHANGE_SSH_PORT
$pve_summary
Debian 13 upgrade: $DODO_UPGRADE_DEBIAN13 (${DODO_DEBIAN13_MIRROR})
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
Change SSH port to 10022: $DODO_CHANGE_SSH_PORT
$pve_summary
Debian 13 upgrade: $DODO_UPGRADE_DEBIAN13 (${DODO_DEBIAN13_MIRROR})
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
        DODO_USER="$(ui_inputbox "Configuring dodo-sshkey" "User for authorized_keys." "$DODO_USER" 9 72)" || return 1
        if ui_yesno "Configuring dodo-sshkey" "Disable SSH password login?" 9 72 "$DODO_DISABLE_PASSWORD_LOGIN"; then
            DODO_DISABLE_PASSWORD_LOGIN="1"
        else
            DODO_DISABLE_PASSWORD_LOGIN="0"
        fi
        if ui_yesno "Configuring dodo-sshkey" "Change SSH port to 10022?" 9 78 "$DODO_CHANGE_SSH_PORT"; then
            DODO_CHANGE_SSH_PORT="1"
            DODO_SSH_PORT="10022"
            DODO_KEEP_OLD_SSH_PORT="0"
        else
            DODO_CHANGE_SSH_PORT="0"
        fi
        if ui_yesno "Configuring dodo-sshkey" "Enable fail2ban SSH blacklist?" 9 78 "$DODO_ENABLE_FAIL2BAN"; then
            DODO_ENABLE_FAIL2BAN="1"
        else
            DODO_ENABLE_FAIL2BAN="0"
        fi
        if ui_yesno "Configuring dodo-sshkey" "Send abuse report email when fail2ban bans an IP?" 10 78 "$DODO_ENABLE_ABUSE_REPORTS"; then
            DODO_ENABLE_ABUSE_REPORTS="1"
            DODO_SPAMHAUS_REPORT_TO="$(ui_inputbox "Configuring dodo-sshkey" "Extra report destination such as Spamhaus. Empty is OK." "$DODO_SPAMHAUS_REPORT_TO" 10 78)" || return 1
        else
            DODO_ENABLE_ABUSE_REPORTS="0"
        fi
        if ui_yesno "Configuring dodo-sshkey" "Disable SSH TCP forwarding? Choose No if you use tunnels or port forwards." 11 78 "$DODO_DISABLE_TCP_FORWARDING"; then
            DODO_DISABLE_TCP_FORWARDING="1"
        else
            DODO_DISABLE_TCP_FORWARDING="0"
        fi
        return 0
    fi

    if [ "$DODO_LANG" = "zh" ]; then
        DODO_USER="$(tty_prompt "authorized_keys 用户" "$DODO_USER")"
        if prompt_yes_no "关闭 SSH 密码登录" "$DODO_DISABLE_PASSWORD_LOGIN"; then
            DODO_DISABLE_PASSWORD_LOGIN="1"
        else
            DODO_DISABLE_PASSWORD_LOGIN="0"
        fi
        if prompt_yes_no "将 SSH 端口改为 10022" "$DODO_CHANGE_SSH_PORT"; then
            DODO_CHANGE_SSH_PORT="1"
            DODO_SSH_PORT="10022"
            DODO_KEEP_OLD_SSH_PORT="0"
        else
            DODO_CHANGE_SSH_PORT="0"
        fi
        if prompt_yes_no "启用 fail2ban SSH 防爆破" "$DODO_ENABLE_FAIL2BAN"; then
            DODO_ENABLE_FAIL2BAN="1"
        else
            DODO_ENABLE_FAIL2BAN="0"
        fi
        if prompt_yes_no "fail2ban 封禁时发送 abuse 邮件" "$DODO_ENABLE_ABUSE_REPORTS"; then
            DODO_ENABLE_ABUSE_REPORTS="1"
            DODO_SPAMHAUS_REPORT_TO="$(tty_prompt "Spamhaus 等额外报告收件人（可留空）" "$DODO_SPAMHAUS_REPORT_TO")"
        else
            DODO_ENABLE_ABUSE_REPORTS="0"
        fi
        if prompt_yes_no "关闭 SSH TCP forwarding" "$DODO_DISABLE_TCP_FORWARDING"; then
            DODO_DISABLE_TCP_FORWARDING="1"
        else
            DODO_DISABLE_TCP_FORWARDING="0"
        fi
    elif [ "$DODO_LANG" = "ja" ]; then
        DODO_USER="$(tty_prompt "authorized_keys を設定するユーザー" "$DODO_USER")"
        if prompt_yes_no "SSH パスワードログインを無効化しますか" "$DODO_DISABLE_PASSWORD_LOGIN"; then
            DODO_DISABLE_PASSWORD_LOGIN="1"
        else
            DODO_DISABLE_PASSWORD_LOGIN="0"
        fi
        if prompt_yes_no "SSH ポートを 10022 に変更しますか" "$DODO_CHANGE_SSH_PORT"; then
            DODO_CHANGE_SSH_PORT="1"
            DODO_SSH_PORT="10022"
            DODO_KEEP_OLD_SSH_PORT="0"
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
            DODO_KEEP_OLD_SSH_PORT="0"
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

firewall_summary() {
    found="0"

    if have_cmd pve-firewall; then
        status="$(pve-firewall status 2>/dev/null | head -n 1 || true)"
        printf 'pve-firewall: %s\n' "${status:-installed}"
        found="1"
    fi

    if have_cmd ufw; then
        status="$(ufw status 2>/dev/null | head -n 1 || true)"
        printf 'ufw: %s\n' "${status:-installed}"
        found="1"
    fi

    if have_cmd firewall-cmd; then
        if firewall-cmd --state >/dev/null 2>&1; then
            printf 'firewalld: running\n'
        else
            printf 'firewalld: installed, not running\n'
        fi
        found="1"
    fi

    if have_cmd nft; then
        table_count="$(nft list tables 2>/dev/null | wc -l | awk '{print $1}')"
        printf 'nftables: available, tables=%s\n' "${table_count:-0}"
        found="1"
    fi

    if have_cmd iptables; then
        printf 'iptables: available\n'
        found="1"
    fi

    if have_cmd ip6tables; then
        printf 'ip6tables: available\n'
        found="1"
    fi

    if [ "$found" = "0" ]; then
        printf 'none detected\n'
    fi
}

recommended_firewall_precheck() {
    [ "$OS_ID" = "debian" ] || return 0
    case "$OS_VERSION_ID" in
        11|12) ;;
        *) return 0 ;;
    esac

    have_cmd nft && return 0

    current_firewall="$(firewall_summary)"
    if can_prompt; then
        if [ -n "$UI_TOOL" ]; then
            message="$(cat <<EOF
Debian $OS_VERSION_ID detected, but nftables command was not found.

Current firewall:
$current_firewall

Recommended: go back and use Debian 13 upgrade first.
If you continue, this script will try to install nftables.

Continue this profile?
EOF
)"
        elif [ "$DODO_LANG" = "zh" ]; then
            message="$(cat <<EOF
检测到 Debian $OS_VERSION_ID，但没有检测到 nftables 命令。

当前防火墙:
$current_firewall

推荐先从主菜单进入 Debian 13 upgrade，再选择 Global 或 CN 源升级。
如果继续，脚本会尝试安装 nftables 并继续配置。

是否继续当前推荐配置？
EOF
)"
        elif [ "$DODO_LANG" = "ja" ]; then
            message="$(cat <<EOF
Debian $OS_VERSION_ID を検出しましたが、nftables コマンドが見つかりません。

現在の firewall:
$current_firewall

先にメインメニューから Debian 13 upgrade を選択し、Global または CN source でアップグレードすることを推奨します。
続行する場合、スクリプトは nftables のインストールを試行して設定を続けます。

この推奨設定を続行しますか？
EOF
)"
        else
            message="$(cat <<EOF
Debian $OS_VERSION_ID was detected, but the nftables command was not found.

Current firewall:
$current_firewall

Recommended path: return to the main menu, choose Debian 13 upgrade, then select Global or CN source.
If you continue, the script will try to install nftables and continue.

Continue with this recommended profile?
EOF
)"
        fi

        if [ -n "$UI_TOOL" ]; then
            ui_yesno "Configuring dodo-sshkey" "$message" 18 86 0
        else
            tty_print "$message"
            prompt_yes_no "Continue" "0"
        fi
        return $?
    fi

    warn "Debian $OS_VERSION_ID without nftables detected. Current firewall: $(printf '%s' "$current_firewall" | tr '\n' '; ')"
    warn "Recommended: run Debian 13 upgrade first, or allow this script to install nftables."
    return 0
}

select_debian13_mirror() {
    if [ -n "$UI_TOOL" ]; then
        if [ "$DODO_LANG" = "zh" ]; then
            answer="$(ui_menu "Configuring dodo-sshkey" "Debian 13 upgrade source." 13 78 2 \
                "global" "Global CDN: deb.debian.org" \
                "cn" "CN: Aliyun mirrors")" || return 1
        elif [ "$DODO_LANG" = "ja" ]; then
            answer="$(ui_menu "Configuring dodo-sshkey" "Debian 13 upgrade source." 13 78 2 \
                "global" "Global CDN: deb.debian.org" \
                "cn" "CN: Aliyun mirrors")" || return 1
        else
            answer="$(ui_menu "Configuring dodo-sshkey" "Debian 13 upgrade source." 13 78 2 \
                "global" "Global CDN: deb.debian.org" \
                "cn" "CN: Aliyun mirrors")" || return 1
        fi
        DODO_DEBIAN13_MIRROR="$answer"
        return 0
    fi

    tty_print ""
    tty_print "Debian 13 upgrade source:"
    tty_print "1) Global CDN: deb.debian.org"
    tty_print "2) CN: Aliyun mirrors"
    while :; do
        answer="$(tty_prompt "Select source" "1")"
        case "$answer" in
            1|global|Global|GLOBAL) DODO_DEBIAN13_MIRROR="global"; return 0 ;;
            2|cn|CN|china|China) DODO_DEBIAN13_MIRROR="cn"; return 0 ;;
            *) tty_print "Please select 1 or 2." ;;
        esac
    done
}

confirm_pve_firewall_profile() {
    if [ "$DODO_LANG" = "zh" ] && [ "$UI_UTF8" = "1" ]; then
        message="$(cat <<EOF
将只配置 Proxmox VE 防火墙。

不会导入 SSH key。
不会修改 SSH 端口。
不会修改 SSH 密码登录。

数据中心 Options:
- Firewall: enabled
- ebtables: enabled
- Log rate limit: enable=1,rate=1/second,burst=5
- Input policy: DROP
- Output policy: ACCEPT
- Forward policy: ACCEPT

数据中心 Rules:
- Allow TCP 10022
- Allow Web
- Allow TCP 8006

节点 Options:
- Firewall: enabled
- SMURFS filter: enabled
- TCP flags filter: disabled
- NDP: enabled
- nftables technical preview: disabled
- Log levels: nolog

不会添加节点级别 firewall rules。
EOF
)"
    elif [ "$DODO_LANG" = "ja" ] && [ "$UI_UTF8" = "1" ]; then
        message="$(cat <<EOF
Proxmox VE firewall のみ設定します。

SSH key は導入しません。
SSH port は変更しません。
SSH password login は変更しません。

Datacenter Options:
- Firewall: enabled
- ebtables: enabled
- Log rate limit: enable=1,rate=1/second,burst=5
- Input policy: DROP
- Output policy: ACCEPT
- Forward policy: ACCEPT

Datacenter Rules:
- Allow TCP 10022
- Allow Web
- Allow TCP 8006

Node Options:
- Firewall: enabled
- SMURFS filter: enabled
- TCP flags filter: disabled
- NDP: enabled
- nftables technical preview: disabled
- Log levels: nolog

Node-level firewall rules は追加しません。
EOF
)"
    else
        message="$(cat <<EOF
This will configure Proxmox VE firewall only.

It will not import SSH keys.
It will not change SSH port.
It will not change SSH password login.

Datacenter options:
- Firewall: enabled
- ebtables: enabled
- Log rate limit: enable=1,rate=1/second,burst=5
- Input policy: DROP
- Output policy: ACCEPT
- Forward policy: ACCEPT

Datacenter rules:
- Allow TCP 10022
- Allow Web
- Allow TCP 8006

Node options:
- Firewall: enabled
- SMURFS filter: enabled
- TCP flags filter: disabled
- NDP: enabled
- nftables technical preview: disabled
- Log levels: nolog

No node-level firewall rules will be added.
EOF
)"
    fi

    if [ -n "$UI_TOOL" ]; then
        ui_yesno "Configuring dodo-sshkey" "$message" 31 92 0
    else
        tty_print "$message"
        prompt_yes_no "Continue with PVE firewall import" "0"
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
        if [ "$DODO_LANG" = "zh" ] && [ "$UI_UTF8" = "1" ]; then
            menu_text="$(cat <<EOF
检测: $PLATFORM / $OS_NAME
SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}

请选择要执行的配置。
EOF
)"
            answer="$(ui_menu "Configuring dodo-sshkey" "$menu_text" 22 100 6 \
                "推荐配置" "SSH 10022 + key 登录 + 关闭密码登录 + fail2ban 黑名单 + 关闭隧道" \
                "导入PVE防火墙" "导入 Proxmox VE 防火墙规则和 Options" \
                "升级Debian13" "Debian 11/12 升级到 13，下一步选择 Global 或 CN 源" \
                "Key和端口" "导入 authorized_keys + SSH 10022 + 关闭密码登录" \
                "自定义设置" "手动选择 SSH/fail2ban/PVE 项目" \
                "取消" "不做修改并退出")" || {
                    DODO_LANG=""
                    select_language
                    continue
                }
        elif [ "$DODO_LANG" = "ja" ] && [ "$UI_UTF8" = "1" ]; then
            menu_text="$(cat <<EOF
検出: $PLATFORM / $OS_NAME
SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}

実行する設定を選択してください。
EOF
)"
            answer="$(ui_menu "Configuring dodo-sshkey" "$menu_text" 22 100 6 \
                "推奨設定" "SSH 10022 + key login + password login off + fail2ban blacklist + tunnel off" \
                "PVE-FW導入" "Proxmox VE firewall rules/options を導入" \
                "Debian13更新" "Debian 11/12 を 13 へ更新。次画面で Global / CN source を選択" \
                "KeyとPort" "authorized_keys 導入 + SSH 10022 + password login off" \
                "カスタム設定" "SSH/fail2ban/PVE 項目を手動選択" \
                "中止" "変更せず終了")" || {
                    DODO_LANG=""
                    select_language
                    continue
                }
        else
            menu_text="$(cat <<EOF
Detected: $PLATFORM / $OS_NAME
SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}

Select the change to apply.
EOF
)"
            answer="$(ui_menu "Configuring dodo-sshkey" "$menu_text" 22 100 6 \
                "recommended" "SSH 10022, key login, password off, fail2ban blacklist, tunnels off" \
                "import-pve-fw" "import Proxmox VE firewall rules and options" \
                "debian13-upgrade" "upgrade Debian 11/12 to 13; choose Global or CN source next" \
                "key-and-port" "install authorized_keys, SSH 10022, password login off" \
                "custom-setup" "choose SSH/fail2ban/PVE options manually" \
                "cancel" "exit without changes")" || {
                    DODO_LANG=""
                    select_language
                    continue
                }
        fi

        case "$answer" in
            recommended|ssh-10022-fail2ban|推荐配置|推奨設定)
                recommended_firewall_precheck || continue
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="1"
                ;;
            pvefw|pve-firewall|import-pve-fw|导入PVE防火墙|PVE-FW導入)
                if [ "$PLATFORM" != "proxmox" ]; then
                    ui_msgbox "Configuring dodo-sshkey" "This feature is only available on Proxmox VE. Returning to the main menu." 9 78 || true
                    continue
                fi
                confirm_pve_firewall_profile || continue
                DODO_INSTALL_KEYS="0"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="1"
                DODO_UPGRADE_DEBIAN13="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                ;;
            debian13|debian13-upgrade|升级Debian13|Debian13更新)
                select_debian13_mirror || continue
                DODO_INSTALL_KEYS="0"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="1"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                ;;
            keys|keys-ssh10022|key-and-port|Key和端口|KeyとPort)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                ;;
            custom|custom-options|custom-setup|自定义设置|カスタム設定)
                DODO_INSTALL_KEYS="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="0"
                custom_menu || continue
                ;;
            cancel|取消|中止)
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

    if [ "$DODO_LANG" = "zh" ]; then
        tty_print ""
        tty_print "========================================"
        tty_print " DODO-SSHKEY 配置"
        tty_print "========================================"
        tty_print "检测: $PLATFORM / $OS_NAME / SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}"
        tty_print ""
        tty_print "1) 推荐配置: SSH 10022 + key 登录 + 关闭密码登录 + fail2ban 黑名单 + 关闭隧道"
        tty_print "2) 导入 PVE 防火墙规则"
        tty_print "3) Debian 13 upgrade: 进入后选择 Global CDN 或 CN Aliyun 源"
        tty_print "4) Key only and Port Change: 导入 key + SSH 10022 + 关闭密码登录"
        tty_print "5) Custom 设置"
        tty_print "6) 取消"
    elif [ "$DODO_LANG" = "ja" ]; then
        tty_print ""
        tty_print "========================================"
        tty_print " DODO-SSHKEY セットアップ"
        tty_print "========================================"
        tty_print "検出: $PLATFORM / $OS_NAME / SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}"
        tty_print ""
        tty_print "1) 推奨設定: SSH 10022 + key login + password login off + fail2ban blacklist + tunnel off"
        tty_print "2) PVE firewall rules を導入"
        tty_print "3) Debian 13 upgrade: 次画面で Global CDN / CN Aliyun を選択"
        tty_print "4) Key only and Port Change: key 導入 + SSH 10022 + password login off"
        tty_print "5) Custom 設定"
        tty_print "6) 中止"
    else
        tty_print ""
        tty_print "========================================"
        tty_print " DODO-SSHKEY Setup"
        tty_print "========================================"
        tty_print "Detected: $PLATFORM / $OS_NAME / SSH: $SSH_IMPL / PKG: ${PKG_MANAGER:-none}"
        tty_print ""
        tty_print "1) Recommended: SSH 10022 + key login + password off + fail2ban blacklist + tunnels off"
        tty_print "2) Import PVE firewall rules"
        tty_print "3) Debian 13 upgrade: choose Global CDN or CN Aliyun in the next screen"
        tty_print "4) Key only and Port Change: keys + SSH 10022 + password login off"
        tty_print "5) Custom setup"
        tty_print "6) Cancel"
    fi

    while :; do
        if [ "$DODO_LANG" = "zh" ]; then
            answer="$(tty_prompt "选择配置方案" "1")"
        elif [ "$DODO_LANG" = "ja" ]; then
            answer="$(tty_prompt "設定方案を選択" "1")"
        else
            answer="$(tty_prompt "Select profile" "1")"
        fi

        case "$answer" in
            1)
                recommended_firewall_precheck || continue
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="1"
                break
                ;;
            2)
                if [ "$PLATFORM" != "proxmox" ]; then
                    if [ "$DODO_LANG" = "zh" ]; then
                        tty_print "此选项只适用于 Proxmox VE。"
                    elif [ "$DODO_LANG" = "ja" ]; then
                        tty_print "このオプションは Proxmox VE でのみ利用できます。"
                    else
                        tty_print "This option is only available on Proxmox VE."
                    fi
                    continue
                fi
                confirm_pve_firewall_profile || continue
                DODO_INSTALL_KEYS="0"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="1"
                DODO_UPGRADE_DEBIAN13="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                break
                ;;
            3)
                select_debian13_mirror
                DODO_INSTALL_KEYS="0"
                DODO_DISABLE_PASSWORD_LOGIN="0"
                DODO_CHANGE_SSH_PORT="0"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="1"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                break
                ;;
            4)
                DODO_INSTALL_KEYS="1"
                DODO_DISABLE_PASSWORD_LOGIN="1"
                DODO_CHANGE_SSH_PORT="1"
                DODO_SSH_PORT="10022"
                DODO_KEEP_OLD_SSH_PORT="0"
                DODO_ENABLE_FAIL2BAN="0"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="0"
                DODO_ENABLE_ABUSE_REPORTS="0"
                DODO_DISABLE_TCP_FORWARDING="0"
                break
                ;;
            5)
                DODO_INSTALL_KEYS="1"
                DODO_CONFIGURE_PVE_FIREWALL="0"
                DODO_UPGRADE_DEBIAN13="0"
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
    if [ "$DODO_LANG" = "zh" ]; then
        prompt_yes_no "是否执行此配置" "1" || die "Canceled by user."
    elif [ "$DODO_LANG" = "ja" ]; then
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
        OS_VERSION_ID="${VERSION_ID:-}"
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

upgrade_debian13() {
    [ "$DODO_UPGRADE_DEBIAN13" = "1" ] || return 0

    [ "$PLATFORM" != "proxmox" ] || die "Debian 13 upgrade is disabled on Proxmox VE. Use the Proxmox-supported upgrade path instead."
    [ "$PLATFORM" != "openwrt" ] || die "Debian 13 upgrade is not available on OpenWrt."
    [ "$OS_ID" = "debian" ] || die "Debian 13 upgrade is only available on Debian systems."
    [ "$PKG_MANAGER" = "apt" ] || die "Debian 13 upgrade requires apt."

    version_id=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        version_id="${VERSION_ID:-}"
    fi

    case "$version_id" in
        13)
            log "System is already Debian 13; running package refresh only."
            ;;
        11|12)
            log "Preparing Debian $version_id -> Debian 13 upgrade."
            ;;
        *)
            die "Only Debian 11/12 -> Debian 13 upgrade is supported by this script. Detected VERSION_ID=${version_id:-unknown}."
            ;;
    esac

    case "$DODO_DEBIAN13_MIRROR" in
        cn)
            debian_uri="https://mirrors.aliyun.com/debian"
            security_uri="https://mirrors.aliyun.com/debian-security"
            ;;
        global|"")
            debian_uri="https://deb.debian.org/debian"
            security_uri="https://security.debian.org/debian-security"
            ;;
        *)
            die "Invalid DODO_DEBIAN13_MIRROR: $DODO_DEBIAN13_MIRROR"
            ;;
    esac

    export DEBIAN_FRONTEND=noninteractive
    log "Installing Debian archive keyring and HTTPS certificates before source switch."
    apt-get update || warn "apt-get update failed before source switch; continuing with source rewrite."
    apt-get install -y debian-archive-keyring ca-certificates || warn "Failed to refresh keyring/certificates before source switch."

    backup_dir="/root/dodo-sshkey-apt-backup-$(date +%Y%m%d%H%M%S)"
    install -d -m 700 "$backup_dir/sources.list.d"
    [ ! -f /etc/apt/sources.list ] || cp -a /etc/apt/sources.list "$backup_dir/sources.list"
    if [ -d /etc/apt/sources.list.d ]; then
        cp -a /etc/apt/sources.list.d/. "$backup_dir/sources.list.d/" 2>/dev/null || true
    else
        install -d -m 755 /etc/apt/sources.list.d
    fi

    if [ -f /etc/apt/sources.list ]; then
        : >/etc/apt/sources.list
    fi

    for file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [ -f "$file" ] || continue
        case "$file" in
            *.dodo-disabled) continue ;;
            *) mv "$file" "$file.dodo-disabled" ;;
        esac
    done

    cat >/etc/apt/sources.list.d/dodo-debian13.sources <<EOF
Types: deb
URIs: $debian_uri
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: $security_uri
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

    log "APT sources switched to Debian 13 trixie ($DODO_DEBIAN13_MIRROR). Backup: $backup_dir"
    apt-get update
    apt-get -y upgrade
    apt-get -y dist-upgrade
    apt-get -y autoremove
    log "Debian 13 upgrade flow completed. Reboot the server and verify /etc/os-release."
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
    log "Detected firewall tools: $(firewall_summary | tr '\n' '; ')"

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

    if have_cmd nft; then
        nft add table inet dodo-sshkey 2>/dev/null || true
        nft 'add chain inet dodo-sshkey input { type filter hook input priority -10; policy accept; }' 2>/dev/null || true
        if ! nft list chain inet dodo-sshkey input 2>/dev/null | grep -q "tcp dport $port accept"; then
            nft add rule inet dodo-sshkey input tcp dport "$port" accept 2>/dev/null || \
                warn "Failed to add nftables allow rule for TCP $port."
        fi
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

    if have_cmd fail2ban-client && have_cmd nft; then
        return 0
    fi

    log "Installing fail2ban/nftables..."
    case "$PKG_MANAGER" in
        apt) pkg_install fail2ban nftables whois ca-certificates || warn "Failed to install fail2ban/nftables packages." ;;
        dnf|yum) pkg_install fail2ban nftables whois bind-utils ca-certificates || warn "Failed to install fail2ban/nftables packages. On RHEL-compatible systems, EPEL may be required." ;;
        zypper) pkg_install fail2ban nftables whois ca-certificates || warn "Failed to install fail2ban/nftables packages." ;;
        apk) pkg_install fail2ban nftables whois ca-certificates || warn "Failed to install fail2ban/nftables packages." ;;
        pacman) pkg_install fail2ban nftables whois ca-certificates || warn "Failed to install fail2ban/nftables packages." ;;
        *) pkg_install fail2ban nftables whois || warn "Failed to install fail2ban/nftables packages." ;;
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
    have_cmd nft || warn "nft command was not found; fail2ban nftables action may not be able to enforce bans until nftables is installed."

    install -d -m 755 /etc/fail2ban/jail.d
    fail2ban_ssh_port="ssh"
    if [ "$DODO_CHANGE_SSH_PORT" = "1" ]; then
        fail2ban_ssh_port="$DODO_SSH_PORT"
    fi

    fail2ban_backend="auto"
    fail2ban_logpath=""
    if have_cmd journalctl && [ -d /run/systemd/system ]; then
        fail2ban_backend="systemd"
    else
        for candidate in /var/log/auth.log /var/log/secure /var/log/messages; do
            if [ -f "$candidate" ]; then
                fail2ban_logpath="$candidate"
                break
            fi
        done
        if [ -z "$fail2ban_logpath" ]; then
            warn "No SSH auth log file found; skipping fail2ban sshd jail to avoid service startup failure."
            return 0
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
backend = $fail2ban_backend
maxretry = 3
findtime = 10m
bantime = 12h
ignoreip = 127.0.0.1/8 ::1
banaction = nftables-multiport
banaction_allports = nftables-allports
action = $action_lines
EOF

    if [ -n "$fail2ban_logpath" ]; then
        {
            echo "logpath = $fail2ban_logpath"
        } >>/etc/fail2ban/jail.d/dodo-sshd.conf
    fi

    if [ -f /var/log/fail2ban.log ]; then
        cat >>/etc/fail2ban/jail.d/dodo-sshd.conf <<EOF

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
maxretry = 5
findtime = 1d
bantime = 1w
EOF
    fi

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

    if [ "$DODO_UPGRADE_DEBIAN13" = "1" ]; then
        upgrade_debian13
        return 0
    fi

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
