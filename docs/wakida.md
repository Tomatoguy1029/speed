# Tomatoguy1029 の本番作業・判断の履歴

Godot 本番の要望・作業内容・決定事項を日付と番号付きで追記する。過去の試作記録は [demo の履歴](../demo/docs/wakida.md) に保存している。

80. 「Godotでの本格開発を始め、今の試作はdemoへ移して実験場として残す」→ ユーザーが編集したAGENTS.mdを先にコミットし、その内容を変更せず `demo/AGENTS.md` へ保存。既存のWeb試作と資料を `demo/` にまとめ、本番は既存の `speed/project.godot` を使う。ルートのAGENTS.md・READMEを本番用に作り直し、本番とdemoの仕様・作業記録を分ける。Vercelの公開対象は `demo/dist/` に変更し、既存URLを維持する（2026-10-07）。
