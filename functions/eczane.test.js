import assert from "node:assert/strict";
import { test } from "node:test";

import { bicimle, bugun, eczaneCek, tarihCevir } from "./eczane.js";

/** Odanın sayfasının birebir biçimli, kısaltılmış hâli. */
const kart = (ad, ilce, adres, tel, konum = "41.385459,33.783699") => `
<div class="col-md-12 nobetci">
  <div class="col-md-2 top-1"><img src="images/epano.gif" alt="${ad}" /></div>
  <div class=" col-md-10">
    <h4 class="tred"><strong>${ad}</strong> - ${ilce}</h4>
    <p> <i class='fa fa-home main-color'></i> ${adres}
      <br><i class='fa fa-phone main-color'></i> <a href="tel:${tel}">${tel}</a>
      <br /> <i class="fa fa-map-marker main-color"></i>
      <a href="https://maps.google.com/maps?q=${konum}" target="_blank">Haritada</a><br>
    </p>
  </div>
  <hr>
</div>
</div>`;

const sayfa = (tarih, kartlar) => `<html><body>
<h3 class="main-color">ECZANE REHBERİ</h3>
<h3 class="main-color">${tarih} Kastamonu Bugün Nöbetçi Eczaneler</h3><hr/>
${kartlar.join("\n")}
<footer>son</footer></body></html>`;

const TAM = sayfa("05 Ekim 2026", [
  kart("DOĞA ECZANESİ", "MERKEZ", "ESKİ FİZİK TEDAVİ HASTANESİ KARŞISI", "03662142303"),
  kart("ABANA ECZANESİ", "ABANA", "MERKEZ MAHALLESI CUMHURIYET MEYDANI NO:17",
    "03665642030", "41.978558,34.007966"),
]);

test("tarihCevir: Türkçe ay adı ISO'ya dönüyor", () => {
  assert.equal(tarihCevir("05 Ekim 2026 Kastamonu Bugün Nöbetçi Eczaneler"), "2026-10-05");
  assert.equal(tarihCevir("1 Ocak 2027"), "2027-01-01");
  assert.equal(tarihCevir("31 Aralık 2026"), "2026-12-31");
});

test("tarihCevir: olmayan gün ve tanınmayan ay null", () => {
  assert.equal(tarihCevir("31 Şubat 2026"), null);
  assert.equal(tarihCevir("05 Foobar 2026"), null);
  assert.equal(tarihCevir("nöbetçi eczaneler"), null);
  assert.equal(tarihCevir(null), null);
});

test("bicimle: bugünün listesi eksiksiz çıkıyor", () => {
  const d = bicimle(TAM, { bugunTarih: "2026-10-05" });
  assert.equal(d.guncel, true);
  assert.equal(d.tarih, "2026-10-05");
  assert.equal(d.eczaneler.length, 2);
  const [a, b] = d.eczaneler;
  assert.equal(a.ad, "DOĞA ECZANESİ");
  assert.equal(a.ilce, "MERKEZ");
  assert.equal(a.telefon, "03662142303");
  assert.match(a.adres, /ESKİ FİZİK TEDAVİ/);
  assert.equal(a.enlem, 41.385459);
  assert.equal(b.ilce, "ABANA");
  assert.equal(b.boylam, 34.007966);
});

test("bicimle: SAYFA DÜNÜ GÖSTERİYORSA liste boş", () => {
  // En önemli kural. Oda sayfayı güncellemeyi unutursa dünün
  // nöbetçisini göstermek, insanı gece kapalı eczaneye gönderir.
  const d = bicimle(TAM, { bugunTarih: "2026-10-06" });
  assert.equal(d.guncel, false);
  assert.deepEqual(d.eczaneler, []);
  assert.equal(d.tarih, "2026-10-05", "tarih yine bildirilmeli");
});

test("bicimle: tarih başlığı yoksa liste boş", () => {
  const d = bicimle(`<html><body>${kart("X ECZANESİ", "MERKEZ", "ADRES", "0366")}</body></html>`);
  assert.equal(d.guncel, false);
  assert.equal(d.tarih, null);
  assert.deepEqual(d.eczaneler, []);
});

test("bicimle: sayfa düzeni değişirse yanlış veri değil BOŞ dönüyor", () => {
  const d = bicimle("<html><body><h1>bambaşka bir sayfa</h1></body></html>");
  assert.equal(d.guncel, false);
  assert.deepEqual(d.eczaneler, []);
});

test("bicimle: adresi ya da telefonu eksik kayıt listeye girmiyor", () => {
  // Yarım kayıt okuru yanlış yere gönderir.
  const eksik = sayfa("05 Ekim 2026", [
    kart("TAM ECZANESİ", "MERKEZ", "GERÇEK ADRES", "03661111111"),
    `<div class="col-md-12 nobetci"><div class=" col-md-10">
       <h4 class="tred"><strong>TELEFONSUZ ECZANESİ</strong> - MERKEZ</h4>
       <p> <i class='fa fa-home main-color'></i> BİR ADRES <br /></p>
     </div></div></div>`,
  ]);
  const d = bicimle(eksik, { bugunTarih: "2026-10-05" });
  assert.deepEqual(d.eczaneler.map((e) => e.ad), ["TAM ECZANESİ"]);
});

test("bicimle: konumsuz eczane yine listeleniyor", () => {
  // Harita bağlantısı güzel ama zorunlu değil; adres ve telefon yeter.
  const konumsuz = sayfa("05 Ekim 2026", [`
<div class="col-md-12 nobetci"><div class=" col-md-10">
  <h4 class="tred"><strong>KONUMSUZ ECZANESİ</strong> - TOSYA</h4>
  <p> <i class='fa fa-home main-color'></i> BİR CADDE NO:1
    <br><i class='fa fa-phone main-color'></i> <a href="tel:03667000000">03667000000</a>
  </p></div></div></div>`]);
  const d = bicimle(konumsuz, { bugunTarih: "2026-10-05" });
  assert.equal(d.eczaneler.length, 1);
  assert.equal(d.eczaneler[0].enlem, null);
  assert.equal(d.eczaneler[0].boylam, null);
});

test("bugun: Türkiye saatine göre hesaplanıyor", () => {
  // Sunucu UTC'de koşuyor. 4 Ekim 22:30 UTC, Kastamonu'da 5 Ekim
  // 01:30 — nöbet çoktan değişmiş.
  assert.equal(bugun(new Date("2026-10-04T22:30:00Z")), "2026-10-05");
  assert.equal(bugun(new Date("2026-10-05T00:30:00Z")), "2026-10-05");
  assert.equal(bugun(new Date("2026-10-05T20:59:00Z")), "2026-10-05");
  assert.equal(bugun(new Date("2026-10-05T21:30:00Z")), "2026-10-06");
});

test("eczaneCek: oda sayfası düşerse hata yükseliyor", async () => {
  const fetchIsl = async () => ({ ok: false, status: 503, text: async () => "" });
  await assert.rejects(() => eczaneCek({ fetchIsl }), /eczacı odası 503/);
});

test("eczaneCek: doğru adrese gidiyor", async () => {
  let u = "";
  const fetchIsl = async (adres) => {
    u = adres;
    return { ok: true, text: async () => TAM };
  };
  const d = await eczaneCek({ fetchIsl, bugunTarih: "2026-10-05" });
  assert.match(u, /kastamonueo\.org\.tr/);
  assert.equal(d.eczaneler.length, 2);
  assert.equal(d.kaynak, "Kastamonu Eczacı Odası");
});
