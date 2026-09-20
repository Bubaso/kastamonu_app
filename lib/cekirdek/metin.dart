/// Türkçe metin işlemleri.
///
/// Neden ayrı bir dosya
/// ────────────────────
/// Dart'ın `toUpperCase()` metodu Unicode'un dilden bağımsız kuralını
/// uyguluyor: `"i"` → `"I"`. Türkçede doğrusu `"İ"`. Portalda bütün bölüm
/// etiketleri versal yazıldığı için bu, ekranda doğrudan görünen bir hata
/// üretiyordu:
///
///     "Eğitim".toUpperCase()        → "EĞITIM"     (yanlış)
///     "Kaza ve Acil".toUpperCase()  → "KAZA VE ACIL" (yanlış)
///     "Ekonomi".toUpperCase()       → "EKONOMI"    (yanlış)
///
/// Aynı tuzağın küçültme yönüne hat tarafında düşülmüştü: `"İ".lower()`
/// Python'da tek bir "i" değil, "i" + birleşik nokta üretiyor ve yayın
/// süzgecini sessizce bozmuştu. Bu dosya arayüz tarafındaki karşılığı.
library;

/// Türkçeye uygun büyütme.
///
/// `i` → `İ` ve `ı` → `I` eşlemeleri önce yapılıyor; gerisini standart
/// büyütme hallediyor (ğ→Ğ, ş→Ş, ç→Ç, ö→Ö, ü→Ü zaten doğru çalışıyor).
String buyult(String metin) => metin
    .replaceAll('i', 'İ')
    .replaceAll('ı', 'I')
    .toUpperCase();

/// Türkçeye uygun küçültme. Şu an arayüzde kullanılmıyor ama karşılığı
/// burada dursun ki ihtiyaç olduğunda `toLowerCase()` yazılmasın.
String kucult(String metin) => metin
    .replaceAll('I', 'ı')
    .replaceAll('İ', 'i')
    .toLowerCase();
