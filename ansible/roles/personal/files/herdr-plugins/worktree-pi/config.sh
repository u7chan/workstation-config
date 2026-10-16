# Defaults for the worktree-pi Herdr plugin.
#
# Machine-local overrides live in $HERDR_PLUGIN_CONFIG_DIR/config.sh. Herdr
# creates that directory as ~/.config/herdr/plugins/config/u7chan.worktree-pi
# and this repository neither provisions nor removes the override file.

# Set to 0 to stop launching pi without unlinking the plugin.
WORKTREE_PI_ENABLED=1

# Repository roots that launch pi. An empty array enables every repository.
WORKTREE_PI_REPOS=()

# Agent name and kind passed to `herdr agent start`.
WORKTREE_PI_AGENT="pi"

# Interactive-readiness timeout in milliseconds.
WORKTREE_PI_AGENT_TIMEOUT_MS=60000

# Extra arguments appended after the agent name, for example ("--model" "gpt-6-luna").
WORKTREE_PI_AGENT_ARGS=()
