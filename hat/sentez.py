"""Bir olayın kayıtlarından portalın kendi metnini yazar.

Neden
─────
Beş kaynak aynı kazayı yazdığında bugün dördü siliniyor. Oysa her
kaynak farklı ayrıntı taşıyor: ölçülen Daday yangınında bir kaynak
jandarmayı, orman ekiplerini ve ihbarın köylülerden geldiğini yazmış,
öbürü hiçbirini. Kümeyi birleştirip tek metin yazınca bunlar korunuyor.

Çıkan metin portala ait oluyor — kaynak cümleleri kopyalanmadığı,
olgulardan yeniden yazıldığı için.

Model çağrısı dışarıdan veriliyor
─────────────────────────────────
`yaz()` bir istemci alıyor; almazsa kendi kuruyor. Böylece prompt
kurulumu ve çıktı denetimi anahtar olmadan test edilebiliyor —
`istek()` ve `dogrula()` saf işlevler.
"""

from __future__ import annotations

import json
from typing import Any, Protocol

from pydantic import BaseModel, Field

from .kumele import Olay

#: Varsayılan model. Sentez haber metni yazıyor; ucuzlatmak sizin
#: kararınız, `yaz(model=...)` ile değiştirin.
MODEL = "claude-opus-5-5"


# ── Çıktı biçimi ─────────────────────────────────────────────────

class Celiski(BaseModel):
    """Kaynakların aynı şey için farklı değer verdiği yer."""

    konu: str = Field(description="Neyin çeliştiği, örn. 'yaralı sayısı'")
    degerler: dict[str, str] = Field(
        description="Kaynak adı -> o kaynağın verdiği değer"
    )


class Sentez(BaseModel):
    baslik: str
    spot: str
    govde: str
    kullanilan_kaynaklar: list[str]
    celiskiler: list[Celiski] = Field(default_factory=list)


# ── Yönerge ──────────────────────────────────────────────────────

YONERGE = """\
Sen bir şehir haber portalının yazı işlerindesin. Aynı olayı anlatan \
birden çok kaynak kaydı veriliyor. Bunlardan portalın KENDİ haberini \
yazacaksın.

Kurallar:

1. Yazdığın her cümle verilen kayıtlardaki bir bilgiye dayanmalı. \
Kayıtlarda olmayan hiçbir şey ekleme — tahmin, yorum, genel bilgi yok.
2. Kaynakların cümlelerini KOPYALAMA. Olgulardan kendi cümlelerini kur. \
Metnin portala ait olmasının tek yolu bu.
3. Kayıtlar birleşince daha dolu bir haber çıkar: bir kaynağın yazıp \
öbürünün yazmadığı ayrıntıları MUTLAKA kullan. Birleştirmenin amacı bu.
4. Kaynaklar aynı şey için farklı değer veriyorsa (yaralı sayısı, saat, \
isim) ARALARINDA SEÇİM YAPMA. Metinde o ayrıntıyı belirsiz bırak ve \
çelişkiyi `celiskiler` alanına yaz. Hangi kaynağın haklı olduğuna karar \
vermek senin işin değil.
5. `kullanilan_kaynaklar` alanına, metninde bilgisini kullandığın \
kaynakların adlarını yaz.

Üslup: Türkçe, haber dili, sade. Başlık tek cümle, abartısız. Spot iki \
cümleyi geçmesin. Gövde kısa paragraflar halinde.\
"""


def kayit_ozeti(k) -> dict[str, Any]:
    """Tek kaydın modele verilen hali."""
    return {
        "kaynak": k.kaynak_adi,
        "baslik": k.baslik,
        "spot": k.spot,
        "govde": k.govde,
        "olgular": k.olgular,
        "sayilar": k.sayilar,
    }


def istek(olay: Olay) -> str:
    """Modele gidecek kullanıcı mesajı.

    Saf işlev — anahtar gerektirmiyor, testte doğrudan çağrılıyor.
    """
    kayitlar = [kayit_ozeti(k) for k in olay.uyeler]
    return (
        f"Aşağıda aynı olayı anlatan {len(kayitlar)} kaynak kaydı var.\n\n"
        + json.dumps(kayitlar, ensure_ascii=False, indent=2)
    )


# ── Denetim ──────────────────────────────────────────────────────

class DenetimHatasi(Exception):
    """Çıktı sözleşmeyi tutmuyor."""


def dogrula(s: Sentez, olay: Olay) -> None:
    """Çıktıyı yayına uygun mu diye denetler.

    Saf işlev. Modelin söylediğine güvenmiyoruz: `kullanilan_kaynaklar`
    uydurulmuş bir yayın adı taşıyorsa ya da metin boşsa, haber yayına
    çıkmamalı.
    """
    if not s.baslik.strip():
        raise DenetimHatasi("başlık boş")
    if not s.govde.strip():
        raise DenetimHatasi("gövde boş")

    kumedekiler = set(olay.kaynaklar)
    uydurma = [k for k in s.kullanilan_kaynaklar if k not in kumedekiler]
    if uydurma:
        raise DenetimHatasi(
            f"kümede olmayan kaynak gösterilmiş: {', '.join(uydurma)}"
        )
    if not s.kullanilan_kaynaklar:
        raise DenetimHatasi("hiçbir kaynak gösterilmemiş")

    for c in s.celiskiler:
        yabanci = [k for k in c.degerler if k not in kumedekiler]
        if yabanci:
            raise DenetimHatasi(
                f"çelişkide kümede olmayan kaynak: {', '.join(yabanci)}"
            )


def durum(s: Sentez) -> str:
    """Haberin inceleme masasına hangi durumda düşeceği.

    Çelişki varsa editör bakmadan yayına çıkmamalı.
    """
    return "celiskili" if s.celiskiler else "yazildi"


# ── Model çağrısı ────────────────────────────────────────────────

class Istemci(Protocol):
    """`anthropic.Anthropic` bu biçimi karşılıyor."""

    messages: Any


def yaz(
    olay: Olay,
    istemci: Istemci | None = None,
    model: str = MODEL,
) -> Sentez:
    """Kümeden tek haber metni üretir ve denetler.

    Denetimden geçmezse [DenetimHatasi] yükseliyor — çağıran kaydı
    editöre düşürüyor, yayına değil.
    """
    if istemci is None:
        import anthropic

        istemci = anthropic.Anthropic()

    yanit = istemci.messages.parse(
        model=model,
        max_tokens=16000,
        system=YONERGE,
        messages=[{"role": "user", "content": istek(olay)}],
        output_format=Sentez,
    )

    # Güvenlik sınıflandırıcısı isteği reddedebiliyor; `content` okunmadan
    # önce bakılması gereken yer burası.
    if getattr(yanit, "stop_reason", None) == "refusal":
        raise DenetimHatasi("model isteği reddetti")

    s = yanit.parsed_output
    dogrula(s, olay)
    return s
