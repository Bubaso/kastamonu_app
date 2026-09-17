#!/bin/bash
# Paneli yerelde çalıştırır.
#
# Anahtar kaynağa yazılmıyor, --dart-define ile veriliyor: böylece depoya
# girmiyor ve ortam değiştiğinde kod değişmiyor.
[ -f .env.panel ] && source .env.panel
if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "SUPABASE_ANON_KEY yok."
  echo "  .env.panel dosyasına yaz:  SUPABASE_ANON_KEY=..."
  exit 1
fi
exec flutter run -d chrome \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://vcwgcvzqdnjyoitdfhma.supabase.co}"
