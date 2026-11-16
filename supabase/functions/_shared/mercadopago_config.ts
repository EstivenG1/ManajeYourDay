export type MercadoPagoEnvironment = "test" | "production";

export function isMercadoPagoEnvironment(
  value: string | null,
): value is MercadoPagoEnvironment {
  return value === "test" || value === "production";
}

export function isTestUpgradePromotionEnabled(
  environment: string | null | undefined,
  setting: string | null | undefined,
): boolean {
  return environment === "test" && setting === "true";
}

export function resolvePayerEmail(
  environment: MercadoPagoEnvironment,
  requestedEmail: string | null,
  configuredTestEmail: string | null,
): string | null {
  return environment === "test" ? configuredTestEmail : requestedEmail;
}
