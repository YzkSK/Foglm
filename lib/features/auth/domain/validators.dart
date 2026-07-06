final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _passwordPattern = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');

/// メールアドレスの形式を検証する。
bool isValidEmail(String email) => _emailPattern.hasMatch(email);

/// パスワード要件(8文字以上・英大文字/小文字/数字を全て含む)を検証する(仕様書 3.1参照)。
bool isValidPassword(String password) => _passwordPattern.hasMatch(password);
