import '../../data/models/user_model.dart';
import '../../../../core/utils/result.dart';



abstract class AuthRepository {
  Future<Result<void>> login(String phone, String password); // Returns success/fail for OTP send
  Future<Result<UserModel>> verifyOtp(String phone, String otp);
  Future<Result<UserModel>> register(UserModel user, String password, {String role = 'CUSTOMER'});
  /// [role] is the app the user is signing in from ('CUSTOMER' / 'PROVIDER').
  /// When given, the backend rejects an account that belongs to the other app.
  Future<Result<UserModel>> loginWithEmail(String email, String password,
      {String? role});
  Future<Result<UserModel>> loginWithGoogle(String role);
  Future<void> logout();
  Future<Result<void>> changePassword(String currentPassword, String newPassword);
  Future<Result<void>> deleteAccount();
  Future<Result<UserModel>> getCurrentUser();
  Future<void> sendPasswordResetOtp(String email);
  Future<void> verifyPasswordResetOtp(String email, String otp);
  Future<void> resetPassword(String email, String otp, String newPassword);
}
