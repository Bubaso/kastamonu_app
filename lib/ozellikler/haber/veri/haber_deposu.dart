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
  /// İlgili haberler. Girdi SLUG — `Haber` nesnesi değil.
  ///
  /// Haberi burada kendisi çekiyor. İlk sürümde bu iş iki sağlayıcıya
  /// bölünmüştü: `ilgililerSaglayici` içinde `haberSaglayici(slug).future`
  /// bekleniyordu. İkisi de `autoDispose` olduğu için sağlayıcılar
  /// birbirini atıp yeniden kuruyor ve sonuç **hiç yerleşmiyordu** —
  /// ekranda bölüm sonsuza kadar "yükleniyor"da kaldı. Bir fazladan sorgu,
  /// iç içe sağlayıcıdan ucuz.
  Future<List<Haber>> ilgililer(String slug, {int adet = 4}) async {
    final haber = await slugIle(slug);
    if (haber == null) return const [];

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

    // Üçüncü yedek: ne aynı ilçeden ne aynı kategoriden bir şey yoksa
    // son haberler. Küçük bir portalda ilk haftalarda bu durum kural,
    // istisna değil — bölümü boş bırakmak sayfayı yarım gösteriyor.
    if (toplanan.isEmpty) {
      final y = await sb
          .from('haberler')
          .select(_secim)
          .eq('durum', 'yayinda')
          .neq('id', haber.id)
          .order('olusturuldu', ascending: false)
          .limit(adet);
      for (final j in (y as List)) {
        final h = Haber.jsondan(j as Map<String, dynamic>);
        toplanan[h.id] = h;
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

// NOT: İlgili haberler için sağlayıcı YOK — bilerek.
//
// `FutureProvider.autoDispose.family` ile denendi ve bölüm ekranda
// sonsuza kadar "yükleniyor"da kaldı; izleme çıktıları depo metodunun
// HİÇ çağrılmadığını gösterdi. Tek seferlik, tek kullanıcısı olan bir
// getirme için sağlayıcı zaten gereksiz katman. Ekran doğrudan
// `FutureBuilder` kullanıyor.
