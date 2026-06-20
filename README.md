# DODO K.K. SSH Key Import

Import DODO authorized keys and apply basic SSH hardening for common Linux distributions, Proxmox VE, and OpenWrt.

## Quick Start

```sh
curl -o import_key.sh https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/import_key.sh
chmod +x import_key.sh
./import_key.sh
```

Keep the current SSH session open and verify that a new key-based login works before closing the old session.

## What It Does

- Detects common Linux distributions via `/etc/os-release`.
- Detects Proxmox VE via `pveversion` or `/etc/pve`.
- Detects OpenWrt/Dropbear via `/etc/openwrt_release` or `/etc/config/dropbear`.
- Installs `authorized_keys` for `root` by default.
- Backs up existing `authorized_keys` and SSH config files before replacing or editing them.
- Disables SSH password login on Linux/Proxmox OpenSSH.
- Disables Dropbear password login on OpenWrt.
- Adds OpenSSH hardening settings such as lower auth retry limits, shorter login grace time, verbose auth logging, and disabled X11/agent forwarding.
- Installs and configures fail2ban for SSH brute-force protection where supported.
- Optionally configures fail2ban abuse reporting.

## Configuration

Set environment variables before running the script:

```sh
DODO_USER=root \
DODO_DISABLE_PASSWORD_LOGIN=1 \
DODO_ENABLE_FAIL2BAN=1 \
./import_key.sh
```

Available variables:

| Variable | Default | Description |
| --- | --- | --- |
| `DODO_USER` | `root` | Linux user whose `~/.ssh/authorized_keys` is replaced. |
| `DODO_KEY_URL` | GitHub raw `authorized_keys` | Source URL for keys. |
| `DODO_DISABLE_PASSWORD_LOGIN` | `1` | Disable password login for OpenSSH/Dropbear. |
| `DODO_ENABLE_FAIL2BAN` | `1` | Install and configure fail2ban on Linux/Proxmox. |
| `DODO_ENABLE_ABUSE_REPORTS` | `0` | Enable automatic abuse email reporting from fail2ban bans. |
| `DODO_SPAMHAUS_REPORT_TO` | empty | Optional additional report destination for Spamhaus-compatible reporting workflows. |
| `DODO_DISABLE_TCP_FORWARDING` | `0` | Also disable SSH TCP forwarding. This may break legitimate tunnels. |

## Abuse Reporting

Automatic abuse reporting is off by default. To enable it:

```sh
DODO_ENABLE_ABUSE_REPORTS=1 ./import_key.sh
```

When enabled, fail2ban calls `/usr/local/sbin/dodo-fail2ban-abuse-report` on SSH bans. The reporter:

- queries WHOIS/RIR data from ARIN, RIPE, APNIC, LACNIC, and AFRINIC;
- extracts likely abuse/security/NOC contact emails;
- sends a short SSH brute-force/scanning report if the host has `sendmail`, `mail`, or `mailx`;
- optionally sends the same report to `DODO_SPAMHAUS_REPORT_TO`.

Edit `/etc/dodo-sshkey-abuse.conf` after installation to set sender, CC, Spamhaus destination, or dry-run mode.

Spamhaus reporting is intentionally configurable instead of hard-coded. Use the official reporting address or workflow for your account/process, then place that destination in `DODO_SPAMHAUS_REPORT_TO` or `/etc/dodo-sshkey-abuse.conf`.

## Notes

- OpenWrt uses Dropbear hardening and skips fail2ban by default.
- RHEL-compatible systems may need EPEL enabled before fail2ban is available.
- The script validates `sshd_config` with `sshd -t` before restarting OpenSSH. If validation fails, the previous config is restored.
