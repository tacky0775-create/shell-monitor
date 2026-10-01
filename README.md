# Shell Monitor

LinuxサーバーのCPU・メモリ・ディスク使用率を定期的に監視し、異常値を検知した場合にAWSのCloudWatchとSNSを利用してメール通知する監視ツールです。

Shell Scriptによる監視処理の作成から、AWS EC2へのデプロイ、CloudWatch Logsへのログ転送、Metric Filterによる異常ログの検知、CloudWatch Alarmによるアラーム、SNSによるメール通知までを一通り構築しました。

## 概要

Linuxサーバー上でShell Scriptを5分間隔で実行し、以下のリソース使用率を取得します。

- CPU使用率
- メモリ使用率
- ディスク使用率

取得した情報はログファイルに記録し、設定した閾値を超えた場合にはWARNINGログを出力します。

WARNINGログをCloudWatch Logsへ転送し、Metric Filterで検知することでCloudWatch Alarmを発生させ、SNS経由でメール通知を行います。

## システム構成

```text
AWS EC2
  │
  ├─ monitor.sh
  │
  ├─ cron（5分間隔）
  │
  ↓
monitor.log
  │
  ↓
CloudWatch Logs
  │
  ↓
Metric Filter
  │
  ↓
CloudWatch Alarm
  │
  ↓
SNS
  │
  ↓
メール通知
```
## 使用技術

- Shell Script:	サーバーリソース監視
- Linux: 実行環境
- Amazon EC2: 監視対象サーバー
- Amazon Linux 2023: EC2 OS
- cron: 監視スクリプトの定期実行
- Amazon CloudWatch Logs: ログ収集
- CloudWatch Metric Filter: WARNINGログのメトリクス化
- CloudWatch Alarm: 閾値超過の検知
- Amazon SNS: メール通知
- IAM: EC2からCloudWatchへのアクセス権限管理
- Git / GitHub: ソースコード管理

## 監視仕様
**CPU**

CPU使用率が80%を超えた場合、WARNINGログを出力します。

WARNING: CPU usage is high.

**Memory**

メモリ使用率が80%を超えた場合、WARNINGログを出力します。

WARNING: MEMORY usage is high.

**Disk**

ディスク使用率が90%を超えた場合、WARNINGログを出力します。
WARNING: DISK usage is high.

**monitor.sh**
```bash
#!/bin/bash

LOGFILE="/opt/monitor/logs/monitor.log"
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int(100-$8)}')
MEMORY=$(free | awk '/Mem:/ {print int($3/$2*100)}')
DISK=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
DATE=$(date "+%Y-%m-%d %H:%M:%S")

echo "$DATE CPU:${CPU}% MEMORY:${MEMORY}% DISK:${DISK}%" >> "$LOGFILE"

if [ "$CPU" -gt 80 ]; then
    echo "$DATE WARNING: CPU usage is high." >> "$LOGFILE"
fi

if [ "$MEMORY" -gt 80 ]; then
    echo "$DATE WARNING: MEMORY usage is high." >> "$LOGFILE"
fi

if [ "$DISK" -gt 90 ]; then
    echo "$DATE WARNING: DISK usage is high." >> "$LOGFILE"
fi
```

## 処理内容

**CPU使用率**
```bash
top -bn1 | grep "Cpu(s)" | awk '{print int(100-$8)}'
```

topコマンドからCPU情報を取得し、idle値を利用してCPU使用率を算出しています。
```
CPU使用率 = 100 - CPU idle率
```

**メモリ使用率**
```bash
free | awk '/Mem:/ {print int($3/$2*100)}'
```
freeコマンドからメモリの使用量と総容量を取得し、使用率を算出しています。

**ディスク使用率**
```bash
df / | awk 'NR==2 {gsub("%","",$5); print $5}'
```
ルートファイルシステム / のディスク使用率を取得しています。

## 定期実行

cronを使用して5分間隔で監視スクリプトを実行しています。
```bash
*/5 * * * * /opt/monitor/monitor.sh
```
これにより、サーバーのリソース状況を定期的に取得します。

## AWS構成
**EC2**

Amazon Linux 2023を使用したEC2インスタンスに監視ツールをデプロイしています。

監視スクリプトは以下に配置しています。
```
/opt/monitor/
├── monitor.sh
└── logs/
    └── monitor.log
```
**CloudWatch Logs**

CloudWatch AgentをEC2へインストールし、以下のログをCloudWatch Logsへ送信しています。
```
/opt/monitor/logs/monitor.log
```
ロググループ：
```
/shell-monitor/monitor
```
ログストリームにはEC2のInstance IDを使用しています。

**IAM**

EC2にIAMロールを付与し、CloudWatch AgentからCloudWatch Logsへログを送信できるようにしています。

使用ポリシー：
```
CloudWatchAgentServerPolicy
```

## Metric Filter

CloudWatch Logsに出力されたWARNINGログをMetric Filterで検知しています。

