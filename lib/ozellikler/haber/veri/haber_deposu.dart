import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/supabase.dart';
import '../../inceleme/model/haber.dart';

class HaberDeposu {
  static const _secim = '''
    id, slug, baslik, spot, govde, kaynak_adi, kaynak_url, yayinci,
    katman, onem, diaspora, durum, olusturuldu,
    kategoriler ( ad ),
    haber_ilce ( ilce_id, guven, kaynak, onaylandi, ilceler ( ad ) )
  ''';

  /// Tek haberi slug ile getirir.
  ///
  /// `durum='yayinda'` koşulu burada da AÇIKÇA yazılı. RLS zaten anonim
  /// kullanıcıyı sınırlıyor ama editör oturumu açıkken o sınır kalkıyor;
  /// ana sayfadaki ilçe süzgecinde bu tam olarak başımıza geldi. Görünürlük
  /// koşulu sorgunun kendisinde olmalı.
  Future<Haber?> slugIle(String slug) async {
    final y = await sb
        .from('haberler')
        .select(_secim)
        .eq('slug', slug)
        .eq('durum', 'yayinda')
        .maybeSingle();
    if (y == null) return null;
    return Haber.jsondan(y);
  }

  /// İlgili haberler: önce aynı ilçeden, yetmezse aynı kategoriden.
  ///
  /// Yerel bir portalda "aynı ilçe" bağı "aynı kategori"den daha anlamlı:
  /// Tosya'daki bir haberi okuyan kişi Tosya'nın başka haberini merak eder,
  /// başka ilçedeki bir ekonomi haberini değil.
  Future<List<Haber>> ilgililer(Haber haber, {int adet = 4}) async {
    final ilceIdler = haber.ilceler
        .where((b) => b.onaylandi)
        .map((b) => b.ilceId)
        .toList();

    final toplanan = <String, Haber>{};

    if (ilceIdler.isNotEmpty) {
      final y = await sb
          .from('haberler')
          .select(_secim)
          .eq('durum', 'yayinda')
          .neq('id', haber.id)
          .order('olusturuldu', ascending: false)
          .limit(40);
      for (final j in (y as List)) {
        final h = Haber.jsondan(j as Map<String, dynamic>);
        final ortak = h.ilceler.any(
          (b) => b.onaylandi && ilceIdler.contains(b.ilceId),
        );
        if (ortak) toplanan[h.id] = h;
        if (toplanan.length >= adet) break;
      }
    }

    if (toplanan.length < adet && haber.kategoriAd != null) {
      final y = await sb
          .from('haberler')
          .select(_secim)
          .eq('durum', 'yayinda')
          .neq('id', haber.id)
          .order('olusturuldu', ascending: false)
          .limit(20);
      for (final j in (y as List)) {
        final h = Haber.jsondan(j as Map<String, dynamic>);
        if (h.kategoriAd == haber.kategoriAd) toplanan[h.id] = h;
        if (toplanan.length >= adet) break;
      }
    }

    return toplanan.values.take(adet).toList();
  }
}

final haberDeposuSaglayici = Provider((_) => HaberDeposu());

final haberSaglayici = FutureProvider.autoDispose.family<Haber?, String>((
  ref,
  slug,
) {
  return ref.watch(haberDeposuSaglayici).slugIle(slug);
});

final ilgililerSaglayici = FutureProvider.autoDispose
    .family<List<Haber>, Haber>((ref, haber) {
      return ref.watch(haberDeposuSaglayici).ilgililer(haber);
    });
