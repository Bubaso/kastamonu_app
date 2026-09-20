import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/supabase.dart';
import '../../inceleme/model/haber.dart';

/// Genel (giriş gerektirmeyen) taraf.
///
/// Bu katman anon anahtarla çalışıyor ve RLS gereği yalnızca
/// `durum='yayinda'` kaydı görebiliyor. Yani inceleme masasındaki haber
/// buraya kod hatasıyla bile sızamaz — koruma uygulamada değil,
/// veritabanında.
class AnasayfaDeposu {
  static const _secim = '''
    id, slug, baslik, spot, govde, kaynak_adi, kaynak_url, yayinci,
    katman, onem, diaspora, durum, olusturuldu, gorsel_url, gorsel_kaynak,
    kategoriler ( ad, slug ),
    haber_ilce ( ilce_id, guven, kaynak, onaylandi, ilceler ( ad, sira ) )
  ''';

  /// Yayındaki TÜM haberler — tek sorgu, süzgeçsiz.
  ///
  /// Bu liste uygulamanın tek okuma kaynağı: ana sayfa akışı, ilçe süzgeci
  /// listesi ve detay sayfasındaki "diğer haberler" şeridi hepsi bundan
  /// besleniyor. Süzme bellekte yapılıyor.
  ///
  /// Neden böyle: her görünüm için ayrı sorgu yazmak hem gereksiz (portal
  /// ölçeğinde toplam kayıt birkaç yüz) hem de kırılgandı — ilçe süzgecinde
  /// PostgREST'in gömülü kaynak filtresi ana satırı elemeyip yalnızca
  /// gömülü diziyi boşalttığı için sonradan ayıklama yapmak gerekiyordu.
  /// Tek liste + bellekte süzme o katmanı tamamen kaldırıyor.
  ///
  /// `durum='yayinda'` koşulu AÇIKÇA yazılı: RLS emniyet ağıdır, sorgu
  /// mantığı değildir (editör oturumu açıkken anon kuralı geçerli olmuyor).
  Future<List<Haber>> tumYayindakiler() async {
    final yanit = await sb
        .from('haberler')
        .select(_secim)
        .eq('durum', 'yayinda')
        .order('yayinlandi', ascending: false)
        .order('olusturuldu', ascending: false)
        .limit(200);
    return (yanit as List)
        .map((j) => Haber.jsondan(j as Map<String, dynamic>))
        .toList();
  }
}

/// Bir haberin onaylı ilçe kimlikleri.
Set<String> onayliIlceler(Haber h) =>
    h.ilceler.where((b) => b.onaylandi).map((b) => b.ilceId).toSet();

final anasayfaDeposuSaglayici = Provider((_) => AnasayfaDeposu());

/// Yayındaki tüm haberler. `autoDispose` DEĞİL — sayfalar arası gezinirken
/// liste sıcak kalsın ve her geçişte yeniden çekilmesin.
final tumYayindakilerSaglayici = FutureProvider<List<Haber>>((ref) {
  return ref.watch(anasayfaDeposuSaglayici).tumYayindakiler();
});

/// Yayımlanmış haberi olan kategoriler.
///
/// İlçe süzgecindeki kuralın aynısı: boş kategori gösterilmiyor. Ölçümde
/// bazı kategorilere (Sağlık, Spor) günlerce haber gelmeyebiliyor;
/// tıklayınca boş çıkan bir bölüm, olmayan bölümden kötü.
final kategoriListesiSaglayici =
    Provider<AsyncValue<List<({String slug, String ad, int adet})>>>((ref) {
      return ref.watch(tumYayindakilerSaglayici).whenData((liste) {
        final sayac = <String, ({String slug, String ad, int adet})>{};
        for (final h in liste) {
          final slug = h.kategoriSlug;
          final ad = h.kategoriAd;
          if (slug == null || ad == null) continue;
          final onceki = sayac[slug];
          sayac[slug] = (slug: slug, ad: ad, adet: (onceki?.adet ?? 0) + 1);
        }
        final sirali = sayac.values.toList()
          ..sort(
            (a, b) => b.adet != a.adet
                ? b.adet.compareTo(a.adet)
                : a.ad.compareTo(b.ad),
          );
        return sirali;
      });
    });

/// Seçili kategori; null = tümü.
class KategoriSecimi extends Notifier<String?> {
  @override
  String? build() => null;
  void sec(String? slug) => state = slug;
}

final kategoriSecimiSaglayici = NotifierProvider<KategoriSecimi, String?>(
  KategoriSecimi.new,
);

