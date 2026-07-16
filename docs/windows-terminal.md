# Windows Terminal設定

Windows Terminalの`settings.json`はWindowsホスト側のマシン固有設定であり、このリポジトリでは管理しません。このドキュメントを再セットアップ時の手順とし、既存設定へ必要な項目だけをマージします。

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

## コア設定をマージする

次のJSONは設定ファイル全体ではなく、既存のトップレベルオブジェクトへマージする設定片です。`actions`、`keybindings`、`profiles.defaults`は既存の同名配列・オブジェクトと内容を統合し、同じ`id`やキーがある場合は意図を確認して重複させないでください。`defaultProfile`は含めません。

```json
{
  "copyFormatting": "none",
  "copyOnSelect": false,
  "defaultInputScope": "alphanumericHalfWidth",
  "actions": [
    {
      "command": { "action": "sendInput", "input": "\n" },
      "id": "User.sendNewLineInput"
    }
  ],
  "keybindings": [
    { "id": "Terminal.CopyToClipboard", "keys": "ctrl+c" },
    { "id": "Terminal.PasteFromClipboard", "keys": "ctrl+v" },
    { "id": "User.sendNewLineInput", "keys": "shift+enter" },
    { "id": null, "keys": "ctrl+w" }
  ],
  "newTabMenu": [
    { "type": "remainingProfiles" }
  ],
  "profiles": {
    "defaults": {
      "colorScheme": "One Half Dark",
      "font": {
        "face": "JetBrainsMono Nerd Font Mono"
      }
    }
  }
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

フォントの導入手順は[workstation-notes](https://github.com/u7chan/workstation-notes)を参照してください。フォント未導入の状態では、アイコンや区切り文字が正しく表示されません。

## WSLプロファイルを調整する

WSLプロファイルは`profiles.list`内の対象プロファイルへマージします。次はUbuntu 24.04の例であり、GUID、名前、ディストリビューション名は実際の環境に合わせます。`startingDirectory: "~"`は、WSLをWindowsのカレントディレクトリではなくLinuxのホームディレクトリから開始するための指定です。

```json
{
  "guid": "{fbcb50f4-0eb8-5035-af1b-092102dc1170}",
  "name": "Ubuntu-24.04",
  "source": "Microsoft.WSL",
  "hidden": false,
  "icon": "\ue70c",
  "cursorShape": "filledBox",
  "cursorColor": "#BEBEBE",
  "startingDirectory": "~"
}
```

`source: "Microsoft.WSL"`で自動検出されるプロファイルを、手動で同じ内容の別エントリとして追加しないでください。`workstation-test-ubuntu26`など検証用ディストリビューションを作成・削除した後は、設定画面のプロファイル一覧と`profiles.list`を確認し、不要になった重複WSLエントリを削除または非表示にします。削除前に、現在の既定プロファイルではないことを確認してください。

## 既定プロファイルをGUIで選ぶ

`defaultProfile`は環境ごとにGUIDが異なるため、JSONには書き込みません。Windows Terminalの **設定** から **起動** を開き、**既定のプロファイル** で利用するWSLプロファイルを選択して保存してください。

![既定プロファイルの選択画面（画像は後から追加）](assets/windows-terminal-default-profile.png)

上の画像参照先は、追加予定の物理パス`docs/assets/windows-terminal-default-profile.png`です。画像ファイル自体はまだリポジトリに追加しません。

## 反映と復元

1. `settings.json`を保存し、Windows Terminalをいったんすべて終了して再起動します。
2. WSLタブを開き、IMEが半角英数で始まること、コピー、`Shift+Enter`の改行、`Ctrl+W`でタブが閉じないことを確認します。
3. 起動時エラーや意図しない動作があれば、Windows Terminalを終了します。
4. バックアップを復元してから、Windows Terminalを再起動します。

バックアップの復元は、作成時に表示されたバックアップパスを`$backupPath`へ設定して行います。

```powershell
$settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$backupPath = '作成時に表示されたバックアップファイルのパス'
Copy-Item -LiteralPath $backupPath -Destination $settingsPath -Force
```

復元後もエラーが続く場合は、Windows Terminalの **設定** から **JSON ファイルを開く** を選び、JSONの構文エラー表示を確認してください。
