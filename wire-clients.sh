#!/usr/bin/env bash
#
# wire-clients.sh
# A utility script to automatically configure popular AI coding agents
# to use the local CodeGraphContext MCP SSE server provided by this container.
#
# Usage: ./wire-clients.sh [SSE_URL]
# Example: ./wire-clients.sh http://localhost:8045/sse

set -euo pipefail

SSE_URL="${1:-http://localhost:8045/sse}"

inject_sse() {
  local target="$1"
  local agent="$2"
  
  if [ ! -f "$target" ]; then
    mkdir -p "$(dirname "$target")"
    echo '{"mcpServers": {}}' > "$target"
  fi
  
  if ! jq . "$target" >/dev/null 2>&1; then
    echo "WARNING: $target is not valid JSON, skipping $agent wiring" >&2
    return
  fi

  jq --arg url "$SSE_URL" '.mcpServers.codegraphcontext = {"type": "sse", "url": $url}' "$target" > "$target.tmp" && mv "$target.tmp" "$target"
  echo "✅ Wired CodeGraphContext SSE for $agent -> $target"
}

echo "Wiring CodeGraphContext MCP SSE URL: $SSE_URL"
echo ""

# 1. Codex (Global)
inject_sse "$HOME/.codex/mcp.json" "Codex"

# 2. Gemini (Global)
inject_sse "$HOME/.gemini/config/mcp.json" "Gemini"

# 3. Kimi (Global)
inject_sse "$HOME/.kimi-code/mcp.json" "Kimi"

# 4. OpenCode (Global)
inject_sse "$HOME/.opencode/mcp.json" "OpenCode"

# 5. Cursor (Global)
inject_sse "$HOME/.cursor/mcp.json" "Cursor"

# 6. VSCode native MCP (Global)
inject_sse "$HOME/.vscode/mcp.json" "VSCode"

# 7. Cline (VSCode extension)
CLINE_PATH="$HOME/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
[ "$(uname)" = "Darwin" ] && CLINE_PATH="$HOME/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
inject_sse "$CLINE_PATH" "Cline"

# 8. Roo (VSCode extension)
ROO_PATH="$HOME/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"
[ "$(uname)" = "Darwin" ] && ROO_PATH="$HOME/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"
inject_sse "$ROO_PATH" "Roo Code"

echo ""
echo "Done! Restart your agents to apply the new configuration."
