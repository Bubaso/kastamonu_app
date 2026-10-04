"""Sentez testleri — model çağrısı olmadan.

`istek()` ve `dogrula()` saf işlevler; anahtar gerekmiyor. Model
çağrısı sahte bir istemciyle veriliyor.
"""

import json
import unittest
from datetime import datetime, timedelta, timezone

from .kumele import Kayit, Olay
from .sentez import Celiski, DenetimHatasi, Sentez, dogrula, durum, istek, yaz

T0 = datetime(2026, 9, 20, 10, 0, tzinfo=timezone.utc)


def olay_kur():
    """Ölçülen gerçek çift: Daday'da samanlık yangını."""
    a = Kayit(
        id="1", baslik="Daday'ın Bolatlar köyünde çıkan yangında samanlık "
                       "kullanılamaz hale geldi",
        kaynak_adi="Sondakika.com / Kastamonu", olusturuldu=T0,
        kategori_ad="Kaza ve Acil", ilceler=frozenset(["daday"]),
        olgular={"kim": "Yaşar Mıcık'a ait samanlık", "ne": "Samanlık yangını"},
    )
    b = Kayit(
        id="2", baslik="Daday'ın Bolatlar köyünde çıkan yangında Yaşar Mıcık'a "
                       "ait samanlık kullanılamaz hale geldi",
        kaynak_adi="Haberler.com / Kastamonu",
        olusturuldu=T0 + timedelta(hours=20),
        kategori_ad="Kaza ve Acil", ilceler=frozenset(["daday"]),
        olgular={"kim": "Yaşar Mıcık, itfaiye ve orman ekipleri, jandarma",
                 "nasil": "Köylülerin ihbarı üzerine sevk edilen ekipler"},
    )
    return Olay(capa=a, uyeler=[a, b])


class Istek(unittest.TestCase):
    def test_her_kaydin_olgulari_gidiyor(self):
        """Birleştirmenin amacı bu: bir kaynağın yazıp öbürünün
        yazmadığı ayrıntı modele ulaşmalı."""
        m = istek(olay_kur())
        self.assertIn("jandarma", m)
        self.assertIn("Köylülerin ihbarı", m)

    def test_gecerli_json_tasiyor(self):
        m = istek(olay_kur())
        json.loads(m[m.index("["):])

    def test_kaynak_adlari_gidiyor(self):
        m = istek(olay_kur())
        self.assertIn("Sondakika.com / Kastamonu", m)
        self.assertIn("Haberler.com / Kastamonu", m)


class Dogrula(unittest.TestCase):
    def iyi(self, **f):
        g = dict(
            baslik="Daday'da samanlık yangını",
            spot="Bolatlar köyünde çıkan yangında samanlık kullanılamaz hale geldi.",
            govde="Yangına itfaiye, orman ekipleri ve jandarma müdahale etti.",
            kullanilan_kaynaklar=["Sondakika.com / Kastamonu",
                                  "Haberler.com / Kastamonu"],
        )
        g.update(f)
        return Sentez(**g)

    def test_gecerli_cikti_gecer(self):
        dogrula(self.iyi(), olay_kur())

    def test_uydurulan_kaynak_reddedilir(self):
        """Model kümede olmayan bir yayını künyeye yazarsa yayına çıkmamalı."""
        with self.assertRaises(DenetimHatasi) as e:
            dogrula(self.iyi(kullanilan_kaynaklar=["Hürriyet"]), olay_kur())
        self.assertIn("Hürriyet", str(e.exception))

    def test_kaynaksiz_reddedilir(self):
        with self.assertRaises(DenetimHatasi):
            dogrula(self.iyi(kullanilan_kaynaklar=[]), olay_kur())

    def test_bos_govde_reddedilir(self):
        with self.assertRaises(DenetimHatasi):
            dogrula(self.iyi(govde="   "), olay_kur())

    def test_celiskide_yabanci_kaynak_reddedilir(self):
        with self.assertRaises(DenetimHatasi):
            dogrula(
                self.iyi(celiskiler=[Celiski(konu="saat",
                                             degerler={"Hürriyet": "14.00"})]),
                olay_kur(),
            )


class Durum(unittest.TestCase):
    def test_celiskisiz_yazildi(self):
        self.assertEqual(durum(Sentez(baslik="a", spot="b", govde="c",
                                      kullanilan_kaynaklar=["x"])), "yazildi")

    def test_celiskili_editore_duser(self):
        """Çelişkili haber sessizce yayına çıkmamalı."""
        s = Sentez(baslik="a", spot="b", govde="c", kullanilan_kaynaklar=["x"],
                   celiskiler=[Celiski(konu="yaralı sayısı",
                                       degerler={"A": "3", "B": "5"})])
        self.assertEqual(durum(s), "celiskili")


class SahteIstemci:
    """`messages.parse` taklidi."""

    def __init__(self, sonuc, stop_reason="end_turn"):
        self._s, self._r = sonuc, stop_reason
        self.cagrildi = None
        self.messages = self

    def parse(self, **kw):
        self.cagrildi = kw
        return type("Y", (), {"parsed_output": self._s, "stop_reason": self._r})()


class Yaz(unittest.TestCase):
    def test_denetimden_gecen_doner(self):
        s = Sentez(baslik="a", spot="b", govde="c",
                   kullanilan_kaynaklar=["Haberler.com / Kastamonu"])
        self.assertIs(yaz(olay_kur(), SahteIstemci(s)), s)

    def test_denetimden_gecmeyen_yukselir(self):
        s = Sentez(baslik="a", spot="b", govde="c",
                   kullanilan_kaynaklar=["Uydurma Gazete"])
        with self.assertRaises(DenetimHatasi):
            yaz(olay_kur(), SahteIstemci(s))

    def test_red_yakalaniyor(self):
        """Güvenlik sınıflandırıcısı reddederse içerik okunmamalı."""
        s = Sentez(baslik="a", spot="b", govde="c", kullanilan_kaynaklar=["x"])
        with self.assertRaises(DenetimHatasi) as e:
            yaz(olay_kur(), SahteIstemci(s, stop_reason="refusal"))
        self.assertIn("reddetti", str(e.exception))

    def test_yonerge_gonderiliyor(self):
        s = Sentez(baslik="a", spot="b", govde="c",
                   kullanilan_kaynaklar=["Haberler.com / Kastamonu"])
        i = SahteIstemci(s)
        yaz(olay_kur(), i)
        self.assertIn("KOPYALAMA", i.cagrildi["system"])
        self.assertEqual(i.cagrildi["output_format"], Sentez)


if __name__ == "__main__":
    unittest.main()
