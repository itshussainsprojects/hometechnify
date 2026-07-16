# HomeTechnify Backend Documentation

> **Version**: 1.0.0  
> **Last Updated**: January 2026  
> **Architecture**: Flutter (Frontend) + Clerk (Auth) + REST API (Backend)

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/          # Environment configuration
│   ├── constants/       # App-wide constants
│   ├── errors/          # Custom error/failure classes
│   ├── services/        # Core services (API, Auth, etc.)
│   ├── theme/           # App theming
│   ├── utils/           # Utility functions
│   └── widgets/         # Reusable widgets
├── features/
│   ├── auth/            # Authentication (Clerk integration)
│   ├── booking/         # Booking management
│   ├── provider/        # Service provider features
│   ├── admin/           # Admin panel
│   ├── home/            # Home screen
│   ├── chat/            # Messaging
│   ├── payment/         # Payment processing
│   ├── profile/         # User profiles
│   └── ...              # Other features
└── main.dart            # App entry point & routing
```

---

## ⚙️ Environment Configuration

**File**: `lib/core/config/env_config.dart`

```dart
class EnvConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
  static String get apiUrl => '$baseUrl/api';
  static String get clerkPublishableKey => dotenv.env['CLERK_PUBLISHABLE_KEY'] ?? '';
}
```

**Required `.env` file**:
```env
BASE_URL=http://localhost:3000
CLERK_PUBLISHABLE_KEY=pk_test_xxxx
ENVIRONMENT=development
```

---

## 🔐 Authentication System (Clerk)

### Provider: Clerk.dev
- **SDK**: `clerk_flutter: ^0.0.9-dev.1`
- **Strategies**: Password + Email OTP verification

### Auth Screens
| Screen | Route | Description |
|--------|-------|-------------|
| RoleSelectionScreen | `/role-selection` | User/Provider role choice |
| LoginScreen | `/login` | Email + Password login |
| SignupScreen | `/signup` | Registration with OTP |
| OtpScreen | `/otp` | Email verification |
| LocationPermissionScreen | `/location-permission` | Location access |

### ClerkAuthService (`lib/core/services/clerk_auth_service.dart`)

```dart
class ClerkAuthService {
  static bool isAuthenticated(context)      // Check auth status
  static String? getUserEmail(context)      // Get user email
  static String getUserName(context)        // Get full name
  static String? getUserId(context)         // Get Clerk user ID
  static String? getProfileImageUrl(context) // Get avatar URL
  static Future<void> signOut(context)      // Logout
}
```

### Auth Flow
```
┌─────────────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐
│ Role Select │───▶│  Login   │───▶│   Home    │    │          │
└─────────────┘    └──────────┘    └───────────┘    │          │
       │                                             │  Clerk   │
       ▼                                             │   API    │
