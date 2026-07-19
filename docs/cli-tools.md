# CLIツールガイド

このリポジトリでは、次のターミナルツールをmiseで管理します。`base`と`personal`のどちらのプロファイルにも導入され、`./bootstrap`または`./bootstrap base`で利用可能になります。

バージョンは`provisioning/mise/mise.lock`に固定します。更新時は[Workstation構成ガイド](workstation.md#miseの管理範囲)の手順でlockfileを更新してください。

| ツール | 用途 | 起動 | 導入元 |
|---|---|---|---|
| [Hunk](https://github.com/modem-dev/hunk) | 変更セットをレビューするためのインタラクティブなdiff viewer | `hunk diff` | `modem-dev/hunk` |
| [Lazygit](https://github.com/jesseduffield/lazygit) | Git操作用のターミナルUI | `lazygit` | `jesseduffield/lazygit` |
| [Lazydocker](https://github.com/jesseduffield/lazydocker) | Docker resourceを操作・確認するターミナルUI | `lazydocker` | `jesseduffield/lazydocker` |
| [Herdr](https://github.com/ogulcancelik/herdr) | terminal上でAgentを多重化するCLI | `herdr` | `ogulcancelik/herdr` |
| [Yazi](https://github.com/sxyazi/yazi) | 非同期I/Oベースのファイルマネージャ | `yazi` | `sxyazi/yazi` |
| [Starship](https://github.com/starship/starship) | shell prompt | Bash起動時に自動で有効化 | `starship/starship` |
| [cagent](https://github.com/u7chan/code-agent-launcher) | Agent起動コマンドを統一するlauncher | `cagent --help` | `u7chan/code-agent-launcher` |

## Gitと変更レビュー

Git操作には`lazygit`、Agentが生成した変更のレビューには`hunk diff`を使います。Hunkは`--watch`で作業ツリーの更新を追従できます。

```bash
lazygit
hunk diff
hunk diff --watch
hunk show HEAD~1
```

HunkをGit pagerとして常用する場合は、利用者が明示的に次を設定します。リポジトリのbootstrapは既存のGit pager設定を変更しません。

```bash
git config --global core.pager "hunk pager"
```

## Docker

Docker CEを導入した`personal`プロファイルでは、Docker daemonが利用可能な状態で`lazydocker`を起動します。

```bash
lazydocker
```

Docker CEを無効化した`personal`構成や`base`プロファイルでもbinaryは導入されますが、Docker daemonの導入・起動は行いません。

## 設定の管理

- YaziとStarshipの設定はchezmoiで管理します。詳細は[Workstation構成ガイド](workstation.md#yazi)を参照してください。
- Hunk、Lazygit、Lazydocker、Herdr、cagentのユーザー設定は、必要になった時点で各ツールの公式ドキュメントを確認してください。現在はHerdrとcagentの非機密設定だけをchezmoiで管理しています。
- 認証情報、履歴、cache、runtime stateはリポジトリで管理しません。
