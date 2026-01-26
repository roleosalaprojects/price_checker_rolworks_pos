# Price Checker Session Log

**Last Updated:** 2026-01-26
**Project:** Price Checker for Rolworks POS
**Location:** `/Users/pepper/Projects/GitHub/price_checker_rolworks_pos/price_checker`

---

## Project Overview

A **Flutter-based retail POS application** with two main functions:
1. **Price Checking** - Customers scan barcodes to check product prices
2. **Employee Attendance** - Employees clock in/out via barcode scan

- **Framework:** Flutter/Dart
- **Flutter SDK:** >=3.1.5 <4.0.0
- **Version:** 1.0.0+1

---

## Architecture

```
lib/
├── main.dart                          # App entry point
├── components/                        # Reusable UI widgets
│   ├── custom_button.dart
│   ├── custom_icon_button.dart
│   ├── custom_snack_bar.dart          # Toast notifications
│   ├── custom_text.dart
│   └── custom_text_field.dart
├── controllers/
│   ├── main_controller.dart           # Device init, settings (host, store_id)
│   ├── theme_controller.dart          # Theme management (Light/Dark/System)
│   └── price_checker_page_controller.dart  # Settings dialog, helpers
├── models/
│   ├── product_model.dart             # Product data model
│   └── attendance_record_model.dart   # Attendance, Employee, Store, Summary
├── pages/
│   ├── price_checker_page.dart        # Main price check interface
│   ├── products/
│   │   └── product_details_page.dart  # Single product view
│   └── attendance/
│       ├── attendance_page.dart       # Time-in/out with barcode scan
│       └── attendance_history_page.dart # Monthly history & summary
├── services/
│   ├── http_service.dart              # HTTP client (GET/POST)
│   ├── product_service.dart           # (empty placeholder)
│   └── helpers.dart                   # Price calculation utilities
└── assets/
    └── transparent_store.png          # Store logo
```

---

## Features

### Price Checker
- Scan barcode or type product name (min 3 chars)
- Display product details with price
- Multiple unit prices (Box, Pack, Piece)
- Auto-clear results after 6 seconds

### Attendance Module
- Employee barcode scan for identification
- TIME IN button (green) - when not yet timed in
- TIME OUT button (red) - when timed in but not out
- Live clock display
- Today's status card (time-in, time-out, hours)
- History page with month navigation
- Monthly summary (present/absent/total hours)
- Auto-clear after 5 seconds

### Settings
- Server Host (e.g., 192.168.1.100:8080)
- Store ID (for multi-store support)
- Theme (Light/Dark/System)

---

## API Endpoints

### Price Checker
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/desktop/items/search?term=xxx` | Search products |

### Attendance
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/desktop/v1/attendance/lookup?barcode=xxx` | Lookup employee |
| POST | `/api/desktop/v1/attendance/time-in` | Record time-in |
| POST | `/api/desktop/v1/attendance/time-out` | Record time-out |
| GET | `/api/desktop/v1/attendance/today?barcode=xxx` | Today's record |
| GET | `/api/desktop/v1/attendance/history?barcode=xxx` | History |
| GET | `/api/desktop/v1/attendance/summary?barcode=xxx` | Monthly summary |

---

## Settings Storage (Hive)

- **Box name:** `price_checker_settings`
- **Keys:**
  - `server_address` - Server host
  - `store_id` - Current store ID
  - `theme_mode` - Theme preference

---

## Global Variables

- `host` - Server address (default: 'localhost:8080')
- `currentStoreId` - Store ID (default: 1)
- `products` - Last search results
- `themeController` - Theme management instance

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Hive init |
| `lib/pages/price_checker_page.dart` | Main UI, search logic |
| `lib/pages/attendance/attendance_page.dart` | Time-in/out with barcode |
| `lib/models/attendance_record_model.dart` | Attendance data models |
| `lib/controllers/main_controller.dart` | Settings management |
| `lib/services/http_service.dart` | API communication |

---

## Session History

### 2026-01-26
- Added logger package for error tracking
- Created log_service.dart with configured logger instances
- Updated http_service with debug/warning/error logging
- Fixed `branch_id` → `store_id` (table is `stores`, not `branches`)
- Updated all models, controllers, and API calls

### 2026-01-26 (earlier)
- Implemented barcode scanning for employee identification
- Added Store ID to settings (configurable)
- Created attendance module:
  - `attendance_page.dart` - main time-in/out screen
  - `attendance_history_page.dart` - history with summary
  - `attendance_record_model.dart` - data models
- Updated `http_service.dart` with `httpPost()`
- Updated `main_controller.dart` with store settings

### 2026-01-25
- Initial codebase exploration
- Created this session log
- Added attendance button to main page header

---

## Attendance Flow

```
1. Employee taps Attendance (clock icon)
2. Scans their ID barcode
3. System looks up employee via /lookup endpoint
4. Shows employee name and today's status
5. Employee taps TIME IN or TIME OUT
6. System records via /time-in or /time-out
7. Auto-clears after 5 seconds
```

---

## Notes

- Hardware barcode scanner works as keyboard input
- Employee identified by `code` field in backend users table
- No authentication required - barcode is the identifier
- Real-time data preferred (no offline caching)
