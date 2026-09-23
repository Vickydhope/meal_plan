#!/usr/bin/env bash
# Cheap grep-based guard for the architecture rules in CLAUDE.md that
# `flutter analyze` can't see. Run locally or wire into CI
# (`scripts/check_architecture.sh`) before `flutter test`.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "Checking domain layers stay pure Dart..."
if grep -rn --include="*.dart" -E "import .*(/data/|/presentation/|package:flutter/|package:supabase_flutter)" lib/features/*/domain; then
  echo "❌ domain layer must not import data, presentation, Flutter, or Supabase"
  fail=1
fi

echo "Checking widgets don't construct repositories/datasources directly..."
if grep -rn --include="*.dart" -E "(RepositoryImpl|RemoteDataSource)\(" lib/features/*/presentation/screens lib/features/*/presentation/notifiers lib/features/*/presentation/state 2>/dev/null; then
  echo "❌ only presentation/providers/*_providers.dart may construct data-layer implementations"
  fail=1
fi

echo "Checking for hardcoded TextStyle font sizes outside core/theme..."
# fontSize: 0 is excluded — that's the zero-size trick for suppressing a
# TextFormField's errorStyle, not a real type-scale usage.
if grep -rn --include="*.dart" -E "fontSize: [^0]" lib/features lib/shared 2>/dev/null | grep -v "core/theme"; then
  echo "❌ use a named style from core/theme/app_typography.dart instead of TextStyle(fontSize: ...)"
  fail=1
fi

echo "Checking for hardcoded Color(0x...) literals outside core/theme..."
if grep -rln --include="*.dart" "Color(0x" lib/features lib/shared 2>/dev/null | grep -v "core/theme"; then
  echo "❌ use a token from core/theme/app_colors.dart instead of a raw Color(0x...) literal"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "✅ architecture checks passed"
fi
exit $fail
