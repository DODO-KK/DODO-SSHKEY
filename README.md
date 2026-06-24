# DODO-SSHKEY

Interactive SSH key import and SSH hardening script for DODO K.K.

The setup screen uses the Debian-style `whiptail`/`dialog` interface when available, and falls back to a plain text menu on minimal systems. Chinese/Japanese UI requires a UTF-8 locale; otherwise the script falls back to English UI.

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

1. Select language: English, Japanese, or Chinese.
2. The script detects the system and SSH service.
3. Select a setup profile from the package-configuration style menu.
4. Review the summary and confirm.
5. Keep the current SSH session open and test a new key login.
6. If the selected profile changes the SSH port, test `ssh -p 10022`.
7. Make sure local firewall, Proxmox firewall, or cloud security groups allow TCP `10022`.
8. In the UI, `Esc`/`Cancel` returns to the previous menu layer.

### Menu Profiles

- Recommended: import keys, change SSH port to `10022`, disable SSH password login, enable fail2ban, and disable SSH tunnels/port forwarding.
- Proxmox firewall: configure only Proxmox firewall settings. It does not import keys or change SSH settings.
- Debian 13 upgrade: enter this profile, then choose Global CDN or CN Aliyun APT sources.
- Key only and Port Change: import `authorized_keys`, change SSH to TCP `10022`, and disable SSH password login.
- Custom: choose each option manually.

### Features

- Imports DODO `authorized_keys`.
- Uses a `whiptail`/`dialog` terminal UI when available.
- Uses Chinese/Japanese terminal UI when UTF-8 is available, with English fallback on non-UTF-8 consoles.
- Backs up existing SSH key/config files before changes.
- Detects Linux, Proxmox VE, and OpenWrt.
- Supports OpenSSH and OpenWrt Dropbear.
- Changes SSH service port to `10022` when selected.
- Detects common firewall tools including nftables, UFW, firewalld, iptables, ip6tables, and Proxmox firewall.
- Tries to open TCP `10022` in local nftables/UFW/firewalld/iptables where supported.
- On Debian 11/12 recommended profiles, warns when nftables is missing and recommends the Debian 13 upgrade path.
- On Proxmox VE, configures datacenter firewall options and adds datacenter-level rules for TCP `10022`, Web, and TCP `8006`.
- On Proxmox VE, configures node firewall options for PVE 8/9 without adding node-level rules.
- Disables password login for Linux/Proxmox/OpenWrt when selected.
- Adds OpenSSH hardening options.
- Recommended profile writes `AllowTcpForwarding no`; do not use it if the server must provide SSH tunnels, SOCKS proxy, or port forwarding.
- Configures fail2ban SSH brute-force protection with nftables bans on supported Linux systems.
- Optional fail2ban abuse reporting with RIR WHOIS abuse contact lookup.
- Optional additional Spamhaus-compatible report destination.
- Debian 11/12 to Debian 13 upgrade option with Global CDN or CN Aliyun APT sources. This option is disabled on Proxmox VE.

### Proxmox Firewall Profile

Datacenter options:

- Firewall: enabled
- ebtables: enabled
- Log rate limit: `enable=1,rate=1/second,burst=5`
- Input policy: `DROP`
- Output policy: `ACCEPT`
- Forward policy: `ACCEPT`

Datacenter rules:

- Accept TCP `10022`
- Accept `Web`
- Accept TCP `8006`

Node options for PVE 8/9:

- Firewall: enabled
- SMURFS filter: enabled
- TCP flags filter: disabled
- NDP: enabled
- nftables technical preview: disabled
- Firewall log levels: `nolog`

No node-level firewall rules are added.

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

Debian 11/12 to Debian 13 with Global CDN:

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | \
  DODO_NONINTERACTIVE=1 DODO_UPGRADE_DEBIAN13=1 DODO_DEBIAN13_MIRROR=global sh
