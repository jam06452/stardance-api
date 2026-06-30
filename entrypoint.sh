#!/bin/sh
set -e

/app/bin/stardance eval "Stardance.Release.migrate()"

exec "$@"
