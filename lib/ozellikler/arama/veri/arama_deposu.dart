import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/metin.dart';
import '../../anasayfa/veri/anasayfa_deposu.dart';
import '../../inceleme/model/haber.dart';

/// Arama — yayındaki listeden bellekte.
///
/// Neden sunucuda değil
/// ────────────────────
/// Portal ölçeğinde yayındaki toplam kayıt birkaç yüz ve liste zaten
/// açılışta bir kez indiriliyor. Postgres tam metin araması kurmak hem
/// göç hem indeks hem de her tuş vuruşunda bir istek demek; aynı sonucu
/// sıfır gecikmeyle bellekte almak mümkünken bunun karşılığı yok.
///
/// Sınır açık: arşiv büyüyüp liste sınırını (200) aşarsa arama yalnızca
/// o pencereyi görür. O noktada taşınacak yer sunucu.

/// Bir haberin sorguya uygunluk puanı. 0 = eşleşme yok.
///
/// Kelimeler VE ile bağlı: "tosya kaza" yazan okur ikisini birden içeren
/// haberi arıyor, birini içeren otuz haberi değil.
///
/// Ağırlıklar nerede geçtiğine göre. Başlıkta geçen kelime haberin
/// konusu; gövdede geçen kelime çoğu zaman yan bir ayrıntı.
int aramaPuani(Haber h, List<String> kelimeler) {
  if (kelimeler.isEmpty) return 0;

  final baslik = sadelestir(h.baslik);
  final spot = sadelestir(h.spot ?? '');
  final govde = sadelestir(h.govde ?? '');
  final kategori = sadelestir(h.kategoriAd ?? '');
  final ilce = sadelestir(
    h.ilceler.where((b) => b.onaylandi).map((b) => b.ad).join(' '),
  );

  var toplam = 0;
  for (final k in kelimeler) {
    if (baslik.contains(k)) {
      toplam += 8;
    } else if (ilce.contains(k) || kategori.contains(k)) {
      // Yerel portalda yer adı başlık kadar güçlü bir arama ölçütü.
      toplam += 5;
    } else if (spot.contains(k)) {
      toplam += 3;
    } else if (govde.contains(k)) {
      toplam += 1;
    } else {
      // Kelimelerden biri hiçbir yerde yoksa haber sonuç değil.
      return 0;
    }
  }
  return toplam;
}

/// Sorguyu kelimelere ayırır. Tek harflik parçalar atılıyor: "a", "ve"
/// gibi şeyler her habere uyup sıralamayı bozuyor.
List<String> aramaKelimeleri(String sorgu) => sadelestir(sorgu)
    .split(RegExp(r'[^a-z0-9]+'))
    .where((k) => k.length > 1)
    .toList();

/// Sorguya uyan haberler, uygunluk sonra tazelik sırasıyla.
List<Haber> aramaSonuclari(List<Haber> tumu, String sorgu) {
  final kelimeler = aramaKelimeleri(sorgu);
  if (kelimeler.isEmpty) return const [];

  final puanli = <({Haber haber, int puan})>[];
  for (final h in tumu) {
    final p = aramaPuani(h, kelimeler);
    if (p > 0) puanli.add((haber: h, puan: p));
  }
  puanli.sort((a, b) {
    final f = b.puan.compareTo(a.puan);
    return f != 0 ? f : b.haber.zaman.compareTo(a.haber.zaman);
  });
  return puanli.map((e) => e.haber).toList();
}

/// Arama kutusundaki metin.
class AramaSorgusu extends Notifier<String> {
  @override
  String build() => '';
  void yaz(String s) => state = s;
}

final aramaSorgusuSaglayici =
    NotifierProvider<AramaSorgusu, String>(AramaSorgusu.new);

final aramaSonuclariSaglayici = Provider<List<Haber>>((ref) {
  final sorgu = ref.watch(aramaSorgusuSaglayici);
  final liste = ref.watch(tumYayindakilerSaglayici).asData?.value;
  if (liste == null) return const [];
  return aramaSonuclari(liste, sorgu);
});
