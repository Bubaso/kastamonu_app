// node --test functions/gorsel-yol.test.js
//
// Bağımlılık gerektirmiyor: Node'un kendi test koşucusu yetiyor.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { cozumle } from "./gorsel-yol.js";

test("geçerli yol çözümleniyor", () => {
  assert.deepEqual(cozumle("/gorsel/320/kastamonu-a70407ff.jpg"), {
    genislik: 320,
    dosya: "kastamonu-a70407ff.jpg",
  });
  assert.equal(cozumle("/gorsel/1200/a.webp").genislik, 1200);
  assert.equal(cozumle("/gorsel/640/A_b-c.JPEG").genislik, 640);
});

test("listede olmayan genişlik reddediliyor", () => {
  // Serbest genişlik hem CDN önbelleğini böler hem sunucuyu istenildiği
  // kadar çalıştırmaya açar.
  assert.equal(cozumle("/gorsel/321/a.jpg"), null);
  assert.equal(cozumle("/gorsel/4000/a.jpg"), null);
  assert.equal(cozumle("/gorsel/0/a.jpg"), null);
  assert.equal(cozumle("/gorsel/-320/a.jpg"), null);
  assert.equal(cozumle("/gorsel/320.5/a.jpg"), null);
  assert.equal(cozumle("/gorsel/abc/a.jpg"), null);
});

test("dizin dışına çıkılamıyor", () => {
  assert.equal(cozumle("/gorsel/320/../../etc/passwd"), null);
  assert.equal(cozumle("/gorsel/320/..%2Fgizli.jpg"), null);
  assert.equal(cozumle("/gorsel/320/alt/dizin.jpg"), null);
});

test("başka kovaya ya da adrese gidilemiyor", () => {
  // Açık vekil olmadığının testi: adres kabul etmiyor.
  assert.equal(cozumle("/gorsel/320/https://baska/a.jpg"), null);
  assert.equal(cozumle("/gorsel/320/a.jpg?u=https://baska"), null);
});

test("beklenmeyen uzantı ve biçim reddediliyor", () => {
  assert.equal(cozumle("/gorsel/320/a.gif"), null);
  assert.equal(cozumle("/gorsel/320/a.svg"), null);
  assert.equal(cozumle("/gorsel/320/uzantisiz"), null);
  assert.equal(cozumle("/gorsel/320/bosluk li.jpg"), null);
});

test("yanlış biçimli yol reddediliyor", () => {
  assert.equal(cozumle("/gorsel/320"), null);
  assert.equal(cozumle("/gorsel"), null);
  assert.equal(cozumle("/baska/320/a.jpg"), null);
  assert.equal(cozumle(""), null);
  assert.equal(cozumle(null), null);
  assert.equal(cozumle(undefined), null);
});
