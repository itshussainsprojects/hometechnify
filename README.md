# Home Technify

> On-Demand Home Services App - Your Home Services Partner

## 📱 Overview

Home Technify is a real-time, location-based mobile application that connects users with nearby verified service providers (plumber, electrician, cleaner, etc.), similar to Urban Company / TaskRabbit.

## 🏗️ Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend (Mobile) | Flutter (Dart) + Material UI |
| Backend | Node.js + Express.js |
| Database | MongoDB |
| Real-Time | Socket.IO |
| Calls | WebRTC |
| Maps | OpenStreetMap + MapLibre |
| Auth | Email OTP (Free) |
| Payments | Cash on Service (MVP) |
| Admin Panel | React / HTML + Bootstrap |

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/       # App colors, text styles, constants
│   ├── theme/           # App theme configuration
│   ├── utils/           # Utility functions
│   └── widgets/         # Reusable widgets
├── features/
│   ├── splash/          # Splash screen
│   ├── onboarding/      # Onboarding screens
│   ├── auth/            # Login, Signup, OTP
│   ├── home/            # Home screen
│   ├── services/        # Service listing
│   ├── booking/         # Booking flow
│   ├── chat/            # Chat & calls
│   ├── profile/         # User profile
│   └── provider/        # Provider screens
└── main.dart
```

## 🎨 Theme

- **Primary Color:** Dark Blue (#2196F3)
- **Secondary:** Black (#000000)
- **Background:** White (#FFFFFF)

## 🚀 Getting Started

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

## 📋 Development Phases

- [x] Phase 1: Project Setup
- [ ] Phase 2: User App Frontend
- [ ] Phase 3: Provider App Frontend
- [ ] Phase 4: Chat & Interaction UI
- [ ] Phase 5: Backend Setup
- [ ] Phase 6: Auth APIs
- [ ] Phase 7: Core APIs
- [ ] Phase 8: Verification System
- [ ] Phase 9: Admin Panel
- [ ] Phase 10: Integration & Cleanup

## 📄 License

Private - All rights reserved
