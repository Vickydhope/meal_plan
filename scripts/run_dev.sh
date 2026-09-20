#!/usr/bin/env bash
exec flutter run --flavor dev --dart-define-from-file=dart_defines/dev.json "$@"
