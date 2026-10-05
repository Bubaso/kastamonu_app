import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";

import { BIRIMLER, bicimle, dovizCek, tarihCevir } from "./doviz.js";

// TCMB bülteninin kısaltılmış ama BİREBİR biçimli hâli.
const XML = `<?xml version="1.0" encoding="ISO-8859-9"?>
<Tarih_Date Tarih="02.10.2026" Date="10/02/2026" Bulten_No="2026/186">
<Currency CrossOrder="0" Kod="USD" CurrencyCode="USD">
<Unit>1</Unit><Isim>ABD DOLARI</Isim><CurrencyName>US DOLLAR</CurrencyName>
<ForexBuying>48.9699</ForexBuying><ForexSelling>49.0582</ForexSelling>
<BanknoteBuying>48.9357</BanknoteBuying><BanknoteSelling>49.1318</BanknoteSelling>
<CrossRateUSD/><CrossRateOther/>
</Currency>
<Currency CrossOrder="9" Kod="EUR" CurrencyCode="EUR">
<Unit>1</Unit><Isim>EURO</Isim><CurrencyName>EURO</CurrencyName>
<ForexBuying>55.0992</ForexBuying><ForexSelling>55.1984</ForexSelling>
<BanknoteBuying>55.0441</BanknoteBuying><BanknoteSelling>55.2646</BanknoteSelling>
<CrossRateUSD/><CrossRateOther>1.1246</CrossRateOther>
</Currency>
<Currency CrossOrder="5" Kod="GBP" CurrencyCode="GBP">
<Unit>1</Unit><Isim>INGILIZ STERLINI</Isim><CurrencyName>POUND STERLING</CurrencyName>
<ForexBuying>64.6117</ForexBuying><ForexSelling>64.9430</ForexSelling>
<BanknoteBuying>64.5344</BanknoteBuying><BanknoteSelling>65.0137</BanknoteSelling>
<CrossRateUSD/><CrossRateOther>1.3237</CrossRateOther>
</Currency>
<Currency CrossOrder="21" Kod="XDR" CurrencyCode="XDR">
<Unit>1</Unit><Isim>SDR</Isim><CurrencyName>SDR</CurrencyName>
<ForexBuying/><ForexSelling/><BanknoteBuying/><BanknoteSelling/>
<CrossRateUSD>0.7321</CrossRateUSD><CrossRateOther/>
</Currency>
</Tarih_Date>`;

test("tarihCevir: TCMB biçimi ISO'ya dönüyor", () => {
  assert.equal(tarihCevir("02.10.2026"), "2026-10-02");
  assert.equal(tarihCevir("31.12.2025"), "2025-12-31");
});

test("tarihCevir: olmayan gün sessizce kaymıyor", () => {
  // `new Date(2026, 1, 31)` 3 Mart'a kayar; bülten tarihi kaymamalı.
  assert.equal(tarihCevir("31.02.2026"), null);
  assert.equal(tarihCevir("00.10.2026"), null);
  assert.equal(tarihCevir("2026-10-02"), null);
  assert.equal(tarihCevir(""), null);
  assert.equal(tarihCevir(null), null);
});

test("bicimle: bültenden üç kur ve tarih çıkıyor", () => {
  const d = bicimle(XML);
  assert.equal(d.tarih, "2026-10-02");
  assert.equal(d.kaynak, "TCMB");
  assert.deepEqual(d.kurlar.map((k) => k.kod), ["USD", "EUR", "GBP"]);
  const usd = d.kurlar[0];
  assert.equal(usd.ad, "Dolar");
  assert.equal(usd.birim, 1);
  assert.equal(usd.alis, 48.9699);
  assert.equal(usd.satis, 49.0582);
});

test("bicimle: efektif değil döviz kuru alınıyor", () => {
  // Haber sitesinde gösterilen kur döviz satışı; efektif (banknot)
  // farklı bir sayı ve ikisini karıştırmak yanlış bilgi.
  const d = bicimle(XML);
  const usd = d.kurlar.find((k) => k.kod === "USD");
  assert.equal(usd.satis, 49.0582, "ForexSelling olmalı");
  assert.notEqual(usd.satis, 49.1318, "BanknoteSelling olmamalı");
});

test("bicimle: boş kurlu birim listeye girmiyor", () => {
  // XDR'nin alış/satışı boş; şeritte "—" basmak yerine hiç olmamalı.
  const d = bicimle(XML, { birimler: ["USD", "XDR"] });
  assert.deepEqual(d.kurlar.map((k) => k.kod), ["USD"]);
});

test("bicimle: biçim bozulursa yanlış sayı basılmıyor", () => {
  const d = bicimle("<html>bambaşka bir sayfa</html>");
  assert.equal(d.tarih, null);
  assert.deepEqual(d.kurlar, []);
});

test("bicimle: tarih okunamasa da kurlar geliyor", () => {
  const d = bicimle(XML.replace('Tarih="02.10.2026"', 'Tarih="bozuk"'));
  assert.equal(d.tarih, null);
  assert.equal(d.kurlar.length, 3, "kurlar yine okunmalı");
});

test("BIRIMLER: şeritte üç para birimi var", () => {
  assert.deepEqual(BIRIMLER, ["USD", "EUR", "GBP"]);
});

test("dovizCek: TCMB düşerse hata yükseliyor", async () => {
  const fetchIsl = async () => ({ ok: false, status: 503, text: async () => "" });
  await assert.rejects(() => dovizCek({ fetchIsl }), /TCMB 503/);
});

test("dovizCek: doğru adrese gidiyor", async () => {
  let u = "";
  const fetchIsl = async (adres) => {
    u = adres;
    return { ok: true, text: async () => XML };
  };
  const d = await dovizCek({ fetchIsl });
  assert.equal(u, "https://www.tcmb.gov.tr/kurlar/today.xml");
  assert.equal(d.kurlar.length, 3);
});
