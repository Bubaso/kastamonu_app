import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/supabase.dart';
import '../model/gorev.dart';

/// Hat tetikleme kuyruğu.
///
/// Panel hattı doğrudan çağıramıyor (biri Flutter Web'de, öbürü Python'da);
/// araya `hat_gorevleri` kuyruğu giriyor. Panel satır yazıyor, yerel işçi
/// görüp koşuyor ve aynı satıra sonucu yazıyor.
class HatDeposu {
  Future<List<Gorev>> gecmis({int adet = 8}) async {
    final y = await sb
        .from('hat_gorevleri')
        .select()
        .order('istendi', ascending: false)
        .limit(adet);
    return (y as List)
        .map((j) => Gorev.jsondan(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> tetikle({int sinir = 20}) async {
    await sb.from('hat_gorevleri').insert({
      'sinir': sinir,
      'isteyen': sb.auth.currentUser?.id,
    });
  }
}

final hatDeposuSaglayici = Provider((_) => HatDeposu());

final gorevGecmisiSaglayici = FutureProvider.autoDispose<List<Gorev>>((
  ref,
) async {
  return ref.watch(hatDeposuSaglayici).gecmis();
});
