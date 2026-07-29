#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
missing=$(grep -rL '// SPDX-License-Identifier: MPL-2.0' --include='*.swift' Sources Tests App/Denzel 2>/dev/null || true)
if [ -n "$missing" ]; then
  echo "Missing SPDX header:"
  echo "$missing"
  exit 1
fi
echo "SPDX headers OK"
