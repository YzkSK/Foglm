const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PASSWORD_PATTERN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;

export function isValidEmail(email: string): boolean {
  return EMAIL_PATTERN.test(email);
}

export function isValidPassword(password: string): boolean {
  return PASSWORD_PATTERN.test(password);
}
