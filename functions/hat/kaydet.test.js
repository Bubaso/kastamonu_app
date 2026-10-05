import assert from "node:assert/strict";
import { test } from "node:test";

import { yazici } from "./kaydet.js";

const AYAR = { taban: "https://ornek.supabase.co", anahtar: "anahtar" };

/** Belirtilen adresleri kayıtlı sayan sahte PostgREST. */
function sahte({ kayitli = [], basarisizParca = -1 } = {}) {
  const cagrilar = [];
  const fetchIsl = async (u) => {
    cagrilar.push(u);
    const n = cagrilar.length - 1;
    if (n === basarisizParca) {
      return { ok: false, status: 414, json: async () => ({}) };
    }
    // `in.(...)` içindeki adreslerden kayıtlı olanlar dönüyor.
    const ic = decodeURIComponent(/in\.\(([^)]*)\)/.exec(u)?.[1] ?? "");
    const istenen = ic.split(",").map((s) => s.replace(/^"|"$/g, ""));
    return {
      ok: true, status: 200,
      json: async () => istenen.filter((a) => kayitli.includes(a))
        .map((a) => ({ kaynak_url: a })),
    };
  };
  return { fetchIsl, cagrilar };
}

const adres = (i) =>
  `https://www.taskoprupostasi.com/kastamonuda-cok-uzun-bir-haber-basligi-${i}`;

test("varMi: uzun adres listesi parçalara bölünüyor", async () => {
  // 145 adres tek sorguya dizildiğinde URL 37.639 karaktere çıkıyordu
  // ve istek düşüyordu. Parçalanmazsa bu test tek çağrı görür.
  const { fetchIsl, cagrilar } = sahte({ kayitli: [adres(100)] });
  const yz = yazici({ ...AYAR, fetchIsl });

  const sonuc = await yz.varMi(Array.from({ length: 145 }, (_, i) => adres(i)));

  assert.ok(cagrilar.length >= 6, `parça sayısı: ${cagrilar.length}`);
  for (const u of cagrilar) {
    assert.ok(u.length < 8000, `parça sorgusu çok uzun: ${u.length}`);
  }
  assert.ok(sonuc.has(adres(100)), "kayıtlı adres bulunmalı");
  assert.equal(sonuc.size, 1);
});

test("varMi: sorgu düşerse koşu DURUYOR, boş küme dönmüyor", async () => {
  // Eski davranış sessizce boş küme döndürüyordu: "hiçbiri kayıtlı
  // değil". Sonuç, yayındaki haberlerin her koşuda yeniden
  // sentezlenmesi ve on iki model çağrısının boşa yanmasıydı.
  const { fetchIsl } = sahte({ basarisizParca: 0 });
  const yz = yazici({ ...AYAR, fetchIsl });

  await assert.rejects(
    () => yz.varMi([adres(1), adres(2)]),
    /kayıtlı adresler okunamadı: 414/,
  );
});

test("varMi: boş liste ağa hiç çıkmıyor", async () => {
  const { fetchIsl, cagrilar } = sahte();
  const yz = yazici({ ...AYAR, fetchIsl });
  assert.equal((await yz.varMi([])).size, 0);
  assert.equal((await yz.varMi([null, undefined, ""])).size, 0);
  assert.equal(cagrilar.length, 0);
});

test("varMi: aynı adres iki kez sorulmuyor", async () => {
  const { fetchIsl, cagrilar } = sahte({ kayitli: [adres(1)] });
  const yz = yazici({ ...AYAR, fetchIsl });
  const sonuc = await yz.varMi([adres(1), adres(1), adres(2), adres(1)]);
  assert.equal(cagrilar.length, 1);
  const ic = decodeURIComponent(/in\.\(([^)]*)\)/.exec(cagrilar[0])[1]);
  assert.equal(ic.split(",").length, 2, "yinelenen adres tekilleşmeli");
  assert.ok(sonuc.has(adres(1)));
});
