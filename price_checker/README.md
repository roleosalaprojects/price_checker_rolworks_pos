# Price Checker

A Flutter-based price checker application for retail stores. Allows customers to scan barcodes or search products to check prices.

## Features

- **Barcode Scanning** - Scan product barcodes to instantly check prices
- **Product Search** - Search products by name or keyword
- **Unit Pricing** - View prices for different units (piece, pack, box, etc.)
- **Product Images** - Display product images when available
- **Dark/Light Theme** - Switch between dark, light, or system theme
- **Theme Persistence** - Theme preference saved and restored on app restart
- **Server Configuration** - Configure server host address in settings
- **Modern Card-Based UI** - Clean, modern interface with card layouts
- **Offline-Ready Settings** - Settings stored locally using Hive

## Screenshots

*Coming soon*

## Getting Started

### Prerequisites

- Flutter SDK (>=3.1.5)
- Dart SDK
- A running backend server with product API

### Installation

1. Clone the repository
```bash
git clone https://github.com/roleosalaprojects/price_checker_rolworks_pos.git
cd price_checker_rolworks_pos/price_checker
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

### Configuration

1. Launch the app
2. Tap the settings icon (gear) in the top right
3. Enter your server host address (e.g., `192.168.1.100:8080`)
4. Select your preferred theme (Light/Dark/System)
5. Tap Save

## API Requirements

The app expects a backend server with the following endpoint:

- `GET /items/search?term={searchTerm}` - Returns matching products

Response format:
```json
{
  "products": [
    {
      "id": 1,
      "name": "Product Name",
      "barcode": "1234567890",
      "price": 99.00,
      "cost": 50.00,
      "markup": 20,
      "image": "path/to/image.jpg",
      "itemUnits": [
        {
          "qty": 12,
          "price": 1000.00,
          "unit": {
            "name": "Box"
          }
        }
      ]
    }
  ]
}
```

## Tech Stack

- **Flutter** - UI framework
- **Hive** - Local storage for settings
- **HTTP** - API communication

## License

This project is proprietary software.
