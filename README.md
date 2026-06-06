# スロット収支管理アプリ

## プロジェクト概要

パチスロユーザー向けの収支管理アプリ（MVP版）。
入力の手間を極限まで減らすことを最優先に設計。

## 実装済み機能

- **ホーム画面** — 今日の収支・今月サマリー・最近の実践
- **実践履歴** — 一覧表示・スワイプ削除・編集
- **実践登録** — 店舗/機種オートコンプリート、投資/回収入力で収支自動計算、時間入力（折りたたみ）
- **カレンダー** — 勝ち=緑/負け=赤の色分け、日別収支表示
- **分析** — 月間収支、店舗別ランキング、機種別ランキング、棒グラフ
- **貯玉管理** — 店舗ごとの貯玉追加/使用/履歴
- **設定** — プロフィール表示、データ削除、ログアウト
- **認証** — Googleログイン + ゲストモード（オフライン）
- **ダークモード** — 全画面対応

## セットアップ手順

### 1. 依存パッケージのインストール

```bash
flutter pub get
```

### 2. Supabase の設定（後から追加可能）

1. [supabase.com](https://supabase.com) でプロジェクト作成（Freeプラン）
2. `lib/main.dart` に以下を追加:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

// main() の先頭に:
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_ANON_KEY',
);
```

### 3. Google Sign-In の設定（iOS）

1. [Firebase Console](https://console.firebase.google.com) でプロジェクト作成
2. `GoogleService-Info.plist` を `ios/Runner/` に配置
3. `ios/Runner/Info.plist` に REVERSED_CLIENT_ID を追加:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### 4. ビルド & 実行

```bash
# iOSシミュレーター
flutter run

# iOSリリースビルド
flutter build ios --release
```

## プロジェクト構造

```
lib/
├── main.dart                    # エントリーポイント
├── app.dart                     # ルート・ナビゲーション
├── core/
│   ├── theme/app_theme.dart     # ダークテーマ定義
│   ├── constants/machine_data.dart  # 機種マスタ
│   ├── utils/format_utils.dart  # 日付/金額フォーマット
│   └── database/local_database.dart # SQLiteローカルDB
├── features/
│   ├── auth/                    # 認証（Google/ゲスト）
│   ├── home/                    # ホーム画面
│   ├── records/                 # 実践履歴・登録フォーム
│   ├── calendar/                # カレンダー表示
│   ├── analysis/                # 分析（月間・店舗別・機種別）
│   ├── savings/                 # 貯玉管理
│   └── settings/                # 設定画面
└── shared/
    ├── models/                  # データモデル
    ├── repositories/            # データアクセス層
    └── widgets/                 # 共通ウィジェット
```

## 今後の実装候補（MVP後）

- [ ] Supabase同期（オフライン→オンライン自動同期）
- [ ] 収支共有URL機能
- [ ] パチンコ対応
- [ ] 設定推測メモ
- [ ] AIによる期待値分析
- [ ] SNS共有
