"""Sentezin Gemini uygulaması.

`sentez.py` hangi sağlayıcıyı kullandığımızı bilmiyor; burası onu
bağlayan tek dosya. Başka bir sağlayıcıya geçilecekse yalnız bunun
eşi yazılır, `sentez.py` değişmez.

Anahtar
───────
`GEMINI_API_KEY` ortam değişkeninden okunuyor. Kaynağa, depoya ya da
herhangi bir dosyaya YAZILMAZ: Supabase anon anahtarının aksine bu
anahtar gizli — eline geçen sizin hesabınıza istek yapar.

    export GEMINI_API_KEY=...
"""

from __future__ import annotations

import os

from google import genai
from google.genai import types

from .sentez import Cagirici, DenetimHatasi, Sentez

#: Varsayılan model.
#:
#: Ölçüm sırasında `gemini-2.5-pro` ile `gemini-3.1-pro-preview`
#: karşılaştırıldı; ikisi de kuralları tutturdu. Kararlı olan seçildi:
#: hat her gün koşan bir üretim işi ve "preview" etiketli modeller
#: haber vermeden değişebiliyor ya da kalkabiliyor.
#:
#: Günde ~17 haber ölçeğinde maliyet küçük kalıyor; yine de ucuzlatmak
#: isterseniz `gemini-flash-latest` tek satırlık değişiklik.
MODEL = "gemini-2.5-pro"


def cagirici(model: str = MODEL, anahtar: str | None = None) -> Cagirici:
    """Gemini'ye bağlı bir [Cagirici] üretir.

    İstemci bir kez kuruluyor ve dönen işlev onu paylaşıyor; hat bir
    koşuda onlarca olay sentezleyebilir.
    """
    anahtar = anahtar or os.environ.get("GEMINI_API_KEY")
    if not anahtar:
        raise DenetimHatasi(
            "GEMINI_API_KEY tanımlı değil. Anahtar ortam değişkeninden "
            "okunuyor; kaynağa yazılmaz."
        )

    istemci = genai.Client(api_key=anahtar)

    def cagir(yonerge: str, istek: str) -> Sentez:
        yanit = istemci.models.generate_content(
            model=model,
            contents=istek,
            config=types.GenerateContentConfig(
                system_instruction=yonerge,
                response_mime_type="application/json",
                response_schema=Sentez,
                # Haber metni: uydurmaya yer bırakmamak için düşük.
                temperature=0.2,
            ),
        )

        s = yanit.parsed
        if s is None:
            # Güvenlik süzgeci ya da biçim hatası. Ham metin gövdeye
            # konmuyor: denetlenmemiş çıktı yayına yaklaştırılmaz.
            sebep = getattr(yanit, "prompt_feedback", None)
            raise DenetimHatasi(
                f"model yapılandırılmış çıktı döndürmedi (sebep: {sebep})"
            )
        return s

    return cagir
