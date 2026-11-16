import assert from "node:assert/strict";
import test from "node:test";

import {
  isMercadoPagoEnvironment,
  resolvePayerEmail,
  isTestUpgradePromotionEnabled,
} from "./mercadopago_config.ts";

test("accepts only the two configured Mercado Pago environments", () => {
  assert.equal(isMercadoPagoEnvironment("test"), true);
  assert.equal(isMercadoPagoEnvironment("production"), true);
  assert.equal(isMercadoPagoEnvironment(null), false);
  assert.equal(isMercadoPagoEnvironment("sandbox"), false);
});

test("keeps the upgrade promotion disabled unless explicitly enabled in test", () => {
  assert.equal(isTestUpgradePromotionEnabled("test", "true"), true);
  assert.equal(isTestUpgradePromotionEnabled("production", "true"), false);
  assert.equal(isTestUpgradePromotionEnabled("test", null), false);
  assert.equal(isTestUpgradePromotionEnabled("test", "false"), false);
});

test("uses the configured test buyer instead of a client-provided email", () => {
  assert.equal(
    resolvePayerEmail("test", "user@example.com", "test_buyer@testuser.com"),
    "test_buyer@testuser.com",
  );
  assert.equal(
    resolvePayerEmail("production", "user@example.com", null),
    "user@example.com",
  );
  assert.equal(resolvePayerEmail("test", "user@example.com", null), null);
});
