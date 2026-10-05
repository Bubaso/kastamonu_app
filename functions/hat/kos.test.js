import assert from "node:assert/strict";
import { test } from "node:test";

import {
  DenetimHatasi, ayniOlayHam, dogrula, durum, ilceBul, kos, kumele,
} from "./kos.js";

const T = (saat) => new Date(Date.parse("2026-10-05T08:00:00Z") + saat * 36e5).toISOString();
const k = (baslik, o = {}) => ({
  baslik, ozet: o.ozet ?? "", adres: o.adres ?? "",
  // Görsel varsayılan olarak dolu: görselsizlik ayrı bir testin konusu.
  gorsel: o.gorsel ?? "https://foto.example/x.jpg",
  kaynak_adi: o.kaynak ?? "A", olusturuldu: T(o.saat ?? 0),
});

test("ilçe adı başlıktan bulunuyor, ekli biçimlerle", () => {
  assert.deepEqual([...ilceBul("Taşköprü'de yangın")], ["Taşköprü"]);
  assert.deepEqual([...ilceBul("TOSYA'DA KAZA")], ["Tosya"]);
  assert.equal(ilceBul("Kastamonu'da tören").size, 0);
});

test("aynı olay birleşiyor", () => {
  const a = k("Kastamonu'da otobüsün çarptığı yaya hayatını kaybetti", { kaynak: "A" });
  const b = k("Kastamonu'da otobüsün çarptığı yaya hayatını kaybetti", { kaynak: "B", saat: 2 });
  assert.ok(ayniOlayHam(a, b));
  assert.equal(kumele([a, b]).length, 1);
});

test("ayrı ilçeler birleşmiyor", () => {
  const a = k("Tosya'da tören düzenlendi ve çelenk sunuldu", { saat: 0 });
  const b = k("Daday'da tören düzenlendi ve çelenk sunuldu", { saat: 1 });
  assert.ok(!ayniOlayHam(a, b));
});

test("48 saatten uzak birleşmiyor", () => {
  const a = k("Tosya'da samanlık yangını söndürüldü");
  const b = k("Tosya'da samanlık yangını söndürüldü", { saat: 60 });
  assert.ok(!ayniOlayHam(a, b));
});

// ── Uydurma denetimi ─────────────────────────────────────────────

const olay = {
  capa: k("Kastamonu'da otobüsün çarptığı yaya hayatını kaybetti"),
  uyeler: [
    k("Kastamonu'da otobüsün çarptığı yaya hayatını kaybetti",
      { kaynak: "İhlas", ozet: "Kastamonu'da halk otobüsünün çarptığı yaya kaldırıldığı hastanede yaşamını yitirdi." }),
  ],
};
const iyi = (f) => ({
  baslik: "Kastamonu'da yaya hayatını kaybetti",
  spot: "Otobüsün çarptığı yaya kurtarılamadı.",
  govde: "Kastamonu'da bir yaya, halk otobüsünün çarpması sonucu ağır yaralandı ve hastanede yaşamını yitirdi.",
  kullanilan_kaynaklar: ["İhlas"],
  ...f,
});

test("kaynakta geçmeyen sayı reddediliyor", () => {
  // Ölçümde yakalanan gerçek hata: model plaka ve yaş uydurmuştu.
  assert.throws(
    () => dogrula(iyi({
      govde: "37 M 0134 plakalı otobüs, 70 yaşındaki yayaya çarptı.",
    }), olay),
    (e) => e instanceof DenetimHatasi && /geçmeyen sayı/.test(e.message));
});

test("kaynakta geçen sayı kabul ediliyor", () => {
  const o = { ...olay, uyeler: [{ ...olay.uyeler[0], ozet: olay.uyeler[0].ozet + " 70 yaşındaki yaya." }] };
  dogrula(iyi({ govde: "Yaya 70 yaşındaydı ve hastanede yaşamını yitirdi." }), o);
});

test("sayısız metin geçiyor", () => { dogrula(iyi(), olay); });

test("uydurulmuş kaynak reddediliyor", () => {
  assert.throws(() => dogrula(iyi({ kullanilan_kaynaklar: ["Hürriyet"] }), olay), DenetimHatasi);
});

test("boş gövde reddediliyor", () => {
  assert.throws(() => dogrula(iyi({ govde: "  " }), olay), DenetimHatasi);
});

