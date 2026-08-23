# chezmoi source

This directory is the repository-local chezmoi source. Dedicated configuration issues add managed files here.

Claude Codeの`settings.json` merge fragmentは、設定全体を上書きしないためリポジトリ直下の`claude/settings.json`で管理します。`home/dot_claude/statusline.py`だけをchezmoiの管理対象として配置し、bootstrapがClaude選択時にfragmentの`theme`と`statusLine`を既存設定へmergeします。

Piの画像貼り付けキーバインドは`home/dot_pi/agent/keybindings.json`で管理します。bootstrapはPi選択時にだけ`WORKSTATION_PI_SELECTED=true`を渡して配置し、未選択時は`.chezmoiignore`テンプレートが対象外にした上でbootstrapが既存ファイルを削除します。
