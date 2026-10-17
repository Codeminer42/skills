#!/usr/bin/env bash
# Builds origin.git/ and app/ in the run's workspace from this case's fixture/.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$here/../_shared/make-repo.sh" "$here"
