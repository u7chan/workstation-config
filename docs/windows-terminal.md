# Windows Terminal設定

Windows Terminalの`settings.json`はWindowsホスト側のマシン固有設定であり、このリポジトリでは自動配置しません。このドキュメントの雛形を使い、再セットアップ時に手動で設定します。

> [!NOTE]
> Windows Terminalの導入、Windows側への設定の自動配置、PowerShell 7への移行は対象外です。

## 設定ファイルとバックアップ

Microsoft Store版Windows Terminalの設定ファイルは、次のパスにあります。

```text
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

Windows Terminalの **設定** から **JSON ファイルを開く** を選ぶと、同じファイルを開けます。編集前にPowerShellでバックアップを作成してください。

```powershell
$settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$backupPath = "$settingsPath.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
Copy-Item -LiteralPath $settingsPath -Destination $backupPath
Write-Output "Backup: $backupPath"
```

`$backupPath`に表示されたパスを控えておきます。復元時にも使うため、設定ファイルと同じディレクトリ以外へ退避する場合は、退避先も記録してください。

## WSLディストリビューション名を確認する

PowerShellまたはコマンドプロンプトで次を実行し、使用するディストリビューション名を確認します。

```powershell
wsl -l
```

以下の設定例にある`{WSLディストリビューション名}`の2か所を、上記で確認した名前に置き換えます。例えば`Dev-Ubuntu-26.04`を使う場合、`commandline`は`wsl.exe --distribution Dev-Ubuntu-26.04`とします。

## 設定を反映する

次のJSONは`settings.json`全体の雛形です。ディストリビューション名を置き換えた後、バックアップ済みの`settings.json`をこの内容で丸ごと上書きします。

```json
{
  "$help": "https://aka.ms/terminal-documentation",
  "$schema": "https://aka.ms/terminal-profiles-schema",
  "actions": [
    {
      "command": {
        "action": "sendInput",
        "input": "\n"
      },
      "id": "User.sendNewLineInput"
    }
  ],
  "copyFormatting": "none",
  "copyOnSelect": false,
  "defaultInputScope": "alphanumericHalfWidth",
  "defaultProfile": "{11111111-1111-1111-1111-111111111111}",
  "keybindings": [
    {
      "id": "Terminal.CopyToClipboard",
      "keys": "ctrl+c"
    },
    {
      "id": "Terminal.PasteFromClipboard",
      "keys": "ctrl+v"
    },
    {
      "id": "User.sendNewLineInput",
      "keys": "shift+enter"
    },
    {
      "id": null,
      "keys": "ctrl+w"
    }
  ],
  "newTabMenu": [
    {
      "type": "remainingProfiles"
    }
  ],
  "profiles": {
    "defaults": {
      "colorScheme": "One Half Dark",
      "cursorColor": "#BEBEBE",
      "cursorShape": "filledBox",
      "font": {
        "face": "JetBrainsMono Nerd Font Mono",
        "size": 12,
        "weight": "medium"
      },
      "icon": "\uf15f",
      "opacity": 50,
      "useAcrylic": true,
      "startingDirectory": "~"
    },
    "list": [
      {
        "elevate": false,
        "guid": "{11111111-1111-1111-1111-111111111111}",
        "hidden": false,
        "name": "Windows PowerShell"
      },
      {
        "commandline": "wsl.exe --distribution {WSLディストリビューション名}",
        "guid": "{22222222-2222-2222-2222-222222222222}",
        "hidden": false,
        "name": "WSL - {WSLディストリビューション名}",
        "startingDirectory": "~"
      }
    ]
  },
  "schemes": [],
  "themes": []
}
```

| 設定 | 意図 |
| --- | --- |
| `defaultInputScope: alphanumericHalfWidth` | 日本語IMEが全角入力から始まらないようにする。 |
| `copyFormatting: none` | コピー時の書式を除き、プレーンテキストとして貼り付け先へ渡す。 |
| `copyOnSelect: false` | 範囲選択だけで自動コピーしないようにする。 |
| `shift+enter` → `\n` | Claude Code、Codex、OpenCodeなどのAI CLIで、送信せず入力中に改行する。 |
| `ctrl+w` → `null` | ターミナルタブの誤終了を防ぎ、Herdrのパネル操作との競合を避ける。 |
| `colorScheme: One Half Dark` | Windows Terminal標準の配色へ統一し、未定義の`Dimidium`には依存しない。 |
| `font.face: JetBrainsMono Nerd Font Mono` | Starshipなどが使うNerd Fontアイコンを正しく表示する。 |
| `opacity: 50` / `useAcrylic: true` | 背景を半透明のアクリル表示にする。 |
| `defaultProfile` | 固定GUIDの`Windows PowerShell`プロファイルを既定にする。 |
| WSLの`commandline` | 自動検出プロファイルに依存せず、指定したディストリビューションを起動する。 |

フォントの導入手順は[workstation-notes](https://github.com/u7chan/workstation-notes)を参照してください。フォント未導入の状態では、アイコンや区切り文字が正しく表示されません。

## 反映と復元

1. `settings.json`を保存し、Windows Terminalをいったんすべて終了して再起動します。
2. PowerShellが既定で起動することと、WSLプロファイルが指定したディストリビューションを開くことを確認します。
3. IMEが半角英数で始まること、コピー、`Shift+Enter`の改行、`Ctrl+W`でタブが閉じないことを確認します。
4. 起動時エラーや意図しない動作があれば、Windows Terminalを終了します。
5. バックアップを復元してから、Windows Terminalを再起動します。

バックアップの復元は、作成時に表示されたバックアップパスを`$backupPath`へ設定して行います。

```powershell
$settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$backupPath = '作成時に表示されたバックアップファイルのパス'
Copy-Item -LiteralPath $backupPath -Destination $settingsPath -Force
```

復元後もエラーが続く場合は、Windows Terminalの **設定** から **JSON ファイルを開く** を選び、JSONの構文エラー表示を確認してください。
