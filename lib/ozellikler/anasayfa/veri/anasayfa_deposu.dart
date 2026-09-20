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
    katman, onem, diaspora, durum, olusturuldu, gorsel_url,
    kategoriler ( ad ),
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
final yayindakilerSaglayici = Provider<AsyncValue<List<Haber>>>((ref) {
  final ilce = ref.watch(ilceSuzgeciSaglayici);
  return ref.watch(tumYayindakilerSaglayici).whenData((liste) {
    if (ilce == null) return liste;
    return liste.where((h) => onayliIlceler(h).contains(ilce)).toList();
  });
});

/// Süzgeçte YALNIZCA yayımlanmış haberi olan ilçeler görünüyor.
///
/// 20 ilçenin tamamını listelemek yanıltıcı olurdu: ölçümde katman 1+2
/// akışında ilçelerin yarısından fazlasına hiç haber gelmiyor. Tıklayınca
/// boş liste çıkan bir süzgeç, olmayan süzgeçten kötüdür.
final ilceListesiSaglayici =
    Provider<AsyncValue<List<({String id, String ad})>>>((ref) {
      return ref.watch(tumYayindakilerSaglayici).whenData((liste) {
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
