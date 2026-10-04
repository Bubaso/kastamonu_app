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
Bu dosya hangi sağlayıcıyı kullandığımızı BİLMİYOR. `yaz()` bir çağırıcı
alıyor: yönergeyi ve isteği alıp [Sentez] döndüren herhangi bir işlev.
Gemini uygulaması `gemini.py` içinde.

Böylece iki şey oluyor: sağlayıcı değişince bu dosya değişmiyor, ve
prompt kurulumu ile çıktı denetimi anahtarsız test edilebiliyor —
`istek()` ve `dogrula()` saf işlevler.
"""

from __future__ import annotations

import difflib
import json
from collections.abc import Callable
from typing import Any

from pydantic import BaseModel, Field

from .kumele import Olay

# ── Çıktı biçimi ─────────────────────────────────────────────────

class KaynakDeger(BaseModel):
    """Bir kaynağın bir ayrıntı için verdiği değer."""

    kaynak: str
    deger: str


class Celiski(BaseModel):
    """Kaynakların aynı şey için farklı değer verdiği yer.

    `degerler` neden serbest sözlük (`dict[str, str]`) değil: sözlük
    JSON şemasında `additionalProperties` üretiyor ve Gemini'nin
    geliştirici API'si onu reddediyor. Liste her sağlayıcıda çalışıyor.
    """

    konu: str = Field(description="Neyin çeliştiği, örn. 'yaralı sayısı'")
    degerler: list[KaynakDeger]


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


#: Sentez ile kaynak metin arasında kabul edilebilir en uzun birebir
#: ortak parça, karakter.
#:
#: Cümle benzerliği ölçüt olarak YANILTICI: ölçülen Daday haberinde bir
#: sentez cümlesi kaynaktakine %90 benziyordu, ama sebebi adresti —
#: "Kastamonu'nun Daday ilçesine bağlı Bolatlar köyü Dere Mahallesi'nde".
#: Adresi başka türlü yazmanın anlamı yok ve telife de konu değil.
#:
#: Birebir ortak parça bu tuzağa düşmüyor: aynı ölçümde en uzun ortak
#: parça 31 karakterdi (çoğu paragraf boşluğu). Kopyalanmış bir cümle
#: 80-200 karakter sürer. Eşik ikisinin arasına, güvenli tarafa konuyor.
KOPYA_ESIGI = 100


def en_uzun_ortak(a: str, b: str) -> tuple[int, str]:
    """İki metnin paylaştığı en uzun birebir parça."""
    e = difflib.SequenceMatcher(None, a, b).find_longest_match(0, len(a), 0, len(b))
    return e.size, a[e.a : e.a + e.size]


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

    # Kaynak cümlesi kopyalanmış mı. Yönergede yazıyor ama modelin
    # söylediğine güvenmiyoruz; ölçüyoruz.
    for k in olay.uyeler:
        boy, parca = en_uzun_ortak(s.govde, k.govde or "")
        if boy >= KOPYA_ESIGI:
            raise DenetimHatasi(
                f"{k.kaynak_adi} kaynağından {boy} karakterlik birebir "
                f"parça taşınmış: “{parca[:60]}…”"
            )

    for c in s.celiskiler:
        yabanci = [d.kaynak for d in c.degerler if d.kaynak not in kumedekiler]
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

#: Yönergeyi ve isteği alıp [Sentez] döndüren işlev.
#:
#: Sağlayıcıya bağımlı tek nokta bu. `gemini.py` bir tane üretiyor;
#: testler sahte bir tane veriyor.
Cagirici = Callable[[str, str], Sentez]


def yaz(olay: Olay, cagir: Cagirici) -> Sentez:
    """Kümeden tek haber metni üretir ve denetler.

    Denetimden geçmezse [DenetimHatasi] yükseliyor — çağıran kaydı
    editöre düşürüyor, yayına değil. Modelin söylediğine güvenmiyoruz.
    """
    s = cagir(YONERGE, istek(olay))
    dogrula(s, olay)
    return s
