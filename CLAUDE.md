# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run in debug mode
flutter run -d chrome        # Run on web (Chrome)
flutter run -d <device_id>   # Run on specific device
flutter analyze              # Run Dart analyzer
flutter test                 # Run tests
flutter build apk            # Build Android APK
flutter build ios            # Build iOS
flutter build web            # Build web
flutter clean                # Clean build artifacts
flutterfire configure        # Reconfigure Firebase
```

## Architecture

This is a Flutter app using **Clean Architecture** with **Provider** state management.

### Layer Structure (per feature)

```
features/{feature}/
├── data/
│   ├── datasources/     # Firebase/API calls
│   ├── models/          # DTOs with toFirestore/fromFirestore
│   └── repositories/    # Repository implementations
├── domain/
│   ├── entities/        # Business models (extend Equatable)
│   ├── repositories/    # Abstract repository interfaces
│   └── usecases/        # Single-purpose business logic classes
└── presentation/
    ├── pages/           # Full-screen widgets
    ├── providers/       # ChangeNotifier classes
    └── widgets/         # Reusable UI components
```

Dependencies flow inward: Presentation → Domain ← Data

### Key Directories

- `lib/core/` - Shared code: constants, errors, theme, validators
- `lib/features/auth/` - Phone OTP authentication
- `lib/features/booking/` - Slot booking system
- `lib/router/` - GoRouter navigation config
- `lib/injection_container.dart` - Service locator for DI

## State Management

Uses **Provider with ChangeNotifier**. Key providers:
- `AuthProvider` - Auth state, OTP flow, user session (AuthStatus enum)
- `BookingProvider` - Slot selection, booking CRUD, admin operations (BookingState enum)
- `ThemeProvider` - Theme switching (5 Material 3 color schemes), dark mode, persistence via SharedPreferences

Providers are injected via `MultiProvider` in `app.dart`.

## Navigation

GoRouter with path-based routing:
- `/` - Splash (animated)
- `/phone-input` - Phone entry
- `/otp-verification` - OTP input (phone passed via `state.extra`)
- `/home` - Dashboard (role-based UI)
- `/booking` - Customer booking
- `/admin/booking` - Admin panel

Auth redirects handled in `app_router.dart` via `redirect` callback with `RefreshListenable` on `AuthProvider`.

## Firebase

- **Auth**: Phone OTP authentication
- **Firestore**: Collections - `users`, `bookings`
- **Project**: `book-my-game-a9b76`
- Config in `firebase_options.dart` (auto-generated)
- Android: `google-services.json` in `android/app/`, SHA-1 fingerprint required for Phone Auth

### Firestore Schema

**`users` collection**: uid, phone, displayName, email, photoUrl, role (ADMIN|CUSTOMER), membership (FREE|GOLD|PLATINUM), createdAt

**`bookings` collection**: userId, userPhone, customerName?, date, startTime, endTime, remarks?, status (PENDING|CONFIRMED|CANCELLED|COMPLETED), isPaid, amountPaid?, paidAt?, createdByAdmin?, createdAt

## Domain Conventions

- Entities use `Equatable` and have computed getters (e.g., `isAdmin`, `isPending`, `isPast`)
- Enums have `.value` property for Firestore serialization: `BookingStatus.confirmed.value → "CONFIRMED"`
- Dates normalized to midnight for calendar operations
- Firestore queries use `dateKey` string field to avoid composite indexes
- `copyWith` pattern on entities for immutable updates

## User Roles

`UserRole` enum: `admin`, `customer`
- **Admins**: Create multiple bookings, mark as paid, manage all bookings, multi-slot selection, enter customer phone/amount
- **Customers**: Book available slots, view own booking history

Home page renders different Quick Actions based on `user?.isAdmin`.

## Booking Slots

- Hours: 6 AM to 8 PM (configured in `app_constants.dart`)
- Duration: 1 hour per slot
- Slot status: `available`, `booked`, `blocked`, `unavailable`
- Booking status: `pending`, `confirmed`, `cancelled`, `completed`
- Past time slots (today only) are automatically marked `unavailable` in the data source
- Both admin and customer views respect slot unavailability

## Android Config

- compileSdk: 36, targetSdk: 34, Java/Kotlin: 17
- Namespace: `com.example.book_my_game`

## Important Implementation Notes

### Android Phone Auth (Async Callbacks)
Firebase `verifyPhoneNumber` callbacks (`codeSent`, `verificationCompleted`) are **async on Android**. `phone_input_page.dart` uses a **listener pattern** on `AuthProvider` (added in `initState`, removed in `dispose`) instead of checking status synchronously after `await`. This is critical for Android compatibility.

### Admin Booking Dialog
Uses `StatefulBuilder` for dialog-local state. Phone `TextField` must have `onChanged: (_) => setState(() {})` to trigger rebuilds when validating the Create button enabled state.

## Code Style

- Material 3 theming with `ColorScheme`
- `withValues(alpha:)` instead of deprecated `withOpacity()`
- `Consumer`/`context.read` for Provider access
- Country code: `+977` (Nepal)
- OTP: 6 digits, 60s timeout
