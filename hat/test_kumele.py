"""Kümeleme testleri. `python3 -m unittest discover hat`"""

import unittest
from datetime import datetime, timedelta, timezone

from .kumele import ESIK, Kayit, Olay, aile, benzerlik, kumele, yer_uyuyor

T0 = datetime(2026, 9, 20, 10, 0, tzinfo=timezone.utc)


def k(id, baslik, *, kaynak="A", saat=0, gun=0, ilceler=(), kategori="Kaza ve Acil",
      govde="", fotograf=True):
    return Kayit(
        id=id, baslik=baslik, kaynak_adi=kaynak,
        olusturuldu=T0 + timedelta(days=gun, hours=saat),
        kategori_ad=kategori, ilceler=frozenset(ilceler), govde=govde,
        gorsel_url="x" if fotograf else None,
        gorsel_kaynak="y" if fotograf else None,
    )


class Benzerlik(unittest.TestCase):
    def test_turkce_sadelestirme(self):
        # "Taşköprü" ile "taskopru" aynı kelime sayılmalı
        self.assertEqual(benzerlik("Taşköprü'de yangın", "taskopru de yangin"), 1.0)

    def test_bos_baslik_sifir(self):
        self.assertEqual(benzerlik("", "bir şey"), 0.0)


class Yer(unittest.TestCase):
    def test_ikisi_de_bos_uyar(self):
        self.assertTrue(yer_uyuyor(k("1", "a"), k("2", "b")))

    def test_bos_kume_dolunun_alt_kumesi_degil(self):
        """'Kastamonu'da tören' ile 'Tosya'da tören' ayrı haberler."""
        self.assertFalse(yer_uyuyor(k("1", "a"), k("2", "b", ilceler=["tosya"])))

    def test_kesisiyorsa_uyar(self):
        self.assertTrue(
            yer_uyuyor(k("1", "a", ilceler=["tosya", "agli"]),
                       k("2", "b", ilceler=["agli"]))
        )


class Kumeleme(unittest.TestCase):
    def test_olculen_gercek_cift_birlesiyor(self):
        """Ölçümde yakalanan Daday yangını — benzerlik 0,75."""
        a = k("1", "Daday'ın Bolatlar köyünde çıkan yangında samanlık "
                   "kullanılamaz hale geldi", kaynak="Sondakika", ilceler=["daday"])
        b = k("2", "Daday'ın Bolatlar köyünde çıkan yangında Yaşar Mıcık'a ait "
                   "samanlık kullanılamaz hale geldi", kaynak="Haberler",
              ilceler=["daday"], saat=20)
        olaylar, _ = kumele([a, b])
        self.assertEqual(len(olaylar), 1)
        self.assertEqual(len(olaylar[0]), 2)

    def test_ayri_ilceler_birlesmiyor(self):
        """Ölçümdeki tuzak çift: ortak kelimelerin hepsi vesileye ait."""
        a = k("1", "Kastamonu'da 19 Eylül Gaziler Günü düzenlenen yürüyüş ve "
                   "törenlerle kutlandı", kategori="Gündem")
        b = k("2", "Tosya, Taşköprü ve Ağlı'da 19 Eylül Gaziler Günü törenlerle "
                   "kutlandı", kategori="Gündem", ilceler=["tosya", "agli"])
        olaylar, _ = kumele([a, b])
        self.assertEqual(len(olaylar), 2)

    def test_farkli_aile_birlesmiyor(self):
        a = k("1", "Tosya'da büyük yangın çıktı", kategori="Kaza ve Acil",
              ilceler=["tosya"])
        b = k("2", "Tosya'da büyük yangın çıktı", kategori="Spor",
              ilceler=["tosya"])
        olaylar, _ = kumele([a, b])
        self.assertEqual(len(olaylar), 2)

    def test_pencere_disi_birlesmiyor(self):
        a = k("1", "Tosya'da samanlık yangını söndürüldü", ilceler=["tosya"])
        b = k("2", "Tosya'da samanlık yangını söndürüldü", ilceler=["tosya"], gun=9)
        olaylar, _ = kumele([a, b])
        self.assertEqual(len(olaylar), 2)

    def test_capa_ilk_kayit_ve_degismiyor(self):
        """Çapa olayın ilk kaydı; sonradan gelen üye onu değiştirmiyor."""
        once = k("1", "Tosya'da samanlık yangını söndürüldü", ilceler=["tosya"])
        sonra = k("2", "Tosya'da samanlık yangını söndürüldü ve hasar oluştu",
                  ilceler=["tosya"], saat=5)
        olaylar, _ = kumele([sonra, once])  # sıra bilerek ters
        self.assertEqual(len(olaylar), 1)
        self.assertEqual(olaylar[0].capa.id, "1")

    def test_aday_cift_isaretleniyor(self):
        """Eşiğin altında ama aday eşiğinin üstünde kalanlar editöre gider."""
        a = k("1", "Kastamonu'da 19 Eylül Gaziler Günü yürüyüş ve törenlerle "
                   "kutlandı", kategori="Gündem")
        b = k("2", "Kastamonu'da 19 Eylül Gaziler Günü törenlerle kutlandı ve "
                   "çelenk sunuldu", kategori="Gündem", saat=2)
        _, adaylar = kumele([a, b], esik=0.95)
        self.assertEqual(len(adaylar), 1)
        self.assertGreater(adaylar[0][2], 0.45)


class Lider(unittest.TestCase):
    def test_fotograf_her_seyin_onunde(self):
        fotosuz = k("1", "Tosya'da yangın çıktı ve samanlık tamamen yandı",
                    ilceler=["tosya"], fotograf=False, govde="x" * 900)
        fotoli = k("2", "Tosya'da yangın çıktı", ilceler=["tosya"], saat=1)
        o = Olay(capa=fotosuz, uyeler=[fotosuz, fotoli])
        self.assertEqual(o.lider.id, "2")

    def test_belirgin_uzun_baslik_govdeyi_deviriyor(self):
        kisa = k("1", "Tosya'da yangın çıktı", ilceler=["tosya"], govde="x" * 900)
        uzun = k("2", "Tosya'da Ahmet Yılmaz'a ait samanlıkta yangın çıktı",
                 ilceler=["tosya"], govde="x" * 100, saat=1)
        o = Olay(capa=kisa, uyeler=[kisa, uzun])
        self.assertEqual(o.lider.id, "2")

    def test_kaynaklar_tekil_ve_sirali(self):
        a = k("1", "Tosya'da yangın", kaynak="Haberler", ilceler=["tosya"])
        b = k("2", "Tosya'da yangın", kaynak="Sondakika", ilceler=["tosya"], saat=1)
        c = k("3", "Tosya'da yangın", kaynak="Haberler", ilceler=["tosya"], saat=2)
        o = Olay(capa=a, uyeler=[a, b, c])
        self.assertEqual(o.kaynaklar, ["Haberler", "Sondakika"])


class Aile(unittest.TestCase):
    def test_asayis_ile_kaza_ayni_aile(self):
        self.assertEqual(aile("Asayiş"), aile("Kaza ve Acil"))

    def test_bilinmeyen_diger(self):
        self.assertEqual(aile("Yok Böyle Bir Şey"), "diger")


if __name__ == "__main__":
    unittest.main()
