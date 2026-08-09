# chezmoi source

This directory is the repository-local chezmoi source. Dedicated configuration issues add managed files here.

Claude Codeの`settings.json` merge fragmentは、設定全体を上書きしないためリポジトリ直下の`claude/settings.json`で管理します。`home/dot_claude/statusline.py`だけをchezmoiの管理対象として配置し、bootstrapがClaude選択時にfragmentの`theme`と`statusLine`を既存設定へmergeします。
