import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/supabase.dart';
import '../../inceleme/model/haber.dart';

class HaberDeposu {
  static const _secim = '''
    id, slug, baslik, spot, govde, kaynak_adi, kaynak_url, yayinci,
    katman, onem, diaspora, durum, olusturuldu, gorsel_url,
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
}

// NOT: `ilgililer()` metodu KALDIRILDI.
//
// Detay sayfasının alt şeridi artık kendi sorgusunu atmıyor; ana sayfanın
// da kullandığı paylaşılan listeden bellekte süzülüyor
// (`tumYayindakilerSaglayici`). Eski sürümde buradaki sorgu hiç
// tamamlanmıyordu — Riverpod family, iç içe sağlayıcı, FutureBuilder ve
// State alanı olmak üzere dört farklı kurgu denendi, hiçbiri değiştirmedi;
// aynı REST çağrısı tarayıcı konsolundan 455 ms'de sorunsuz dönüyordu.
// Zaten yüklü listeyi kullanmak sorunu atlıyor ve fazladan istek de
// doğurmuyor.

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