/// Seçili ilçe süzgeci; null = il geneli.
class IlceSuzgeci extends Notifier<String?> {
  @override
  String? build() => null;
  void sec(String? id) => state = id;
}

final ilceSuzgeciSaglayici = NotifierProvider<IlceSuzgeci, String?>(
  IlceSuzgeci.new,
);

/// Ana sayfa akışı: tek listeden bellekte süzülüyor.
///
/// İki süzgeç birlikte çalışıyor — kategori (bölüm) ve ilçe (yer).
/// İkisi de aynı listeden, ek sorgu yok.
final yayindakilerSaglayici = Provider<AsyncValue<List<Haber>>>((ref) {
  final ilce = ref.watch(ilceSuzgeciSaglayici);
  final kategori = ref.watch(kategoriSecimiSaglayici);
  return ref.watch(tumYayindakilerSaglayici).whenData((liste) {
    var sonuc = liste;
    if (kategori != null) {
      sonuc = sonuc.where((h) => h.kategoriSlug == kategori).toList();
    }
    if (ilce != null) {
      sonuc = sonuc.where((h) => onayliIlceler(h).contains(ilce)).toList();
    }
    return sonuc;
  });
});

/// Süzgeçte YALNIZCA yayımlanmış haberi olan ilçeler görünüyor.
///
/// 20 ilçenin tamamını listelemek yanıltıcı olurdu: ölçümde katman 1+2
/// akışında ilçelerin yarısından fazlasına hiç haber gelmiyor. Tıklayınca
/// boş liste çıkan bir süzgeç, olmayan süzgeçten kötüdür.
/// Süzgeçteki ilçeler seçili kategoriye göre daralıyor: "Spor" seçiliyken
/// spor haberi olmayan ilçeyi göstermenin anlamı yok. Tıklayınca boş
/// çıkan süzgeç, olmayan süzgeçten kötü — aynı kural kategorilerde de var.
final ilceListesiSaglayici =
    Provider<AsyncValue<List<({String id, String ad})>>>((ref) {
      final kategori = ref.watch(kategoriSecimiSaglayici);
      return ref.watch(tumYayindakilerSaglayici).whenData((tumu) {
        final liste = kategori == null
            ? tumu
            : tumu.where((h) => h.kategoriSlug == kategori).toList();
        final gorulen = <String, ({String id, String ad, int sira})>{};
        for (final h in liste) {
          for (final b in h.ilceler) {
            if (!b.onaylandi) continue;
            gorulen[b.ilceId] = (id: b.ilceId, ad: b.ad, sira: b.sira);
          }
        }
        final sirali = gorulen.values.toList()
          ..sort(
            (a, b) => a.sira != b.sira
                ? a.sira.compareTo(b.sira)
                : a.ad.compareTo(b.ad),
          );
        return sirali.map((e) => (id: e.id, ad: e.ad)).toList();
      });
    });

/// Haberi olan TÜM ilçeler — kategori seçiminden bağımsız.
///
/// [ilceListesiSaglayici] seçili bölüme göre daralıyor; bu ise "İlçem"
/// sekmesindeki seçim ekranı için, orada okur bölüm değil yer seçiyor.
final tumIlcelerSaglayici =
    Provider<AsyncValue<List<({String id, String ad, int adet})>>>((ref) {
      return ref.watch(tumYayindakilerSaglayici).whenData((liste) {
        final gorulen = <String, ({String id, String ad, int sira, int adet})>{};
        for (final h in liste) {
          for (final b in h.ilceler) {
            if (!b.onaylandi) continue;
            final onceki = gorulen[b.ilceId];
            gorulen[b.ilceId] = (
              id: b.ilceId,
              ad: b.ad,
              sira: b.sira,
              adet: (onceki?.adet ?? 0) + 1,
            );
          }
        }
        final sirali = gorulen.values.toList()
          ..sort(
            (a, b) => a.sira != b.sira
                ? a.sira.compareTo(b.sira)
                : a.ad.compareTo(b.ad),
          );
        return sirali
            .map((e) => (id: e.id, ad: e.ad, adet: e.adet))
            .toList();
      });
    });

/// Belirli bir ilçenin haberleri.
final ilceAkisiSaglayici =
    Provider.family<AsyncValue<List<Haber>>, String>((ref, ilceId) {
      return ref.watch(tumYayindakilerSaglayici).whenData(
        (liste) =>
            liste.where((h) => onayliIlceler(h).contains(ilceId)).toList(),
      );
    });
