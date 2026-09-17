import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/supabase.dart';
import '../model/haber.dart';

/// İnceleme masasının veri katmanı.
class IncelemeDeposu {
  /// Tek sorguda haber + kategori + ilçe bağları.
  ///
  /// Bağları ayrı sorgularla çekmek N+1 doğururdu; PostgREST'in gömülü
  /// kaynak sözdizimi tek istekte getiriyor.
  static const _secim = '''
    id, slug, baslik, spot, govde, kaynak_adi, kaynak_url, yayinci,
    katman, onem, diaspora, durum, olusturuldu,
    kategoriler ( ad ),
    haber_ilce ( ilce_id, guven, kaynak, onaylandi, ilceler ( ad ) )
  ''';

  Future<List<Haber>> getir(String durum) async {
    final yanit = await sb
        .from('haberler')
        .select(_secim)
        .eq('durum', durum)
        .order('onem', ascending: false)
        .order('olusturuldu', ascending: false)
        .limit(100);
    return (yanit as List)
        .map((j) => Haber.jsondan(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> sayimlar() async {
    final sonuc = <String, int>{};
    for (final d in ['inceleme', 'yayinda', 'reddedildi']) {
      final y = await sb.from('haberler').select('id').eq('durum', d);
      sonuc[d] = (y as List).length;
    }
    return sonuc;
  }

  Future<void> alanlariKaydet(
    String id, {
    required String baslik,
    required String spot,
    required String govde,
  }) async {
    await sb.from('haberler').update({
      'baslik': baslik,
      'spot': spot,
      'govde': govde,
    }).eq('id', id);
  }

  /// Yayına al. `yayinlandi` damgasını tetikleyici koyuyor (migration 0002).
  Future<void> yayinla(String id) async {
    await sb.from('haberler').update({'durum': 'yayinda'}).eq('id', id);
  }

  Future<void> reddet(String id, String? gerekce) async {
    await sb.from('haberler').update({
      'durum': 'reddedildi',
      'inceleme_notu': gerekce,
    }).eq('id', id);
  }

  Future<void> incelemeyeAl(String id) async {
    await sb.from('haberler').update({'durum': 'inceleme'}).eq('id', id);
  }

  Future<void> bagOnayla(String haberId, String ilceId, bool onay) async {
    await sb
        .from('haber_ilce')
        .update({'onaylandi': onay})
        .eq('haber_id', haberId)
        .eq('ilce_id', ilceId);
  }

  Future<void> bagSil(String haberId, String ilceId) async {
    await sb
        .from('haber_ilce')
        .delete()
        .eq('haber_id', haberId)
        .eq('ilce_id', ilceId);
  }
}

final depoSaglayici = Provider((_) => IncelemeDeposu());

/// Hangi durum listeleniyor.
///
/// Riverpod 3'te `StateProvider` kaldırıldı; tek alanlık durum için de
/// `Notifier` kullanılıyor.
class DurumSecimi extends Notifier<String> {
  @override
  String build() => 'inceleme';

  void sec(String durum) => state = durum;
}

final durumSaglayici =
    NotifierProvider<DurumSecimi, String>(DurumSecimi.new);

final haberlerSaglayici = FutureProvider.autoDispose<List<Haber>>((ref) async {
  final durum = ref.watch(durumSaglayici);
  return ref.watch(depoSaglayici).getir(durum);
});

final sayimSaglayici = FutureProvider.autoDispose<Map<String, int>>((ref) {
  // Liste tazelenince sayımlar da tazelensin
  ref.watch(durumSaglayici);
  return ref.watch(depoSaglayici).sayimlar();
});
