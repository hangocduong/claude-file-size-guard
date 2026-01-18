#!/bin/bash
# Toggle file-size-guard hook on/off
# Usage: ./file-size-guard-toggle.sh [enable|disable|status]

set -e

CK_CONFIG="${CK_CONFIG:-$HOME/.claude/.ck.json}"

# Ensure config file exists
ensure_config() {
  if [ ! -f "$CK_CONFIG" ]; then
    mkdir -p "$(dirname "$CK_CONFIG")"
    echo '{}' > "$CK_CONFIG"
  fi
}

case "$1" in
  enable)
    ensure_config
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CK_CONFIG', 'utf-8'));
      config.fileSizeGuard = config.fileSizeGuard || {};
      config.fileSizeGuard.enabled = true;
      fs.writeFileSync('$CK_CONFIG', JSON.stringify(config, null, 2));
      console.log('✅ file-size-guard ENABLED');
    "
    ;;
  disable)
    ensure_config
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CK_CONFIG', 'utf-8'));
      config.fileSizeGuard = config.fileSizeGuard || {};
      config.fileSizeGuard.enabled = false;
      fs.writeFileSync('$CK_CONFIG', JSON.stringify(config, null, 2));
      console.log('❌ file-size-guard DISABLED');
    "
    ;;
  status)
    ensure_config
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CK_CONFIG', 'utf-8'));
      const enabled = config.fileSizeGuard?.enabled !== false;
      console.log('file-size-guard:', enabled ? '✅ ENABLED' : '❌ DISABLED');
      console.log('warnThreshold:', config.fileSizeGuard?.warnThreshold || 120);
      console.log('blockThreshold:', config.fileSizeGuard?.blockThreshold || 200);
    "
    ;;
  *)
    echo "Usage: $0 [enable|disable|status]"
    echo ""
    echo "Commands:"
    echo "  enable   - Enable file size guard"
    echo "  disable  - Disable file size guard"
    echo "  status   - Show current status and thresholds"
    exit 1
    ;;
esac