```

Debian 11/12 to Debian 13 with Aliyun mirrors:

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | \
  DODO_NONINTERACTIVE=1 DODO_UPGRADE_DEBIAN13=1 DODO_DEBIAN13_MIRROR=cn sh
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

1. 言語を選択します: English、Japanese、Chinese。
2. スクリプトが OS と SSH サービスを自動検出します。
3. package configuration 風の画面で設定方案を選択します。
4. 設定内容を確認して実行します。
5. 現在の SSH セッションを閉じずに、新しい鍵ログインを確認してください。
6. SSH ポートを変更した場合は `ssh -p 10022` をテストしてください。
7. ローカル firewall、Proxmox firewall、クラウド security group で TCP `10022` を許可してください。
8. UI では `Esc`/`Cancel` で前の階層に戻ります。

### 設定方案

- 推奨: SSH 鍵導入、SSH ポートを `10022` に変更、パスワードログイン無効化、fail2ban 有効化、SSH tunnel/port forwarding 無効化。
- Proxmox firewall: Proxmox firewall のみ設定。SSH 鍵導入や SSH 設定変更は行いません。
- Debian 13 upgrade: この項目に入った後、Global CDN または CN Aliyun APT source を選択。
- Key only and Port Change: `authorized_keys` を導入し、SSH を TCP `10022` に変更し、password login を無効化。
- カスタム: 各項目を手動で選択。

### 機能

- DODO の `authorized_keys` を導入。
- 利用可能な場合は `whiptail`/`dialog` のターミナル UI を使用。
- UTF-8 が利用可能な場合は日本語/中国語 terminal UI を使用し、非 UTF-8 console では英語 UI に fallback。
- 変更前に既存の SSH 鍵/設定ファイルをバックアップ。
- Linux、Proxmox VE、OpenWrt を自動検出。
- OpenSSH と OpenWrt Dropbear に対応。
- 選択時に SSH サービスポートを `10022` に変更。
- nftables、UFW、firewalld、iptables、ip6tables、Proxmox firewall など一般的な firewall tool を検出。
- 対応環境では nftables/UFW/firewalld/iptables に TCP `10022` の許可を追加。
- Debian 11/12 の推奨設定では、nftables がない場合に警告し、Debian 13 upgrade path を推奨。
- Proxmox VE ではデータセンター firewall の Options を設定し、TCP `10022`、Web、TCP `8006` のデータセンター rules を追加。
- Proxmox VE では PVE 8/9 向けのノード firewall Options のみ設定し、ノード rules は追加しません。
- 選択時に Linux/Proxmox/OpenWrt のパスワードログインを無効化。
- OpenSSH の基本的なセキュリティ強化設定を追加。
- 推奨設定では `AllowTcpForwarding no` を設定。SSH tunnel、SOCKS proxy、port forwarding が必要な server では使用しないでください。
- 対応 Linux で nftables ban action を使う fail2ban SSH ブルートフォース対策を設定。
- 任意で RIR WHOIS から abuse 連絡先を検索し、fail2ban ban 時に自動通報。
- 任意で Spamhaus 互換の追加通報先を設定可能。
- Debian 11/12 から Debian 13 への upgrade option。Global CDN または CN Aliyun APT source を選択可能。Proxmox VE では無効です。

### Proxmox Firewall Profile

データセンター Options:

- Firewall: enabled
- ebtables: enabled
- Log rate limit: `enable=1,rate=1/second,burst=5`
- Input policy: `DROP`
- Output policy: `ACCEPT`
- Forward policy: `ACCEPT`

データセンター Rules:

- TCP `10022` を許可
- `Web` を許可
- TCP `8006` を許可

PVE 8/9 向けノード Options:

- Firewall: enabled
- SMURFS filter: enabled
- TCP flags filter: disabled
- NDP: enabled
- nftables technical preview: disabled
- Firewall log levels: `nolog`

ノードレベルの firewall rules は追加しません。

### 対応システム

- Debian / Ubuntu / Proxmox VE
- `dnf` または `yum` を使用する RHEL 系
- `zypper` を使用する openSUSE / SUSE
- Alpine Linux
- Arch Linux
- Dropbear を使用する OpenWrt
- 必要ツールがある OpenSSH 搭載 Linux

## 中文

### 运行方法

请用 root 执行：

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | sh
```

使用 `sudo` 的系统：

```sh
curl -fsSL https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh | sudo sh
```

### 流程

1. 选择语言：English、Japanese、Chinese。
2. 脚本自动检测系统、SSH 服务和包管理器。
3. 在界面中选择配置方案。
4. 确认配置摘要后执行。
5. 不要关闭当前 SSH 会话，先测试新连接。
6. 如果修改了 SSH 端口，请测试 `ssh -p 10022`。
7. 确认本机防火墙、Proxmox 防火墙或云安全组允许 TCP `10022`。
8. UI 中 `Esc`/`Cancel` 返回上一层。

### 配置方案

- 推荐：导入 SSH key、把 SSH 改为 `10022`、关闭密码登录、启用 fail2ban、关闭 SSH 隧道/端口转发。
- Proxmox firewall：只配置 Proxmox 防火墙，不导入 key，不修改 SSH。
- Debian 13 upgrade：进入后选择 Global CDN 或 CN Aliyun APT 源。
- Key only and Port Change：导入 `authorized_keys`，把 SSH 改为 TCP `10022`，并关闭密码登录。
- 自定义：手动选择每个项目。

### 功能

- 导入 DODO `authorized_keys`。
- 使用 `whiptail`/`dialog` 界面，最小系统会回退到文本菜单。
- UTF-8 可用时显示中文/日文终端 UI；Debian 11 等非 UTF-8 控制台会自动回退英文 UI。
- 修改前备份 SSH key 和配置文件。
- 自动检测 Linux、Proxmox VE、OpenWrt。
- 支持 OpenSSH 和 OpenWrt Dropbear。
- 推荐配置会写入 `AllowTcpForwarding no`；如果服务器需要 SSH 隧道、SOCKS 代理或端口转发，不要使用推荐配置，改用自定义。
- 识别 nftables、UFW、firewalld、iptables、ip6tables、Proxmox firewall。
- 支持为 TCP `10022` 添加本机防火墙放行规则。
- Debian 11/12 推荐配置会检查 nftables；没有 nftables 时会显示当前防火墙并推荐先升级 Debian 13。
- fail2ban 使用 nftables ban action。
- 可选 abuse 自动通报和 Spamhaus 兼容额外收件人。
- Debian 11/12 可升级到 Debian 13，支持 Global CDN 或 CN Aliyun 源。Proxmox VE 禁用此升级入口。
