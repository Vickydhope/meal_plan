#!/usr/bin/env bash
exec flutter run --flavor prod --dart-define-from-file=dart_defines/prod.json "$@"
