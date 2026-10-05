import assert from "node:assert/strict";
import { test } from "node:test";

import {
  ILCE_KOORDINAT, bicimle, hadise, havaCek, ruzgarYonu,
} from "./hava.js";

// Gerçek bir Open-Meteo yanıtının kısaltılmış hâli.
const HAM = {
  current: {
    time: "2026-10-05T14:45",
    temperature_2m: 17.8,
    apparent_temperature: 16.2,
    relative_humidity_2m: 35,
    wind_speed_10m: 4.5,
    wind_direction_10m: 61,
    weather_code: 2,
  },
  daily: {
    time: ["2026-10-05", "2026-10-06", "2026-10-07"],
    weather_code: [2, 61, 75],
    temperature_2m_max: [17.4, 19.1, 8.8],
    temperature_2m_min: [5.9, 7.2, -1.4],
    wind_speed_10m_max: [8.3, 12.7, 20.1],
    precipitation_probability_max: [0, 80, 95],
  },
};

test("ilçe koordinatları: yirmi ilçenin hepsi var ve Kastamonu sınırlarında", () => {
  const adlar = Object.keys(ILCE_KOORDINAT);
  assert.equal(adlar.length, 20);
  assert.ok(adlar.includes("Merkez"));
  for (const [ad, [enlem, boylam]] of Object.entries(ILCE_KOORDINAT)) {
    // Kastamonu ili kabaca 41,0–42,1 K ve 32,7–34,5 D arasında.
    assert.ok(enlem > 41.0 && enlem < 42.1, `${ad} enlem dışarıda: ${enlem}`);
    assert.ok(boylam > 32.7 && boylam < 34.5, `${ad} boylam dışarıda: ${boylam}`);
  }
});

test("hadise: WMO kodları Türkçeleşiyor", () => {
  assert.equal(hadise(0).ad, "Açık");
  assert.equal(hadise(3).ad, "Çok bulutlu");
  assert.equal(hadise(75).ad, "Yoğun kar");
  assert.equal(hadise(95).ad, "Gök gürültülü fırtına");
});

test("hadise: bilinmeyen kod haberi düşürmüyor", () => {
  // Sağlayıcı yeni bir kod eklerse şerit boş kalmamalı.
  assert.equal(hadise(123).ad, "—");
  assert.equal(hadise(null).simge, "bilinmiyor");
  assert.equal(hadise(undefined).simge, "bilinmiyor");
});

test("ruzgarYonu: derece sekiz yöne iniyor", () => {
  assert.equal(ruzgarYonu(0), "Kuzey");
  assert.equal(ruzgarYonu(360), "Kuzey");
  assert.equal(ruzgarYonu(10), "Kuzey");
  assert.equal(ruzgarYonu(45), "Kuzeydoğu");
  assert.equal(ruzgarYonu(90), "Doğu");
  assert.equal(ruzgarYonu(180), "Güney");
  assert.equal(ruzgarYonu(270), "Batı");
  assert.equal(ruzgarYonu(349), "Kuzey");
});

test("ruzgarYonu: 337,5 sınırının iki yanı ayrışıyor", () => {
  assert.equal(ruzgarYonu(330), "Kuzeybatı");
  assert.equal(ruzgarYonu(340), "Kuzey");
});

test("ruzgarYonu: geçersiz derece null", () => {
  assert.equal(ruzgarYonu(null), null);
  assert.equal(ruzgarYonu("abc"), null);
});

test("bicimle: yanıt şeride uygun biçime iniyor", () => {
  const h = bicimle(HAM, "Tosya");
  assert.equal(h.ilce, "Tosya");
  assert.equal(h.kaynak, "Open-Meteo");
  assert.equal(h.simdi.sicaklik, 18, "yuvarlanmalı");
  assert.equal(h.simdi.hissedilen, 16);
  assert.equal(h.simdi.nem, 35);
  assert.equal(h.simdi.ruzgarYonu, "Kuzeydoğu");
  assert.equal(h.simdi.ad, "Parçalı bulutlu");
  assert.equal(h.gunler.length, 3);
  assert.deepEqual(h.gunler[2], {
    tarih: "2026-10-07",
    enDusuk: -1,
    enYuksek: 9,
    ruzgar: 20,
    yagisOlasiligi: 95,
    ad: "Yoğun kar",
    simge: "kar",
  });
});

test("bicimle: eksik alanlar çökertmiyor", () => {
  // Sağlayıcı bir alanı vermezse şerit yine çizilebilmeli.
  const h = bicimle({ current: {}, daily: {} }, "Merkez");
  assert.equal(h.gunler.length, 0);
  assert.equal(h.simdi.nem, null);
  assert.equal(h.simdi.ruzgarYonu, null);
  assert.equal(h.ilce, "Merkez");
});

test("havaCek: tanınmayan ilçe Merkez'e düşüyor", async () => {
  let istenen = "";
  const fetchIsl = async (u) => {
    istenen = u;
    return { ok: true, json: async () => HAM };
  };
  const h = await havaCek("Ankara", { fetchIsl });
  assert.equal(h.ilce, "Merkez");
  const [enlem, boylam] = ILCE_KOORDINAT["Merkez"];
  assert.ok(istenen.includes(`latitude=${enlem}`));
  assert.ok(istenen.includes(`longitude=${boylam}`));
});

test("havaCek: istenen ilçenin koordinatı gidiyor", async () => {
  let istenen = "";
  const fetchIsl = async (u) => {
    istenen = u;
    return { ok: true, json: async () => HAM };
  };
  const h = await havaCek("Cide", { fetchIsl, gun: 10 });
  assert.equal(h.ilce, "Cide");
  assert.ok(istenen.includes("latitude=41.8921"), istenen);
  assert.ok(istenen.includes("forecast_days=10"));
  assert.ok(istenen.includes("timezone=Europe%2FIstanbul"));
});

test("havaCek: servis düşerse hata yükseliyor", async () => {
  const fetchIsl = async () => ({ ok: false, status: 503, json: async () => ({}) });
  await assert.rejects(() => havaCek("Merkez", { fetchIsl }), /hava servisi 503/);
});
