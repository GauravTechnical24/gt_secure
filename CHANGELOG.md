# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-27

### Added
- **AES-256-CBC Encryption**: Military-grade encryption with unique IVs per encryption operation
- **Type-Safe Storage**: Support for String, int, bool, double, Map, List, and custom objects
- **SecureStorageUtil class**: Singleton pattern for global access
- **Automatic Key Management**: Secure key generation and storage
- **Key Rotation Support**: `rotateEncryptionKey()` method for enhanced security
- **In-Memory LRU Cache**: Caching for frequently accessed data with automatic eviction
- **Thread-Safe Operations**: Lock mechanism for concurrent access protection
- **App Reinstall Detection**: Automatic cleanup of stale data after app reinstallation
- **Batch Operations**: `batchWrite()` and `batchRead()` for efficient bulk operations
- **Data Backup/Restore**: `exportData()` and `importData()` methods
- **Storage Statistics**: `getStorageStats()` for monitoring storage usage
- **Data Validation**: `validateKey()` and `validateAllData()` for integrity checks
- **Custom Exceptions**: `SecureStorageException` with detailed error messages
- **Retry Logic**: Automatic retry for transient failures
- **Version Migration**: Built-in support for data migration between versions

### Platform Support
- Android (EncryptedSharedPreferences)
- iOS (Keychain)
- macOS
- Linux
- Windows
- Web (localStorage with limitations)
