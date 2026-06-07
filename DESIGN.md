# FeedLoop Design System

## Overview

FeedLoop is a scroll-optimized, content-first design system built for social media feeds and content discovery platforms. It emphasizes readability at speed, with compact spacing that maximizes content density without sacrificing clarity.

## Colors

| Token | Value | Usage |
|---|---|---|
| Primary | `#2563EB` | ボタン・リンク・アクセント |
| Secondary | `#6B7280` | メタ情報・補助テキスト |
| Background | `#F9FAFB` | 画面背景 |
| Surface | `#FFFFFF` | カード背景 |
| Success | `#16A34A` | プラス収支 |
| Warning | `#D97706` | 注意 |
| Error | `#DC2626` | マイナス収支・削除 |
| Info | `#2563EB` | 情報 |
| Text Main | `#111827` | 主要テキスト |
| Text Sub | `#6B7280` | 補助テキスト |
| Border | `#E5E7EB` | カード枠線 |

## Do's and Don'ts

- **Do** カードは白背景・角丸・細いボーダー（0.5px）・影なし
- **Do** タッチターゲットは最小 44px 確保
- **Do** カードの padding・radius は統一する
- **Do** 収支の正負は必ず色で表現（数値の前に `+` `-` を付ける）
- **Do** 数値入力は numeric キーボード（keyboardType: numeric）を使用
- **Don't** フィードカードに重い影をつけない
- **Don't** ダークモードは使用しない（ライトモード固定）

## Navigation

BottomNavigation は 5 タブ：  
`ホーム` | `履歴` | `登録（中央FAB・#2563EB）` | `分析` | `設定`

## Typography

- 大きな数値（収支）: bold, 28px+
- セクションヘッダー: semibold, 12px, Primary Color
- カード本文: regular, 14-16px, Text Main
- 補助ラベル: regular, 11-12px, Text Sub
