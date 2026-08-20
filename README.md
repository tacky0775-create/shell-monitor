# Shell Monitor

## 概要

Linuxサーバーのリソースを監視するシェルスクリプトです。

CPU、メモリ、ディスク使用率を取得し、
閾値を超えた場合に警告をログへ出力します。

cronによる定期実行を想定しています。

## 監視項目

- CPU使用率
- メモリ使用率
- ディスク使用率

## 使用技術

- Rocky Linux 9
- Bash
- cron
- Docker
- Git / GitHub

## 実行方法

```bash
cd monitor
./monitor.sh
