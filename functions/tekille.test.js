import assert from "node:assert/strict";
import { test } from "node:test";

import { ayniOlay, benzerlik, sadelestir, tekille } from "./tekille.js";

const T0 = Date.parse("2026-09-20T10:00:00Z");

function k(id, baslik, o = {}) {
  return {
    id, baslik,
    olusturuldu: new Date(T0 + (o.saat ?? 0) * 36e5 + (o.gun ?? 0) * 864e5)
      .toISOString(),
    kategoriler: { ad: o.kategori ?? "Kaza ve Acil" },
    haber_ilce: (o.ilceler ?? []).map((ad) => ({ onaylandi: true, ilceler: { ad } })),
    govde: o.govde ?? "",
    gorsel_url: o.fotograf === false ? null : "x",
    gorsel_kaynak: o.fotograf === false ? null : "y",
  };
}

test("Türkçe sadeleştirme Dart tablosuyla aynı", () => {
  // "ı" ayrışmayan bir harf; eşleme tablosu onu da kapsamalı.
  assert.equal(sadelestir("Taşköprü'de YANGIN"), "taskopru'de yangin");
  assert.equal(sadelestir("Ilgaz"), "ilgaz");
  assert.equal(sadelestir("İnebolu"), "inebolu");
});

test("ölçülen gerçek çift birleşiyor", () => {
  const a = k("1", "Daday'ın Bolatlar köyünde çıkan yangında samanlık " +
                   "kullanılamaz hale geldi", { ilceler: ["Daday"] });
  const b = k("2", "Daday'ın Bolatlar köyünde çıkan yangında Yaşar Mıcık'a " +
                   "ait samanlık kullanılamaz hale geldi",
              { ilceler: ["Daday"], saat: 20 });
  // Ölçülen değer 0,75. Dart, Python ve bu dosya aynı sonucu vermeli.
  assert.equal(benzerlik(a.baslik, b.baslik).toFixed(2), "0.75");
  assert.ok(ayniOlay(a, b));
  assert.equal(tekille([a, b]).length, 1);
});

test("kalan kayıt sahibin adını yazan olur", () => {
  const kisa = k("1", "Daday'ın Bolatlar köyünde çıkan yangında samanlık " +
                      "kullanılamaz hale geldi", { ilceler: ["Daday"] });
  const uzun = k("2", "Daday'ın Bolatlar köyünde çıkan yangında Yaşar Mıcık'a " +
                      "ait samanlık kullanılamaz hale geldi",
                 { ilceler: ["Daday"], saat: 20 });
  assert.equal(tekille([kisa, uzun])[0].id, "2");
});

test("ayrı ilçeler birleşmiyor", () => {
  // Ortak kelimelerin hepsi vesileye ait; ayıran şey yer.
  const a = k("1", "Kastamonu'da 19 Eylül Gaziler Günü düzenlenen yürüyüş ve " +
                   "törenlerle kutlandı", { kategori: "Gündem" });
  const b = k("2", "Tosya, Taşköprü ve Ağlı'da 19 Eylül Gaziler Günü " +
                   "törenlerle kutlandı",
              { kategori: "Gündem", ilceler: ["Tosya", "Ağlı"] });
  assert.ok(!ayniOlay(a, b));
  assert.equal(tekille([a, b]).length, 2);
});

test("farklı bölüm ailesi birleşmiyor", () => {
  const a = k("1", "Tosya'da büyük yangın çıktı", { ilceler: ["Tosya"] });
  const b = k("2", "Tosya'da büyük yangın çıktı",
              { ilceler: ["Tosya"], kategori: "Spor" });
  assert.ok(!ayniOlay(a, b));
});

test("pencere dışı birleşmiyor", () => {
  const a = k("1", "Tosya'da samanlık yangını söndürüldü", { ilceler: ["Tosya"] });
  const b = k("2", "Tosya'da samanlık yangını söndürüldü",
              { ilceler: ["Tosya"], gun: 9 });
  assert.ok(!ayniOlay(a, b));
});

test("fotoğraflı kayıt tutuluyor", () => {
  const fotosuz = k("1", "Tosya'da yangın çıktı ve samanlık yandı",
                    { ilceler: ["Tosya"], fotograf: false, govde: "x".repeat(900) });
  const fotoli = k("2", "Tosya'da yangın çıktı ve samanlık yandı",
                   { ilceler: ["Tosya"], saat: 1 });
  assert.equal(tekille([fotosuz, fotoli])[0].id, "2");
});

test("gelen sıra korunuyor", () => {
  const a = k("1", "Tosya'da trafik kazası oldu", { ilceler: ["Tosya"] });
  const b = k("2", "Araç'ta sel sularından zarar görüldü", { ilceler: ["Araç"] });
  const c = k("3", "Cide'de balıkçılar denize açıldı", { ilceler: ["Cide"] });
  assert.deepEqual(tekille([a, b, c]).map((h) => h.id), ["1", "2", "3"]);
});

test("boş ve tek elemanlı liste güvenli", () => {
  assert.deepEqual(tekille([]), []);
  assert.deepEqual(tekille(undefined), []);
  assert.equal(tekille([k("1", "tek")]).length, 1);
});

test("eksik alanlar çökertmiyor", () => {
  const a = { id: "1", baslik: "Tosya'da yangın", olusturuldu: "2026-09-20" };
  const b = { id: "2", baslik: "Tosya'da yangın", olusturuldu: "2026-09-20" };
  assert.doesNotThrow(() => tekille([a, b]));
});