┌─────────────┐    ┌──────────┐    ┌───────────┐    │          │
│   Signup    │───▶│   OTP    │───▶│ Location  │───▶│          │
└─────────────┘    └──────────┘    └───────────┘    └──────────┘
```

---

## 🌐 API Client

**File**: `lib/core/services/api_client.dart`

### Base Configuration
```dart
static const String _baseUrl = 'http://10.0.2.2:3000/api'; // Android Emulator
```

### Methods
| Method | Description |
|--------|-------------|
| `get(endpoint, {token})` | HTTP GET request |
| `post(endpoint, {body, token})` | HTTP POST request |
| `put(endpoint, {body, token})` | HTTP PUT request |

### Headers
```dart
{
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'Authorization': 'Bearer <token>' // If authenticated
}
```

### Error Handling
```dart
class NetworkFailure extends Failure { }
class ServerFailure extends Failure { }
```

---

## 📊 Data Models

### Core Models (in `marketplace_controller.dart`)

#### UserModel
```dart
class UserModel {
  String id;
  String name;
  String email;
  String phone;
  String? profileImage;
  String status;          // 'active', 'blocked', 'deleted'
  double rating;
  int totalBookings;
  double totalSpent;
  DateTime joinDate;
  String role;            // 'customer', 'provider', 'admin'
}
```

#### ProviderModel
```dart
class ProviderModel {
  String id;
  String name;
  String email;
  String phone;
  String? profileImage;
  String status;
  bool isVerified;
  double rating;
  int totalJobs;
  double earnings;
  double walletBalance;
  List<String> services;
  String location;
  double latitude, longitude;
}
```

#### BookingModel
```dart
class BookingModel {
  String id;
  String customerId;
  String providerId;
  String serviceId;
  String serviceName;
  DateTime bookingDate;
  String status;          // 'pending', 'confirmed', 'in_progress', 'completed', 'cancelled'
  double amount;
  String paymentStatus;
  String? notes;
}
```

#### ServiceCategoryModel
```dart
class ServiceCategoryModel {
  String id;
  String name;
  String icon;
  int providerCount;
}
```

#### TransactionModel (Wallet)
```dart
class TransactionModel {
  String id;
  String providerId;
  double amount;
  String type;            // 'credit', 'debit', 'withdrawal'
  String description;
  DateTime date;
}
```

---

## 🎮 MarketplaceController

**File**: `lib/core/services/marketplace_controller.dart`  
**Type**: ChangeNotifier (State Management)

### User Management
```dart
addUser(UserModel user)
updateUser(String id, Map updates)
blockUser(String id)
unblockUser(String id)
deleteUser(String id)
restoreUser(String id)
updateUserRating(String id, double rating)
```

### Provider Management
```dart
addProvider(ProviderModel provider)
updateProvider(String id, Map updates)
verifyProvider(String id)
blockProvider(String id)
deleteProvider(String id)
```

### Booking Management
```dart
addBooking(BookingModel booking)
updateBookingStatus(String id, String status)
cancelBooking(String id)
getBookingsForUser(String userId)
getBookingsForProvider(String providerId)
```

### Service Management
```dart
addServiceCategory(ServiceCategoryModel category)
updateServiceCategory(String id, Map updates)
deleteServiceCategory(String id)
```

### Wallet/Finance
```dart
addTransaction(TransactionModel)
getProviderBalance(String providerId)
processWithdrawal(String providerId, double amount)
```

---

## 🛣️ Application Routes

**Defined in**: `lib/main.dart` → `_generateRoute()`

### Authentication Routes
| Route | Screen |
|-------|--------|
| `/` | SplashScreen |
| `/onboarding` | OnboardingScreen |
| `/role-selection` | RoleSelectionScreen |
| `/login` | LoginScreen |
| `/signup` | SignupScreen |
| `/otp` | OtpScreen |
| `/location-permission` | LocationPermissionScreen |

### Customer Routes
| Route | Screen |
|-------|--------|
| `/home` | HomeScreen |
| `/service-detail` | ServiceDetailScreen |
| `/booking` | BookingScreen |
| `/my-bookings` | MyBookingsScreen |
| `/booking-detail` | BookingDetailScreen |
| `/track-provider` | TrackProviderScreen |
| `/chat` | ChatScreen |

### Provider Routes
| Route | Screen |
|-------|--------|
| `/provider/login` | ProviderLoginScreen |
| `/provider/signup` | ProviderSignupScreen |
| `/provider/dashboard` | ProviderDashboardScreen |
| `/provider/job-requests` | JobRequestsScreen |
| `/provider/earnings` | EarningsScreen |
| `/provider/wallet` | WalletScreen |
| `/provider/profile` | ProviderProfileScreen |
| `/provider/services` | ServicesListScreen |

### Admin Routes
| Route | Screen |
|-------|--------|
| `/admin/login` | AdminLoginScreen |
| `/admin/dashboard` | AdminDashboardScreen |
| `/admin/recycle-bin` | AdminRecycleBinScreen |

---

## 🔌 Backend API Endpoints (Expected)

### Authentication
```
POST /api/auth/register     - Create new user
POST /api/auth/login        - User login
POST /api/auth/verify-otp   - Verify email OTP
POST /api/auth/logout       - User logout
```

### Users
```
GET    /api/users           - List all users
GET    /api/users/:id       - Get user details
PUT    /api/users/:id       - Update user
DELETE /api/users/:id       - Delete user
```

### Providers
```
GET    /api/providers       - List all providers
GET    /api/providers/:id   - Get provider details
POST   /api/providers       - Register provider
PUT    /api/providers/:id   - Update provider
GET    /api/providers/nearby?lat=&lng= - Nearby providers
```

### Bookings
```
GET    /api/bookings        - List bookings
POST   /api/bookings        - Create booking
GET    /api/bookings/:id    - Get booking details
PUT    /api/bookings/:id    - Update booking
PATCH  /api/bookings/:id/status - Update status
```

### Services
```
GET    /api/services        - List service categories
GET    /api/services/:id    - Get service details
POST   /api/services        - Create service
```

### Wallet/Transactions
```
GET    /api/wallet/:providerId/balance - Get balance
GET    /api/wallet/:providerId/transactions - History
POST   /api/wallet/withdraw - Request withdrawal
```

---

## 📦 Dependencies

### Core
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0               # HTTP client
  provider: ^6.0.0           # State management
  flutter_dotenv: ^5.1.0     # Environment variables
  json_annotation: ^4.8.1    # JSON serialization
```

### Authentication
```yaml
  clerk_flutter: ^0.0.9-dev.1  # Clerk SDK
  clerk_auth: ^0.0.9-dev.1     # Clerk auth
```

### UI/UX
```yaml
  flutter_animate: ^4.3.0    # Animations
  skeletonizer: ^1.0.0       # Loading skeletons
  pinput: ^3.0.1             # OTP input
```

### Maps/Location
```yaml
  google_maps_flutter: ^2.5.3
  geolocator: ^10.1.0
  geocoding: ^2.1.1
```

---

## 🔄 State Management

### Pattern: Provider + ChangeNotifier

```dart
// Register in main.dart
ChangeNotifierProvider(
  create: (_) => MarketplaceController(),
  child: HomeTechnifyApp(),
)

// Access in widgets
final controller = Provider.of<MarketplaceController>(context);
// or
final controller = context.watch<MarketplaceController>();
```

---

## 🚀 Getting Started

### 1. Clone & Install
```bash
cd hometechnify
flutter pub get
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Run Application
```bash
flutter run
```

### 4. Backend Server (Required)
```bash
# Start your Node.js/Express backend on port 3000
cd backend
npm start
```

---

## 📝 Notes

1. **Clerk Integration**: Currently using email + password with OTP verification
2. **API Client**: Configured for Android emulator (`10.0.2.2`), change for iOS/Web
3. **MarketplaceController**: Contains mock data - replace with real API calls
4. **Missing**: Push notifications, real-time chat (WebSocket), payment gateway integration

---

*Documentation generated for HomeTechnify v1.0.0*
