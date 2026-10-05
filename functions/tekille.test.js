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

// ── Hattın ikinci tekilleştirme katmanı ─────────────────────────
//
// `varMi` adres eşitliğine bakıyor; aynı olay BAŞKA bir yayından,
// başka adresle geldiğinde geçiyor. Ölçümde tam bu oldu: yayındaki
// "Cide'de balık tutarken kalp krizi geçiren kişi hayatını kaybetti"
// dururken hat "Cide'de denizde kalp krizi geçiren balıkçı hayatını
// kaybetti" diye ikinci bir kayıt üretti. İkisi de okura görünüyordu.
//
// `ayniOlay` o çifti yakalıyor; hat da yazmadan önce aynı ölçütü
// kullanıyor (bkz. functions/index.js). Buradaki testler ölçütün o
// gerçek çifti tuttuğunu ve ayrı olayları ayırmayı sürdürdüğünü
// kilitliyor.

const anAn = (saatOnce = 0) =>
  new Date(Date.now() - saatOnce * 36e5).toISOString();

const kayit = (baslik, { kategori = "Kaza ve Acil", ilce = "Cide", saat = 0, id = Math.random().toString(36).slice(2) } = {}) => ({
  id,
  baslik,
  olusturuldu: anAn(saat),
  kategoriler: { ad: kategori },
  haber_ilce: ilce ? [{ onaylandi: true, ilceler: { ad: ilce } }] : [],
});

test("ayniOlay: aynı olayın iki ayrı sentezi yakalanıyor", () => {
  // Gerçek çift, canlı veritabanından.
  const a = kayit("Cide'de balık tutarken kalp krizi geçiren kişi hayatını kaybetti");
  const b = kayit("Cide'de denizde kalp krizi geçiren balıkçı hayatını kaybetti", { saat: 3 });
  assert.equal(ayniOlay(a, b), true,
    `benzerlik ${benzerlik(a.baslik, b.baslik).toFixed(2)} eşiğin altında kaldı`);
});

test("ayniOlay: aynı ilçedeki AYRI olaylar ayrı kalıyor", () => {
  // Aynı ilçe, aynı bölüm, aynı gün — ama farklı olay. Eşik bunları
  // birleştirirse portal haber kaybeder.
  const a = kayit("Cide'de balık tutarken kalp krizi geçiren kişi hayatını kaybetti");
  const b = kayit("Cide'de mantardan zehirlenen dört kişilik aile hastaneye kaldırıldı", { saat: 2 });
  assert.equal(ayniOlay(a, b), false);
});

test("ayniOlay: farklı ilçedeki benzer olay ayrı kalıyor", () => {
  const a = kayit("Taşköprü'de çıkan yangında samanlık kullanılamaz hale geldi", { ilce: "Taşköprü" });
  const b = kayit("Daday'da çıkan yangında samanlık kullanılamaz hale geldi", { ilce: "Daday" });
  assert.equal(ayniOlay(a, b), false);
});

test("ayniOlay: yedi günden eski kayıt engel değil", () => {
  const a = kayit("Cide'de balık tutarken kalp krizi geçiren kişi hayatını kaybetti");
  const b = kayit("Cide'de denizde kalp krizi geçiren balıkçı hayatını kaybetti", { saat: 24 * 9 });
  assert.equal(ayniOlay(a, b), false, "pencere dışındaki kayıt yeni habere engel olmamalı");
});

test("ayniOlay: kalıplı başlıklı AYRI olaylar birleşmiyor", () => {
  // Eşiğin neden 0,40'ın altına inmediğinin gerekçesi. Türkçe haber
  // dili kalıplı: "son yolculuğuna uğurlanacak" tek başına benzerlik
  // üretiyor. Canlı veride bu çift 0,30 ölçüldü ve AYRI iki cenaze.
  const a = kayit("Pakize Dikoğlu son yolculuğuna uğurlanacak", { kategori: "Gündem", ilce: null });
  const b = kayit("İş yerinde ölü bulunan Dilruba Arslan son yolculuğuna uğurlanacak", { kategori: "Gündem", ilce: null, saat: 5 });
  assert.ok(benzerlik(a.baslik, b.baslik) < 0.40,
    `benzerlik ${benzerlik(a.baslik, b.baslik).toFixed(2)} — eşik bunu birleştirmemeli`);
  assert.equal(ayniOlay(a, b), false, "iki ayrı cenaze tek habere indirgenemez");
});

test("ayniOlay: kurt ve maç çiftleri de yakalanıyor", () => {
  // Canlı veride ölçülen diğer iki gerçek tekrar; eski eşik (0,62)
  // ikisini de kaçırıyordu.
  const kurt1 = kayit("Kastamonu Hacımuharrem köyünde ahıra giren kurtlar 18 koyunu telef etti", { kategori: "Tarım", ilce: null });
  const kurt2 = kayit("Kastamonu'da ağıla saldıran kurtlar 18 koyunu telef etti", { kategori: "Tarım", ilce: null, saat: 4 });
  assert.equal(ayniOlay(kurt1, kurt2), true,
    `benzerlik ${benzerlik(kurt1.baslik, kurt2.baslik).toFixed(2)}`);

  const mac1 = kayit("GMG Kastamonuspor, evinde Arnavutköy Belediyesi'ni 2-1 mağlup etti", { kategori: "Spor", ilce: null });
  const mac2 = kayit("GMG Kastamonuspor evinde Arnavutköy Belediyespor'u 2-1 yendi", { kategori: "Spor", ilce: null, saat: 6 });
  assert.equal(ayniOlay(mac1, mac2), true,
    `benzerlik ${benzerlik(mac1.baslik, mac2.baslik).toFixed(2)}`);
});

test("ayniOlay: ilçe bağı seyrek olduğunda asimetri kurala ters tepiyor", () => {
  // Hattın yazmadan önceki denetiminde çıkan GERÇEK hata. `ayniOlay`
  // ilçeyi `haber_ilce` bağından okuyor; o bağ ayrı bir süreçle
  // doluyor ve seyrek (ölçümde 81 kaydın 18'i). Adaya başlıktan ilçe
  // türetip kayıtlıya bağından bakmak karşılaştırmayı asimetrik
  // yapıyor: başlıklar BİREBİR aynıyken bile kural false döndü ve
  // haber ikinci kez yazılmaya kalktı.
  //
  // Bu test o asimetriyi belgeliyor — `functions/index.js` ilçeyi iki
  // tarafta da METİNDEN türettiği için oradaki çağrı doğru çalışıyor.
  const baslik = "Cide'de balık tutarken kalp krizi geçiren kişi hayatını kaybetti";
  const kayitli = kayit(baslik, { ilce: null });       // bağ yok
  const aday = kayit(baslik, { ilce: "Cide", saat: 1 }); // bağ var

  assert.equal(benzerlik(aday.baslik, kayitli.baslik), 1);
  assert.equal(ayniOlay(aday, kayitli), false,
    "asimetrik ilçe kümesi kuralı düşürüyor — bu yüzden çağıran iki tarafı da metinden türetmeli");

  // İki taraf da aynı biçimde türetilince kural doğru çalışıyor.
  const adayB = kayit(baslik, { ilce: "Cide", saat: 1 });
  const kayitliB = kayit(baslik, { ilce: "Cide" });
  assert.equal(ayniOlay(adayB, kayitliB), true);
});
