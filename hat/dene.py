"""Kümelemeyi yayındaki gerçek veriyle koşturur.

    python3 -m hat.dene

Okuma amaçlı: anon anahtarla yalnız yayındaki haberleri çekiyor,
veritabanına hiçbir şey yazmıyor.

    python3 -m hat.dene --sentez

da verilirse birleşen olaylar için metin de yazdırılıyor. Bunun için
`GEMINI_API_KEY` gerekiyor ve her olay bir model çağrısı demek.
"""

from __future__ import annotations

import json
import os
import urllib.request
from datetime import datetime

from .kumele import ADAY_ESIGI, ESIK, Kayit, kumele


def _ayar(ad: str, varsayilan: str = "") -> str:
    v = os.environ.get(ad)
    if v:
        return v
    # functions/.env içindeki anon anahtar — yayımlanmak üzere tasarlandı.
    yol = os.path.join(os.path.dirname(__file__), "..", "functions", ".env")
    try:
        for satir in open(yol, encoding="utf-8"):
            if satir.startswith(ad + "="):
                return satir.split("=", 1)[1].strip()
    except OSError:
        pass
    return varsayilan


def getir() -> list[Kayit]:
    taban, anahtar = _ayar("SUPABASE_URL"), _ayar("SUPABASE_ANON_KEY")
    alanlar = ("baslik,olusturuldu,kaynak_adi,spot,govde,olgular,sayilar,"
               "kaynak_url,gorsel_url,gorsel_kaynak,id,"
               "kategoriler(ad),haber_ilce(onaylandi,ilce_id)")
    url = f"{taban}/rest/v1/haberler?select={alanlar}&order=olusturuldu.desc&limit=500"
    istek = urllib.request.Request(url, headers={
        "apikey": anahtar, "Authorization": f"Bearer {anahtar}",
    })
    with urllib.request.urlopen(istek, timeout=60) as y:
        ham = json.load(y)

    kayitlar = []
    for h in ham:
        kat = h.get("kategoriler") or {}
        ilceler = frozenset(
            b["ilce_id"] for b in (h.get("haber_ilce") or [])
            if b.get("onaylandi") and b.get("ilce_id")
        )
        kayitlar.append(Kayit(
            id=h["id"], baslik=h["baslik"] or "",
            kaynak_adi=h.get("kaynak_adi") or "?",
            olusturuldu=datetime.fromisoformat(h["olusturuldu"]),
            kategori_ad=kat.get("ad") if isinstance(kat, dict) else None,
            ilceler=ilceler, spot=h.get("spot"), govde=h.get("govde"),
            olgular=h.get("olgular") or {}, sayilar=h.get("sayilar") or [],
            kaynak_url=h.get("kaynak_url"), gorsel_url=h.get("gorsel_url"),
            gorsel_kaynak=h.get("gorsel_kaynak"),
        ))
    return kayitlar


def main(argv: list[str] | None = None) -> None:
    import sys

    sentezle = "--sentez" in (argv if argv is not None else sys.argv[1:])
    kayitlar = getir()
    olaylar, adaylar = kumele(kayitlar)
    coklu = [o for o in olaylar if len(o) > 1]

    print(f"Yayındaki kayıt     : {len(kayitlar)}")
    print(f"Olay                : {len(olaylar)}")
    print(f"Birleşen olay       : {len(coklu)}  (eşik {ESIK})")
    print(f"Editöre sorulacak   : {len(adaylar)}  (aday eşiği {ADAY_ESIGI})")

    for o in coklu:
        print(f"\n{'─'*66}\nOLAY — {len(o)} kayıt, kaynaklar: {', '.join(o.kaynaklar)}")
        for k in o.uyeler:
            isaret = "LİDER" if k.id == o.lider.id else "     "
            print(f"  {isaret} [{k.kaynak_adi.split('/')[0].strip()}] {k.baslik[:62]}")
        birlesik: dict[str, set[str]] = {}
        for k in o.uyeler:
            for alan, deger in (k.olgular or {}).items():
                if deger:
                    birlesik.setdefault(alan, set()).add(str(deger))
        print("  Birleşik olgular:")
        for alan, degerler in birlesik.items():
            print(f"    {alan:9} {' || '.join(sorted(degerler))[:100]}")
        # Ölçüt alan ADI değil, alan İÇERİĞİ: iki kaynak da "kim" alanını
        # doldurabiliyor ama biri "Yaşar Mıcık", öbürü "Yaşar Mıcık,
        # itfaiye ve orman ekipleri, jandarma" yazıyor. Kazanç burada.
        tek = max((sum(len(str(v)) for v in (k.olgular or {}).values() if v)
                   for k in o.uyeler), default=0)
        toplam = sum(len(d) for degerler in birlesik.values() for d in degerler)
        ek = sum(1 for degerler in birlesik.values() if len(degerler) > 1)
        if tek:
            print(f"  Olgu metni: en iyi tek kayıt {tek} karakter → birleşik "
                  f"{toplam} ({toplam/tek:.1f}×)")
            print(f"  Kaynakların birbirini tamamladığı alan: {ek}/{len(birlesik)}")

    if sentezle and coklu:
        from .gemini import MODEL, cagirici
        from .sentez import DenetimHatasi, durum, yaz

        cagir = cagirici()
        print(f"\n{'═'*66}\nSENTEZ  ({MODEL})")
        for o in coklu:
            print(f"\n  Kaynaklar: {', '.join(o.kaynaklar)}")
            try:
                s = yaz(o, cagir)
            except DenetimHatasi as e:
                print(f"  ✗ denetimden geçmedi: {e}")
                continue
            print(f"  Durum   : {durum(s)}")
            print(f"  BAŞLIK  : {s.baslik}")
            print(f"  SPOT    : {s.spot}")
            print(f"  GÖVDE   :")
            for par in s.govde.split("\n"):
                if par.strip():
                    print(f"            {par.strip()}")
            print(f"  KÜNYE   : {', '.join(s.kullanilan_kaynaklar)}")
            if s.celiskiler:
                print("  ÇELİŞKİ :")
                for c in s.celiskiler:
                    degerler = ", ".join(f"{x.kaynak}: {x.deger}" for x in c.degerler)
                    print(f"            {c.konu} → {degerler}")

    if adaylar:
        print(f"\n{'─'*66}\nEDİTÖRE SORULACAK ÇİFTLER")
        for yeni, capa, skor in adaylar[:8]:
            print(f"  {skor:.2f}  {yeni.baslik[:58]}")
            print(f"        {capa.baslik[:58]}")


if __name__ == "__main__":
    main()
