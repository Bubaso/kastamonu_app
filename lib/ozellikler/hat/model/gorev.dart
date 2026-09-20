/// Haber hattı koşusu.
class Gorev {
  final String id;
  final String durum;
  final int sinir;
  final DateTime istendi;
  final DateTime? basladi;
  final DateTime? bitti;
  final int? islenen;
  final int? onaylanan;
  final int? elenen;
  final String? gunluk;

  const Gorev({
    required this.id,
    required this.durum,
    required this.sinir,
    required this.istendi,
    this.basladi,
    this.bitti,
    this.islenen,
    this.onaylanan,
    this.elenen,
    this.gunluk,
  });

  bool get surmekte => durum == 'bekliyor' || durum == 'calisiyor';

  String get durumEtiketi => switch (durum) {
    'bekliyor' => 'sırada',
    'calisiyor' => 'çalışıyor',
    'bitti' => 'bitti',
    'hata' => 'hata',
    _ => durum,
  };

  factory Gorev.jsondan(Map<String, dynamic> j) => Gorev(
    id: j['id'] as String,
    durum: j['durum'] as String? ?? 'bekliyor',
    sinir: (j['sinir'] as num?)?.toInt() ?? 20,
    istendi:
        DateTime.tryParse(j['istendi'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    basladi: DateTime.tryParse(j['basladi'] as String? ?? '')?.toLocal(),
    bitti: DateTime.tryParse(j['bitti'] as String? ?? '')?.toLocal(),
    islenen: (j['islenen'] as num?)?.toInt(),
    onaylanan: (j['onaylanan'] as num?)?.toInt(),
    elenen: (j['elenen'] as num?)?.toInt(),
    gunluk: j['gunluk'] as String?,
  );
}
