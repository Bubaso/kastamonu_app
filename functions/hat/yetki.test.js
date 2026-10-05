import assert from "node:assert/strict";
import { test } from "node:test";

import { oturumDogrula } from "./yetki.js";

const AYAR = { taban: "https://x.supabase.co", anonAnahtar: "ANON" };
const ok = async () => ({ ok: true, json: async () => ({ id: "u1", email: "a@b.c" }) });
const red = async () => ({ ok: false, json: async () => ({}) });

test("jeton yoksa reddediliyor", async () => {
  const s = await oturumDogrula({}, { ...AYAR, fetchIsl: ok });
  assert.equal(s.tamam, false);
  assert.match(s.sebep, /jetonu yok/);
});

test("Bearer olmayan başlık reddediliyor", async () => {
  const s = await oturumDogrula({ authorization: "ANON" }, { ...AYAR, fetchIsl: ok });
  assert.equal(s.tamam, false);
});

test("anon anahtar oturum yerine geçmiyor", async () => {
  // Anon anahtar tarayıcıya iniyor; kabul edilseydi uç nokta açıkta olurdu.
  const s = await oturumDogrula({ authorization: "Bearer ANON" },
    { ...AYAR, fetchIsl: ok });
  assert.equal(s.tamam, false);
  assert.match(s.sebep, /anon anahtar/);
});

test("geçersiz jeton reddediliyor", async () => {
  const s = await oturumDogrula({ authorization: "Bearer sahte" },
    { ...AYAR, fetchIsl: red });
  assert.equal(s.tamam, false);
  assert.match(s.sebep, /geçersiz/);
});

test("geçerli oturum kabul ediliyor", async () => {
  const s = await oturumDogrula({ authorization: "Bearer gercek" },
    { ...AYAR, fetchIsl: ok });
  assert.equal(s.tamam, true);
  assert.equal(s.kullanici.id, "u1");
});

test("ağ hatası reddediliyor, çökmüyor", async () => {
  const patla = async () => { throw new Error("ECONNRESET"); };
  const s = await oturumDogrula({ authorization: "Bearer x" },
    { ...AYAR, fetchIsl: patla });
  assert.equal(s.tamam, false);
});

test("kimliksiz yanıt reddediliyor", async () => {
  const bos = async () => ({ ok: true, json: async () => ({}) });
  const s = await oturumDogrula({ authorization: "Bearer x" },
    { ...AYAR, fetchIsl: bos });
  assert.equal(s.tamam, false);
});
