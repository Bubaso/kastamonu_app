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
    katman, onem, diaspora, durum, olusturuldu,
    kategoriler ( ad ),
    haber_ilce ( ilce_id, guven, kaynak, onaylandi, ilceler ( ad ) )
  ''';

  Future<List<Haber>> yayindakiler({String? ilceId}) async {
    var sorgu = sb.from('haberler').select(_secim).eq('durum', 'yayinda');
    // İlçe süzgeci: gömülü kaynak üzerinden filtre. Yalnızca ONAYLI bağlar
    // sayılıyor — doğrulanmamış bir bağ akışı kirletmemeli.
    if (ilceId != null) {
      sorgu = sorgu
          .eq('haber_ilce.ilce_id', ilceId)
          .not('haber_ilce', 'is', null);
    }
    final yanit = await sorgu
        .order('yayinlandi', ascending: false)
        .order('olusturuldu', ascending: false)
        .limit(60);
    final liste = (yanit as List)
        .map((j) => Haber.jsondan(j as Map<String, dynamic>))
        .toList();
    if (ilceId == null) return liste;
    // PostgREST gömülü filtresi ana satırı elemiyor, yalnızca gömülü diziyi
    // boşaltıyor. Eşleşmeyenleri burada ayıklıyoruz.
    return liste
        .where((h) => h.ilceler.any((b) => b.ilceId == ilceId && b.onaylandi))
        .toList();
  }

  /// Süzgeçte YALNIZCA yayımlanmış haberi olan ilçeler gösteriliyor.
  ///
  /// 20 ilçenin tamamını listelemek yanıltıcı olurdu: ölçümde katman 1+2
  /// akışında ilçelerin yarısından fazlasına hiç haber gelmiyor. Tıklayınca
  /// boş liste çıkan bir süzgeç, olmayan süzgeçten kötüdür.
  ///
  /// Sorgu `haber_ilce` üzerinden çalışıyor; RLS gereği bu tablo anon
  /// kullanıcıya zaten yalnızca **onaylı bağ + yayındaki haber** satırlarını
  /// veriyor. Yani süzgeç listesi kendiliğinden doğru.
  Future<List<({String id, String ad})>> ilceler() async {
    final y = await sb.from('haber_ilce').select('ilce_id, ilceler ( ad, sira )');
    final gorulen = <String, ({String id, String ad, int sira})>{};
    for (final j in (y as List)) {
      final ilce = j['ilceler'];
      if (ilce is! Map) continue;
      final id = j['ilce_id'] as String;
      gorulen[id] = (
        id: id,
        ad: ilce['ad'] as String? ?? '?',
        sira: (ilce['sira'] as num?)?.toInt() ?? 99,
      );
    }
    final liste = gorulen.values.toList()
      ..sort((a, b) => a.sira != b.sira
          ? a.sira.compareTo(b.sira)
          : a.ad.compareTo(b.ad));
    return liste.map((e) => (id: e.id, ad: e.ad)).toList();
  }
}

final anasayfaDeposuSaglayici = Provider((_) => AnasayfaDeposu());

/// Seçili ilçe süzgeci; null = il geneli.
class IlceSuzgeci extends Notifier<String?> {
  @override
  String? build() => null;
  void sec(String? id) => state = id;
}

final ilceSuzgeciSaglayici =
    NotifierProvider<IlceSuzgeci, String?>(IlceSuzgeci.new);

final yayindakilerSaglayici =
    FutureProvider.autoDispose<List<Haber>>((ref) async {
  final ilce = ref.watch(ilceSuzgeciSaglayici);
  return ref.watch(anasayfaDeposuSaglayici).yayindakiler(ilceId: ilce);
});

final ilceListesiSaglayici =
    FutureProvider<List<({String id, String ad})>>((ref) {
  return ref.watch(anasayfaDeposuSaglayici).ilceler();
});
