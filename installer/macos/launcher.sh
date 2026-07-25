#!/bin/bash

set -euo pipefail

RESOURCE_DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
COMMAND="$RESOURCE_DIR/install-spot64-beta.command"

/usr/bin/open -a Terminal "$COMMAND"

