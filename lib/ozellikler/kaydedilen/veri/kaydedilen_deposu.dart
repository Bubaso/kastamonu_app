import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/tercihler.dart';
import '../../anasayfa/veri/anasayfa_deposu.dart';
import '../../inceleme/model/haber.dart';

/// Kaydedilen haberler, okurun kaydetme sırasıyla.
///
/// Sıralama yayın tarihine göre DEĞİL: okur en son neyi kaydettiyse o
/// başta duruyor. "Sonra okurum" dediği şeyi ararken beklediği sıra bu.
///
/// Slug'ı yayından kalkmış bir kayıt listeden sessizce düşüyor —
/// `whereType` onu eliyor. Okura "bu haber artık yok" demek yerine
/// göstermemeyi seçiyoruz; kaydedilen haber sayısı zaten alt çubukta
/// güncelleniyor.
final kaydedilenHaberlerSaglayici = Provider<AsyncValue<List<Haber>>>((ref) {
  final sluglar = ref.watch(kaydedilenlerSaglayici);
  return ref.watch(tumYayindakilerSaglayici).whenData((liste) {
    final dizin = {for (final h in liste) h.slug: h};
    return sluglar.map((s) => dizin[s]).whereType<Haber>().toList();
  });
});
