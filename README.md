# DODO-SSHKEY

Interactive SSH key import and SSH hardening script for DODO K.K.

## English

### Run

Run as root:

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | sh
```

If your system uses `sudo`:

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | sudo sh
```

### Flow

1. Select language: English or Japanese.
2. The script detects the system and SSH service.
3. Select a setup profile from the terminal menu.
4. Review the summary and confirm.
5. Keep the current SSH session open and test a new key login.
6. If the selected profile changes the SSH port, reconnect with `ssh -p 10022`.
7. Make sure local firewall, Proxmox firewall, or cloud security groups allow TCP `10022`.

### Menu Profiles

- Recommended: import keys, change SSH port to `10022`, disable SSH password login, enable fail2ban.
- Strict: recommended profile plus disable SSH TCP forwarding.
- Keys only: update `authorized_keys` only.
- Custom: choose each option manually.

### Features

- Imports DODO `authorized_keys`.
- Backs up existing SSH key/config files before changes.
- Detects Linux, Proxmox VE, and OpenWrt.
- Supports OpenSSH and OpenWrt Dropbear.
- Changes SSH service port to `10022` when selected.
- Disables password login for Linux/Proxmox/OpenWrt when selected.
- Adds OpenSSH hardening options.
- Configures fail2ban SSH brute-force protection on supported Linux systems.
- Optional fail2ban abuse reporting with RIR WHOIS abuse contact lookup.
- Optional additional Spamhaus-compatible report destination.

### Supported Systems

- Debian / Ubuntu / Proxmox VE
- RHEL-compatible systems with `dnf` or `yum`
- openSUSE / SUSE with `zypper`
- Alpine Linux
- Arch Linux
- OpenWrt with Dropbear
- Other Linux systems with OpenSSH may work if required tools are present.

### Non-Interactive Example

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | \
  DODO_NONINTERACTIVE=1 DODO_CHANGE_SSH_PORT=1 DODO_SSH_PORT=10022 DODO_DISABLE_PASSWORD_LOGIN=1 DODO_ENABLE_FAIL2BAN=1 sh
```

## 日本語

### 実行方法

root で実行してください。

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | sh
```

`sudo` を使う環境では:

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | sudo sh
```

### 流れ

1. 言語を選択します: English または 日本語。
2. スクリプトが OS と SSH サービスを自動検出します。
3. ターミナル画面で設定方案を選択します。
4. 設定内容を確認して実行します。
5. 現在の SSH セッションを閉じずに、新しい鍵ログインを確認してください。
6. SSH ポートを変更した場合は `ssh -p 10022` で再接続してください。
7. ローカル firewall、Proxmox firewall、クラウド security group で TCP `10022` を許可してください。

### 設定方案

- 推奨: SSH 鍵導入、SSH ポートを `10022` に変更、パスワードログイン無効化、fail2ban 有効化。
- 厳格: 推奨設定に加えて SSH TCP forwarding を無効化。
- キーのみ: `authorized_keys` のみ更新。
- カスタム: 各項目を手動で選択。

### 機能

- DODO の `authorized_keys` を導入。
- 変更前に既存の SSH 鍵/設定ファイルをバックアップ。
- Linux、Proxmox VE、OpenWrt を自動検出。
- OpenSSH と OpenWrt Dropbear に対応。
- 選択時に SSH サービスポートを `10022` に変更。
- 選択時に Linux/Proxmox/OpenWrt のパスワードログインを無効化。
- OpenSSH の基本的なセキュリティ強化設定を追加。
- 対応 Linux で fail2ban による SSH ブルートフォース対策を設定。
- 任意で RIR WHOIS から abuse 連絡先を検索し、fail2ban ban 時に自動通報。
- 任意で Spamhaus 互換の追加通報先を設定可能。

### 対応システム

- Debian / Ubuntu / Proxmox VE
- `dnf` または `yum` を使用する RHEL 系
- `zypper` を使用する openSUSE / SUSE
- Alpine Linux
- Arch Linux
- Dropbear を使用する OpenWrt
- 必要ツールがある OpenSSH 搭載 Linux