**CPU**
```
Filter Pattern:
"WARNING: CPU usage is high."

Metric:
CPUWarningCount
```

**Memory**
```
Filter Pattern:
"WARNING: MEMORY usage is high."

Metric:
MemoryWarningCount
```

**Disk**
```
Filter Pattern:
"WARNING: DISK usage is high."

Metric:
DiskWarningCount
```
WARNINGが発生するたびにメトリクス値を1として記録する構成にしています。

## CloudWatch Alarm

Metric Filterで作成したメトリクスをCloudWatch Alarmで監視しています。

**CPU**
```
Alarm:
ShellMonitor-CPU-Warning

Metric:
CPUWarningCount

Statistic:
Sum

Condition:
>= 1
```

**Memory**
```
Alarm:
ShellMonitor-Memory-Warning

Metric:
MemoryWarningCount

Statistic:
Sum

Condition:
>= 1
```

**Disk**
```
Alarm:
ShellMonitor-Disk-Warning

Metric:
DiskWarningCount

Statistic:
Sum

Condition:
>= 1
```
WARNINGの発生回数をカウントするイベント型メトリクスのため、Statisticには Sum を使用しています。

## SNSによるメール通知

CloudWatch AlarmがALARM状態になった場合、Amazon SNSを利用してメール通知を行います。
```
CloudWatch Alarm
      ↓
SNS Topic
      ↓
Email
```
CPU・Memory・Diskの各監視項目について、実際にALARM状態への遷移とメール通知を確認しています。

## 動作確認
**CPU監視**

CPU負荷を発生させ、CPU使用率が閾値を超えることを確認しました。
```
CPU使用率上昇
    ↓
WARNINGログ出力
    ↓
CloudWatch Logsへ送信
    ↓
CPUWarningCountへ変換
    ↓
CloudWatch AlarmがALARM状態
    ↓
SNSからメール通知
```
メール通知まで正常に動作することを確認しました。

## Memory監視

Pythonによるメモリ負荷テストを実施し、メモリ使用率を80%超まで上昇させました。
```
Memory使用率上昇
    ↓
WARNINGログ出力
    ↓
CloudWatch Logsへ送信
    ↓
MemoryWarningCountへ変換
    ↓
CloudWatch AlarmがALARM状態
    ↓
SNSからメール通知
```
メール通知まで正常に動作することを確認しました。

## Disk監視

Disk監視については、EC2のディスク容量が8GBと小さいため、システムへの影響を避ける目的で、テスト時のみ閾値を一時的に20%へ変更しました。

ディスク使用率が27%の状態で監視スクリプトを実行し、WARNINGログが出力されることを確認しました。
```
Disk使用率 27%
    ↓
テスト用閾値 20%を超過
    ↓
WARNINGログ出力
    ↓
CloudWatch Logsへ送信
    ↓
DiskWarningCountへ変換
    ↓
CloudWatch AlarmがALARM状態
    ↓
SNSからメール通知
```
メール通知まで正常に動作することを確認しました。

検証終了後、Disk監視の閾値は本来の90%へ戻しています。

## 学習・実装した内容

本プロジェクトを通して、以下の内容を実践しました。

**Linux / Shell Script**

- BashによるShell Script作成
- topによるCPU使用率取得
- freeによるメモリ使用率取得
- dfによるディスク使用率取得
- awkによるコマンド結果の加工
- 条件分岐によるWARNING判定
- Linuxログファイルへの出力
- cronによる定期実行

**AWS**

- EC2へのデプロイ
- Amazon Linux 2023環境での実行
- IAMロールによる権限設定
- CloudWatch Agentの導入
- CloudWatch Logsへのログ送信
- Metric Filterによるログのメトリクス化
- CloudWatch Alarmによる監視
- SNSによるメール通知

**監視・アラート**

単純に監視値を取得するだけではなく、
```
監視
 ↓
ログ出力
 ↓
CloudWatch Logs
 ↓
Metric Filter
 ↓
CloudWatch Alarm
 ↓
SNS
 ↓
メール通知
```
という監視・アラート通知の一連の流れを実装しました。

## 今後の改善予定
- TerraformによるAWSリソースのコード化
- CloudWatch Dashboardによる監視画面の作成
- 監視項目の追加
- ログローテーションの実装
- SNS通知内容の改善
- Docker環境との連携
- Pythonによる監視機能の拡張

## ディレクトリ構成
```
shell-monitor/
└── monitor/
    ├── monitor.sh
    └── logs/
        └── monitor.log
```
monitor.logはGitHubへコミットしないよう、.gitignoreで除外しています。

## まとめ

本プロジェクトでは、Shell ScriptによるLinuxサーバー監視から、AWS CloudWatch・SNSを利用したアラート通知まで、一連の監視・通知環境を構築しました。

Linuxコマンドによるリソース監視、cronによる定期実行、CloudWatch Logsによるログ収集、Metric Filter・CloudWatch Alarmによる異常検知、SNSによるメール通知までを実際に構築・検証しています。

