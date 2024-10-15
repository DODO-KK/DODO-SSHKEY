#!/bin/bash

# ユーザー名を設定
USER="root"  # ユーザー名は root に設定
KEY_URL="https://raw.githubusercontent.com/DODO-KK/DODO-SSHKEY/refs/heads/main/authorized_keys"

# 現在の authorized_keys ファイルをバックアップ
if [ -f "/root/.ssh/authorized_keys" ]; then
    cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bak
    echo "現在の authorized_keys を authorized_keys.bak にバックアップしました"
fi

# 新しい authorized_keys ファイルをダウンロード
echo "から $KEY_URL 新しい authorized_keys ファイルをダウンロードしています..."
curl -o /root/.ssh/authorized_keys $KEY_URL

# パーミッションを設定
chmod 600 /root/.ssh/authorized_keys
chmod 700 /root/.ssh

# パスワードログインを無効にする
echo "パスワードログインを無効にしています..."
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# SSH サービスを再起動
echo "SSH サービスを再起動しています..."
systemctl restart sshd  # 一部のシステムでは sshd を使用する必要があります

echo "操作が完了しました。新しい SSH キーを使用してログインできることを確認してください。"
