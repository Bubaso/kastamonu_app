"""Aynı olayı anlatan kayıtları bir araya toplar.

Neden
─────
Haber hattı birden çok kaynağı tarıyor ve aynı olayı birden çok kaynak
yazıyor. Bugün fazlalıklar siliniyor: beş kaynaktan gelen aynı kazanın
dördü çöpe gidiyor. Oysa her kaynak farklı ayrıntı yazıyor.

Ölçülen gerçek örnek — Daday'da bir samanlık yangını:

    Haberler.com : jandarma ve orman ekipleri geldi, ihbarı köylüler yaptı
    Sondakika    : (bunların hiçbiri yok)

Silmek yerine kümeleyip tek metin yazınca bu ayrıntılar korunuyor.

Bu modül kümelemeyi yapıyor; metni `sentez.py` yazıyor.

Taşınabilirlik
──────────────
Bağımlılığı yok, Python standart kitaplığıyla koşuyor. Hat ayrı bir
projede olduğu için bilerek böyle: dosya oraya kopyalanabilsin.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Iterable, Sequence

# ── Bölüm aileleri ───────────────────────────────────────────────
#
# `lib/cekirdek/bolum.dart` ile AYNI olmak zorunda. İki kaynak aynı
# olayı farklı kategoriye koyabiliyor ama aile düzeyinde ayrışmıyorlar.
AILELER = {
    "Asayiş": "asayis",
    "Kaza ve Acil": "asayis",
    "Gündem": "gundem",
    "Kent ve Yönetim": "gundem",
    "Ekonomi": "uretim",
    "Tarım": "uretim",
    "Eğitim": "toplum",
    "Sağlık": "toplum",
    "Kültür ve Turizm": "yasam",
    "Spor": "yasam",
}


def aile(kategori_ad: str | None) -> str:
    return AILELER.get(kategori_ad or "", "diger")


# ── Başlık benzerliği ────────────────────────────────────────────

#: Harf eşlemesi — `lib/cekirdek/metin.dart` ile aynı olmak zorunda.
_ESLEME = {
    "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
    "â": "a", "î": "i", "û": "u",
}

# Üç harften uzun ama her başlıkta geçebilen bağlaçlar.
_DURAKLAR = {
    "icin", "ile", "olarak", "sonra", "once", "kadar",
    "gibi", "daha", "ancak", "ayrica", "uzere",
}


def sadelestir(s: str | None) -> str:
    """Türkçeye uygun küçültme, sonra harf eşleme.

    `lib/cekirdek/metin.dart` ile AYNI tabloyu kullanıyor.

    Sıra önemli: önce Türkçe küçültme, sonra eşleme. Tersi yapılırsa
    "I" önce "i"ye düşüp değişmeden kalıyor ve "Ilgaz" ile "ılgaz" ayrı
    şeylere dönüşüyor.

    Unicode ayrıştırma (NFD) burada YETMİYOR: "ı" (U+0131) ayrışmayan
    bir harf, ayrıştırmaya dayanan bir çözüm onu atlıyor ve "yangın"
    kelimesi ikiye bölünüyor. Türkçede en sık harflerden biri olduğu
    için bu sessiz ve yaygın bir hata olurdu — testle sabitlendi.
    """
    s = (s or "").replace("I", "ı").replace("İ", "i").lower()
    for kaynak, hedef in _ESLEME.items():
        s = s.replace(kaynak, hedef)
    return s


def kelimeler(baslik: str | None) -> set[str]:
    return {
        k for k in re.split(r"[^a-z0-9]+", sadelestir(baslik))
        if len(k) > 2 and k not in _DURAKLAR
    }


def benzerlik(a: str | None, b: str | None) -> float:
    """Ortak kelime oranı, 0 ile 1 arasında."""
    x, y = kelimeler(a), kelimeler(b)
    if not x or not y:
        return 0.0
    return len(x & y) / len(x | y)


# ── Eşikler ──────────────────────────────────────────────────────

#: Zaman penceresi — **derleme anına** bakılıyor, yayın anına değil.
#:
#: Bu ayrım kuralı bir kez işlemez hale getirmişti: ölçülen çiftin iki
#: kaydı bir gün arayla derlenmiş ama biri 21 Eylül'de, öbürü 3 Ekim'de
#: yayımlanmıştı. Yayın damgasına bakınca fark 12,5 gün çıkıyor ve
#: gerçek tekrar pencerenin dışında kalıyordu.
PENCERE = timedelta(days=7)

#: Eşleşme eşiği.
#:
#: DİKKAT — bu sayı ölçülmüş değil. Yayındaki 60 kayıtla 0,50 · 0,55 ·
#: 0,62 · 0,70 denendi, dördü de birebir aynı sonucu verdi: gerçek
#: tekrar 0,75'te, tekrar olmayan en yakın çift 0,45'te, arada geniş bir
#: ölü bölge var. Kaynak sayısı artınca `ADAY_ESIGI` ile toplanan
#: etiketli veriden yeniden ölçülmeli.
ESIK = 0.62

#: Aday eşiği — editöre sorulacak çiftler için.
#:
#: Bilerek düşük. Bu aralıktakiler otomatik birleştirilmiyor, "bunlar
#: aynı olay mı?" diye işaretleniyor. Biriken cevaplar `ESIK`in gerçek
#: değerini ölçmenin tek yolu.
ADAY_ESIGI = 0.45


# ── Kayıt ────────────────────────────────────────────────────────

@dataclass
class Kayit:
    """Hattın bir kaynaktan derlediği tek haber."""

    id: str
    baslik: str
    kaynak_adi: str
    olusturuldu: datetime
    kategori_ad: str | None = None
    ilceler: frozenset[str] = frozenset()
    spot: str | None = None
    govde: str | None = None
    olgular: dict = field(default_factory=dict)
    sayilar: list = field(default_factory=list)
    kaynak_url: str | None = None
    gorsel_url: str | None = None
    gorsel_kaynak: str | None = None

    @property
    def fotografli(self) -> bool:
        return bool(self.gorsel_url) and bool(self.gorsel_kaynak)


# ── Olay ─────────────────────────────────────────────────────────

#: Başlık farkının "bu başlık gerçekten daha bilgilendirici" sayılması
#: için gereken en az karakter. Eşik olmadan tek karakterlik bir fark
#: üç yüz karakterlik gövde farkını deviriyor.
BASLIK_FARK_ESIGI = 10


@dataclass
class Olay:
    """Aynı olayı anlatan kayıtların kümesi."""

    capa: Kayit
    uyeler: list[Kayit]

    @property
    def kaynaklar(self) -> list[str]:
        """Kümedeki farklı yayınlar, ilk görülme sırasıyla."""
        g, s = [], set()
        for k in self.uyeler:
            if k.kaynak_adi not in s:
                s.add(k.kaynak_adi)
                g.append(k.kaynak_adi)
        return g

    @property
    def lider(self) -> Kayit:
        """Görselin, slug'ın ve ilçe bağlarının devralındığı kayıt.

        **Çapa değil.** Çapa eşleşmenin ölçüldüğü referans ve hiç
        değişmiyor; lider yeni üye geldikçe değişebiliyor. İkisini
        ayırmak gerekiyor çünkü çapa değişseydi geçmişte verilmiş
        eşleştirme kararları tutarsızlaşırdı.

        Sıra, okurun o bilgiyi nerede gördüğüne göre: gerçek fotoğraf,
        sonra belirgin şekilde uzun başlık (akışta görünen tek şey o),
        sonra gövde uzunluğu, eşitlikte önce derlenen.
        """
        def anahtar(k: Kayit):
            return (
                0 if k.fotografli else 1,
                -(len(k.baslik) // BASLIK_FARK_ESIGI),
                -len(k.govde or ""),
                k.olusturuldu,
            )
        return min(self.uyeler, key=anahtar)

    def __len__(self) -> int:
        return len(self.uyeler)


# ── Eşleşme ──────────────────────────────────────────────────────

def yer_uyuyor(a: Kayit, b: Kayit) -> bool:
    """İlçe kümeleri kesişiyor, ya da ikisi de boş.

    Boş küme dolu kümenin alt kümesi SAYILMIYOR. "Kastamonu'da tören"
    ile "Tosya'da tören" ayrı haberler ve tam olarak bu ayrım üç ilçenin
    haberini kurtarıyor — ölçümde bu çiftin başlık benzerliği 0,45'ti,
    yani yalnız başlığa bakan bir kural onları birleştirirdi.
    """
    if not a.ilceler and not b.ilceler:
        return True
    return bool(a.ilceler & b.ilceler)


def eslesir_mi(yeni: Kayit, capa: Kayit) -> tuple[bool, float]:
    """Yeni kayıt bu olaya girer mi, ve benzerliği kaç.

    Elemeler eşikten ÖNCE çalışıyor: yanlış birleştirme, kaçırılan
    tekrardan daha zararlı.
    """
    if yeni.id == capa.id:
        return False, 0.0
    if abs(yeni.olusturuldu - capa.olusturuldu) > PENCERE:
        return False, 0.0
    if not yer_uyuyor(yeni, capa):
        return False, 0.0
    if aile(yeni.kategori_ad) != aile(capa.kategori_ad):
        return False, 0.0
    return True, benzerlik(yeni.baslik, capa.baslik)


# ── Kümeleme ─────────────────────────────────────────────────────

def kumele(
    kayitlar: Iterable[Kayit],
    esik: float = ESIK,
) -> tuple[list[Olay], list[tuple[Kayit, Kayit, float]]]:
    """Kayıtları olaylara ayırır.

    Dönen ikinci liste **aday çiftler**: eşiği geçemeyen ama
    [ADAY_ESIGI]'ni geçen, yani editöre "bunlar aynı olay mı?" diye
    sorulacak olanlar. Eşiğin gerçek değeri ancak bu cevaplardan
    ölçülebiliyor.

    Her kayıt yalnız olayın **çapasına** ölçülüyor, bütün üyelere değil.
    Tek-bağ kümelemede A~B ve B~C olup A≁C olabiliyor; zincir uzadıkça
    küme ilgisiz haberleri yutuyor. Çapa sabit tutulunca küme kayamıyor
    ve karar açıklanabilir kalıyor: editöre "bu haber şu habere
    benzediği için buraya girdi" denebiliyor.

    Gelen sıra korunmuyor; kayıtlar derleme anına göre işleniyor ki
    çapa her zaman olayın ilk kaydı olsun.
    """
    olaylar: list[Olay] = []
    adaylar: list[tuple[Kayit, Kayit, float]] = []

    for k in sorted(kayitlar, key=lambda x: (x.olusturuldu, x.id)):
        en_iyi: Olay | None = None
        en_skor = 0.0
        for o in olaylar:
            uyar, skor = eslesir_mi(k, o.capa)
            if not uyar:
                continue
            if skor >= esik and skor > en_skor:
                en_iyi, en_skor = o, skor
            elif ADAY_ESIGI <= skor < esik:
                adaylar.append((k, o.capa, skor))

        if en_iyi is not None:
            en_iyi.uyeler.append(k)
        else:
            olaylar.append(Olay(capa=k, uyeler=[k]))

    return olaylar, adaylar