test("çelişki varsa editöre düşüyor", () => {
  assert.equal(durum({ celiskiler: [{ konu: "yaş", degerler: [] }] }), "celiskili");
  assert.equal(durum({}), "yazildi");
});

// ── Metinsiz küme modele hiç gitmiyor ────────────────────────────

test("metinsiz küme modele gönderilmiyor", async () => {
  let cagrildi = 0;
  const sonuc = await kos({
    tara: async () => ({
      kayitlar: [
        k("Kastamonu'da otobüsün çarptığı yaya hayatını kaybetti", { kaynak: "A" }),
        k("Kastamonu'da otobüsün çarptığı yaya hayatını kaybetti", { kaynak: "B", saat: 1 }),
      ],
      hatalar: [],
    }),
    cagir: async () => { cagrildi++; return iyi(); },
  });
  assert.equal(cagrildi, 0, "özeti olmayan küme modele gitmemeli");
  assert.equal(sonuc.atlanan[0].sebep, "kaynak metni yok");
});

test("metinli küme modele gidiyor", async () => {
  let cagrildi = 0;
  const sonuc = await kos({
    tara: async () => ({ kayitlar: [olay.uyeler[0]], hatalar: [] }),
    cagir: async () => { cagrildi++; return iyi(); },
  });
  assert.equal(cagrildi, 1);
  assert.equal(sonuc.yazilan.length, 1);
});

test("bir olay düşse koşu devam ediyor", async () => {
  const sonuc = await kos({
    tara: async () => ({
      kayitlar: [
        olay.uyeler[0],
        { ...olay.uyeler[0], baslik: "Tosya'da sel suları tarım arazilerine zarar verdi",
          ozet: "Tosya'da sağanak sonrası sel suları tarım arazilerini bastı.", kaynak_adi: "B" },
      ],
      hatalar: [],
    }),
    cagir: async (o) => {
      if (/Tosya/.test(o.capa.baslik)) throw new Error("model hatası");
      return iyi();
    },
  });
  assert.equal(sonuc.yazilan.length, 1);
  assert.equal(sonuc.atlanan.length, 1);
});

test("künyeye adres yazılırsa yayın adına çevriliyor", async () => {
  // Ölçümde model künyeye adres yazdı ve geçerli haberler reddedildi.
  const { kunyeyiDuzelt } = await import("./kos.js");
  const o = {
    capa: k("x"),
    uyeler: [k("x", { kaynak: "Haberler.com / Kastamonu", adres: "https://h.com/a" })],
  };
  const d = kunyeyiDuzelt({ kullanilan_kaynaklar: ["https://h.com/a"] }, o);
  assert.deepEqual(d.kullanilan_kaynaklar, ["Haberler.com / Kastamonu"]);
});

test("çevrilemeyen künye olduğu gibi kalıyor ve reddediliyor", async () => {
  const { kunyeyiDuzelt } = await import("./kos.js");
  const d = kunyeyiDuzelt({ kullanilan_kaynaklar: ["Hürriyet"] }, olay);
  assert.deepEqual(d.kullanilan_kaynaklar, ["Hürriyet"]);
  assert.throws(() => dogrula({ ...iyi(), ...d }, olay), DenetimHatasi);
});


test("görselsiz küme modele gönderilmiyor", async () => {
  // "Görselsiz haber kesinlikle olmayacak" bir ürün kararı; kural
  // kodda, umutta değil.
  let cagrildi = 0;
  const sonuc = await kos({
    tara: async () => ({ kayitlar: [{ ...olay.uyeler[0], gorsel: "" }], hatalar: [] }),
    cagir: async () => { cagrildi++; return iyi(); },
  });
  assert.equal(cagrildi, 0);
  assert.equal(sonuc.atlanan[0].sebep, "görsel yok");
});

test("kümede tek üyenin görseli varsa yetiyor", async () => {
  const sonuc = await kos({
    tara: async () => ({
      kayitlar: [
        { ...olay.uyeler[0], gorsel: "" },
        { ...olay.uyeler[0], kaynak_adi: "B", gorsel: "https://foto.example/y.jpg",
          olusturuldu: T(1) },
      ],
      hatalar: [],
    }),
    cagir: async () => iyi({ kullanilan_kaynaklar: ["İhlas"] }),
  });
  assert.equal(sonuc.yazilan.length, 1);
});
