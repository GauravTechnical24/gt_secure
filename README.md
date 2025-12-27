# GT Secure

[![pub package](https://img.shields.io/pub/v/gt_secure.svg)](https://pub.dev/packages/gt_secure)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D1.17.0-blue.svg)](https://flutter.dev)

A production-ready Flutter package for **secure local storage** with AES-256-CBC encryption. Perfect for storing sensitive data like authentication tokens, user credentials, and encrypted preferences.

## ✨ Features

- 🔐 **AES-256-CBC Encryption** - Military-grade encryption with unique IVs per encryption
- 🔑 **Automatic Key Management** - Secure key generation, storage, and rotation support
- 📦 **Type-Safe Storage** - Store String, int, bool, double, Map, List, and custom objects
- ⚡ **In-Memory Caching** - LRU cache for frequently accessed data
- 🔒 **Thread-Safe Operations** - Lock mechanism for concurrent access protection
- 🔄 **App Reinstall Detection** - Automatic cleanup of stale data after reinstall
- 🛡️ **Comprehensive Error Handling** - Custom exceptions with detailed error messages
- 📊 **Batch Operations** - Efficient bulk read/write for better performance
- 💾 **Backup & Restore** - Export and import encrypted data
- 🔁 **Key Rotation** - Periodically rotate encryption keys for enhanced security

## 📱 Platform Support

| Platform | Support |
|----------|---------|
| Android  | ✅ (EncryptedSharedPreferences) |
| iOS      | ✅ (Keychain) |
| macOS    | ✅ |
| Linux    | ✅ |
| Windows  | ✅ |
| Web      | ⚠️ (Limited - uses localStorage) |

## 🚀 Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  gt_secure: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### Basic Usage

```dart
import 'package:gt_secure/gt_secure.dart';

// Initialize once at app startup
await secureStorage.init();

// Store values
await secureStorage.setString('username', 'john_doe');
await secureStorage.setInt('userId', 12345);
await secureStorage.setBool('isLoggedIn', true);
await secureStorage.setDouble('balance', 1234.56);

// Retrieve values
final username = await secureStorage.getString('username');
final userId = await secureStorage.getInt('userId');
final isLoggedIn = await secureStorage.getBool('isLoggedIn');
final balance = await secureStorage.getDouble('balance');

// Remove values
await secureStorage.remove('userId');

// Clear all data
await secureStorage.clearAll();
```

## 📖 API Reference

### Initialization

```dart
// Initialize storage (required before any operation)
await secureStorage.init();
```

### Store & Retrieve Complex Objects

```dart
// Store a Map
await secureStorage.setMap('userSettings', {
  'theme': 'dark',
  'notifications': true,
  'language': 'en',
});

// Retrieve a Map
final settings = await secureStorage.getMap('userSettings');

// Store a List
await secureStorage.setList('recentSearches', ['flutter', 'dart']);

// Retrieve a List
final searches = await secureStorage.getList('recentSearches');

// Store custom objects
await secureStorage.setObject('user', user.toJson());

// Retrieve custom objects
final user = await secureStorage.getObject<User>(
  'user',
  (json) => User.fromJson(json),
);
```

### Batch Operations

```dart
// Write multiple values at once
await secureStorage.batchWrite({
  'key1': 'value1',
  'key2': 123,
  'key3': true,
});

// Read multiple values at once
final values = await secureStorage.batchRead(['key1', 'key2', 'key3']);
```

### Utility Methods

```dart
// Check if key exists
final exists = await secureStorage.containsKey('authToken');

// Get all stored keys
final allKeys = await secureStorage.getAllKeys();

// Remove multiple keys
await secureStorage.removeAll(['key1', 'key2']);

// Get storage statistics
final stats = await secureStorage.getStorageStats();
// Returns: {totalKeys, totalSizeBytes, cacheSize, version, initialized}
```

### Advanced Features

```dart
// Export data for backup
final backup = await secureStorage.exportData();

// Import data from backup
await secureStorage.importData(backup);

// Rotate encryption key (for enhanced security)
await secureStorage.rotateEncryptionKey();

// Validate data integrity
final isValid = await secureStorage.validateKey('myKey');
final allValid = await secureStorage.validateAllData();

// Reset entire storage (including encryption key)
await secureStorage.resetStorage();
```

### Error Handling

```dart
try {
  await secureStorage.setString('key', 'value');
} on SecureStorageException catch (e) {
  print('Storage error: ${e.message}');
  if (e.originalError != null) {
    print('Caused by: ${e.originalError}');
  }
}
```

## 🔐 Security Best Practices

1. **Initialize Early**: Call `init()` at app startup before any storage operations
2. **Handle Errors**: Always wrap operations in try-catch blocks
3. **Key Rotation**: Consider rotating encryption keys periodically for sensitive apps
4. **Don't Store Raw Passwords**: Store hashed or tokenized credentials only
5. **Clear on Logout**: Use `clearAll()` when user logs out

## 📋 Example

See the [example](example) folder for a complete working demo application.

```dart
import 'package:flutter/material.dart';
import 'package:gt_secure/gt_secure.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await secureStorage.init();
  runApp(const MyApp());
}
```

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting a pull request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) - Platform-specific secure storage
- [encrypt](https://pub.dev/packages/encrypt) - AES encryption implementation
