/// Görsel adreslerini boyutlandırma hizmetine çeviren yardımcı.
///
/// Neden var
/// ─────────
/// Ölçüm: masaüstünde ilk açılışta 1,67 MB fotoğraf iniyordu; en büyüğü tek
/// başına 293 KB ve akıştaki 104×76'lık küçük görsel için kullanılıyordu.
/// Hattın ürettiği dosya 1200×630; akışın ihtiyacı onun otuzda biri.
///
/// Boyutlandırmayı Supabase'in kendi uç noktası yapamıyor — bu projenin
/// planında kapalı. Yerine `functions/gorsel.js` kondu; burası onun
/// istemci tarafı.
library;

/// Boyutlandırma hizmetinin taban yolu.
///
/// `--dart-define=GORSEL_TABANI=/gorsel` ile veriliyor (bkz. `yayinla.sh`).
///
/// Boş bırakılırsa özgün adres kullanılıyor ve bu YERELDE İSTENEN DAVRANIŞ:
/// `flutter run` ile çalışırken Hosting yönlendirmesi yok, dolayısıyla
/// fonksiyon da yok. Anahtarın verilmediği durumda uygulamayı fotoğrafsız
/// bırakmak yerine özgün dosyaya düşmek doğrusu.
const _tabanVarsayilan = String.fromEnvironment('GORSEL_TABANI');

/// Hizmetin kabul ettiği genişlikler, küçükten büyüğe.
///
/// `functions/gorsel.js` içindeki liste ile AYNI olmak zorunda: orada
/// olmayan bir genişlik 404 dönüyor. Üç kademe bilerek az tutuldu — her
/// genişlik CDN'de ayrı bir önbellek girdisi demek.
const _genislikler = [320, 640, 1200];

/// Mantıksal genişliğe yetecek en küçük kademe.
///
/// Ekran yoğunluğu için ikiyle çarpılıyor: 104 piksellik bir küçük görsel
/// Retina'da 208 gerçek piksel istiyor. Üçe katlayan ekranlarda bir miktar
/// yumuşama oluyor; bunun bedeli, her kademeyi üçe katlayıp herkese üç kat
/// veri indirtmekten düşük.
int kademe(int mantiksalGenislik) {
  final istenen = mantiksalGenislik * 2;
  for (final g in _genislikler) {
    if (g >= istenen) return g;
  }
  return _genislikler.last;
}

/// Özgün adresi boyutlandırılmış adrese çevirir.
///
/// Çeviremediği her durumda — taban verilmemiş, adres boş, dosya adı
/// beklenen kalıpta değil — ÖZGÜN ADRESİ döndürüyor. Bu işlevin bir
/// görselin hiç görünmemesine yol açması mümkün değil.
///
/// [taban] yalnızca test için; verilmezse derleme anındaki değer geçerli.
String? gorselAdresi(
  String? adres, {
  required int mantiksalGenislik,
  String taban = _tabanVarsayilan,
}) {
  if (adres == null || adres.isEmpty) return adres;
  if (taban.isEmpty) return adres;

  final dosya = Uri.tryParse(adres)?.pathSegments.lastOrNull;
  if (dosya == null || dosya.isEmpty) return adres;
  // Fonksiyondaki kalıbın aynısı: uymayan bir ad zaten 404 dönerdi.
  if (!RegExp(r'^[A-Za-z0-9._-]+\.(jpe?g|png|webp)$', caseSensitive: false)
      .hasMatch(dosya)) {
    return adres;
  }

  return '$taban/${kademe(mantiksalGenislik)}/$dosya';
}
