#!/bin/bash
# Kastamonu Haber — derleme ve dağıtım
#
# Kabuk üretimi bu betiğin ASIL işi: `functions/shell.html`, Flutter'ın
# ürettiği `build/web/index.html`in birebir kopyası olmak zorunda. Elle
# tutulan bir kabuk, Flutter sürüm damgalı betik yolunu değiştirdiğinde
# sessizce bayatlıyor ve SSR'lı sayfalar eski paketi yüklemeye çalışıyor.
set -e
cd "$(dirname "$0")"

[ -f .env.panel ] && source .env.panel
if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "✗ SUPABASE_ANON_KEY yok (.env.panel)"; exit 1
fi

echo "▸ Flutter web derleniyor…"
flutter build web --release \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://vcwgcvzqdnjyoitdfhma.supabase.co}"

echo "▸ Uygulama kabuğu yeniden adlandırılıyor (index.html → app.html)…"
# Firebase Hosting statik dosyayı yönlendirmeden önce sunuyor; index.html
# yerinde kalırsa "/" isteği ana sayfa SSR fonksiyonuna hiç ulaşmıyor.
mv build/web/index.html build/web/app.html

echo "▸ Fonksiyon kabuğu güncelleniyor…"
sed 's|\$FLUTTER_BASE_HREF|/|g' build/web/app.html > functions/shell.html

if ! grep -q 'SOCIAL_META_START' functions/shell.html; then
  echo "✗ functions/shell.html içinde SOCIAL_META_START yok."
  echo "  web/index.html'deki işaretleyiciler silinmiş olabilir."
  exit 1
fi
echo "  ✓ kabuk hazır ($(wc -c < functions/shell.html) bayt)"

echo "▸ Dağıtılıyor…"
firebase deploy --only hosting,functions
