const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PASSWORD_PATTERN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isValidEmail(email: string): boolean {
  return EMAIL_PATTERN.test(email);
}

export function isValidPassword(password: string): boolean {
  return PASSWORD_PATTERN.test(password);
}

export function isValidUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

export function isValidIsoDateTime(value: string): boolean {
  if (value.trim() === "") return false;
  return !Number.isNaN(new Date(value).getTime());
}
