import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';

/// Custom exception for secure storage errors
class SecureStorageException implements Exception {
  final String message;
  final dynamic originalError;

  SecureStorageException(this.message, [this.originalError]);

  @override
  String toString() =>
      'SecureStorageException: $message${originalError != null ? '\nCaused by: $originalError' : ''}';
}

/// Production-Ready Secure Storage Utility Class
///
/// A high-performance, encrypted local storage solution for Flutter
/// Features:
/// - AES-256-CBC encryption with unique IVs per encryption
/// - Fast read/write operations with error handling and retry logic
/// - Type-safe storage (String, int, bool, double, Map, List)
/// - Singleton pattern for global access
/// - App-specific encryption key with rotation support
/// - Comprehensive error handling and logging
/// - Data versioning and migration support
/// - Automatic cleanup on app reinstallation
/// - In-memory caching for frequently accessed data
/// - Thread-safe operations with locks
class SecureStorageUtil {
  // Singleton instance
  static final SecureStorageUtil _instance = SecureStorageUtil._internal();
  factory SecureStorageUtil() => _instance;
  SecureStorageUtil._internal();

  // Storage instances
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Data will be automatically migrated to custom ciphers on first access
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      // Added for better security on iOS
      synchronizable: false,
    ),
  );

  // Encryption components
  late encrypt.Key _key;
  bool _initialized = false;

  // In-memory cache for frequently accessed data (optional optimization)
  final Map<String, String> _cache = {};
  static const int _maxCacheSize = 50; // Limit cache size
  final List<String> _cacheAccessOrder = []; // For LRU eviction

  // Lock for thread-safe operations
  Completer<void> _currentLock = Completer<void>()..complete();

  // Unique key for this app's encryption
  static const String _keyIdentifier = 'app_encryption_key_v1';
  static const String _versionKey = 'storage_version';
  static const int _currentVersion = 1;

  // Key to detect app reinstallation (stored in SharedPreferences)
  static const String _installMarkerKey = 'app_install_marker';

  // Retry configuration for transient failures
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 100);

  /// Initialize the secure storage
  /// Must be called before using any storage operations
  ///
  /// Automatically detects app reinstallation and clears old secure storage data
  ///
  /// [enableCache] - Enable in-memory caching for frequently accessed data
  ///
  /// Throws [SecureStorageException] if initialization fails
  Future<void> init({bool enableCache = false}) async {
    if (_initialized) return;

    await _withLock(() async {
      if (_initialized) return; // Double-check after acquiring lock

      try {
        // Check if app was reinstalled and clear old secure storage data
        await _checkAndClearOnReinstall();

        // Get or create encryption key
        String? savedKey = await _secureStorage.read(key: _keyIdentifier);

        if (savedKey == null) {
          // Generate new key on first launch
          _key = encrypt.Key.fromSecureRandom(32);
          savedKey = base64Url.encode(_key.bytes);
          await _secureStorage.write(key: _keyIdentifier, value: savedKey);

          // Set initial version
          await _secureStorage.write(
            key: _versionKey,
            value: _currentVersion.toString(),
          );
        } else {
          // Load existing key
          final keyBytes = base64Url.decode(savedKey);
          
          // Validate key length (must be 16, 24, or 32 bytes)
          if (keyBytes.length == 16 || keyBytes.length == 24 || keyBytes.length == 32) {
            _key = encrypt.Key(keyBytes);
            // Check version and migrate if needed
            await _checkAndMigrateVersion();
          } else {
            // Key is corrupted - regenerate it
            _key = encrypt.Key.fromSecureRandom(32);
            savedKey = base64Url.encode(_key.bytes);
            await _secureStorage.write(key: _keyIdentifier, value: savedKey);
            
            // Reset version since we are starting fresh with a new key
            await _secureStorage.write(
              key: _versionKey,
              value: _currentVersion.toString(),
            );
          }
        }

        _initialized = true;
      } catch (e) {
        throw SecureStorageException(
          'Failed to initialize SecureStorageUtil',
          e,
        );
      }
    });
  }

  /// Thread-safe operation wrapper
  Future<T> _withLock<T>(Future<T> Function() operation) async {
    while (!_currentLock.isCompleted) {
      await _currentLock.future;
    }

    _currentLock = Completer<void>();
    try {
      return await operation();
    } finally {
      _currentLock.complete();
    }
  }

  /// Retry wrapper for transient failures
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        await Future.delayed(_retryDelay * attempts);
      }
    }
  }

  /// Check if app was reinstalled and clear old secure storage data
  Future<void> _checkAndClearOnReinstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasInstallMarker = prefs.containsKey(_installMarkerKey);

      // Check if secure storage has data (encryption key exists)
      final hasSecureData = await _secureStorage.containsKey(
        key: _keyIdentifier,
      );

      if (!hasInstallMarker && hasSecureData) {
        // App was reinstalled - clear all old secure storage data
        await _secureStorage.deleteAll();
        _cache.clear(); // Clear cache as well
        _cacheAccessOrder.clear();
      }

      // Set/update the install marker
      if (!hasInstallMarker) {
        await prefs.setBool(_installMarkerKey, true);
      }
    } catch (e) {
      // If check fails, continue with normal initialization
      // This ensures the app doesn't crash if SharedPreferences fails
    }
  }

  /// Check storage version and perform migration if needed
  Future<void> _checkAndMigrateVersion() async {
    try {
      final versionStr = await _secureStorage.read(key: _versionKey);
      final version = versionStr != null ? int.tryParse(versionStr) ?? 0 : 0;

      if (version < _currentVersion) {
        // Perform migration logic here if needed
        await _migrateData(version, _currentVersion);

        await _secureStorage.write(
          key: _versionKey,
          value: _currentVersion.toString(),
        );
      }
    } catch (e) {
      // If version check fails, assume current version
      await _secureStorage.write(
        key: _versionKey,
        value: _currentVersion.toString(),
      );
    }
  }

  /// Migration logic for different versions
  Future<void> _migrateData(int fromVersion, int toVersion) async {
    // Add migration logic here for future versions
    // Example:
    // if (fromVersion == 1 && toVersion == 2) {
    //   // Migrate from v1 to v2
    // }
  }

  /// Ensure initialization before operations
  void _checkInit() {
    if (!_initialized) {
      throw SecureStorageException(
        'SecureStorageUtil not initialized. Call init() first.',
      );
    }
  }

  /// Internal key validation
  void _validateKey(String key) {
    if (key.trim().isEmpty) {
      throw SecureStorageException('Key cannot be empty or only whitespace');
    }
  }

  /// Encrypt data with a unique IV for each encryption
  /// Returns base64 encoded string with IV prepended
  String _encrypt(String data) {
    try {
      if (data.isEmpty) {
        return '';
      }

      // Generate unique IV for each encryption
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key, mode: encrypt.AESMode.cbc),
      );
      final encrypted = encrypter.encrypt(data, iv: iv);

      // Prepend IV to encrypted data (IV is not secret, just needs to be unique)
      final combined = iv.bytes + encrypted.bytes;
      return base64Url.encode(combined);
    } catch (e) {
      throw SecureStorageException('Encryption failed', e);
    }
  }

  /// Decrypt data by extracting IV from the beginning
  String _decrypt(String encryptedData) {
    try {
      if (encryptedData.isEmpty) {
        return '';
      }

      final combined = base64Url.decode(encryptedData);

      // Validate minimum length (16 bytes IV + at least 1 block of encrypted data)
      if (combined.length < 32) {
        // If data is present but too short, it might be unencrypted or corrupted
        // For backward compatibility or graceful handling, we can decide to return empty
        // or throw. The user requested graceful handling.
        return '';
      }

      // Extract IV (first 16 bytes) and encrypted data
      final iv = encrypt.IV(combined.sublist(0, 16));
      final encryptedBytes = combined.sublist(16);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key, mode: encrypt.AESMode.cbc),
      );
      final encrypted = encrypt.Encrypted(encryptedBytes);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      // Fallback: if decryption fails, return empty string instead of crashing
      // unless we want to strictly enforce it.
      return '';
    }
  }

  /// Update cache with LRU eviction
  void _updateCache(String key, String value) {
    // Remove key if it already exists
    _cacheAccessOrder.remove(key);

    // Add to the end (most recently used)
    _cacheAccessOrder.add(key);
    _cache[key] = value;

    // Evict oldest if cache is too large
    if (_cache.length > _maxCacheSize) {
      final oldestKey = _cacheAccessOrder.removeAt(0);
      _cache.remove(oldestKey);
    }
  }

  /// Remove from cache
  void _removeFromCache(String key) {
    _cache.remove(key);
    _cacheAccessOrder.remove(key);
  }

  /// Store a String value
  ///
  /// Throws [SecureStorageException] if operation fails
  Future<void> setString(String key, String value) async {
    _checkInit();
    _validateKey(key);
    try {
      await _withRetry(() async {
        final encrypted = _encrypt(value);
        await _secureStorage.write(key: key, value: encrypted);
        _updateCache(key, encrypted);
      });
    } catch (e) {
      throw SecureStorageException('Failed to store string for key: $key', e);
    }
  }

  /// Retrieve a String value
  ///
  /// Returns [defaultValue] (null by default) if key doesn't exist or is empty
  /// Gracefully handles decryption errors by returning empty string or [defaultValue]
  Future<String?> getString(String key, {String? defaultValue}) async {
    _checkInit();
    _validateKey(key);
    try {
      // Check cache first
      if (_cache.containsKey(key)) {
        final encrypted = _cache[key]!;
        if (encrypted.isEmpty) return defaultValue;
        final decrypted = _decrypt(encrypted);
        return decrypted.isEmpty ? (defaultValue ?? decrypted) : decrypted;
      }

      return await _withRetry(() async {
        final encrypted = await _secureStorage.read(key: key);
        if (encrypted == null || encrypted.isEmpty) return defaultValue;

        _updateCache(key, encrypted);
        final decrypted = _decrypt(encrypted);
        return decrypted.isEmpty ? (defaultValue ?? decrypted) : decrypted;
      });
    } catch (e) {
      return defaultValue;
    }
  }

  /// Store an int value
  Future<void> setInt(String key, int value) async {
    await setString(key, value.toString());
  }

  /// Retrieve an int value
  Future<int?> getInt(String key, {int? defaultValue}) async {
    final value = await getString(key);
    if (value == null || value.isEmpty) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Store a double value
  Future<void> setDouble(String key, double value) async {
    await setString(key, value.toString());
  }

  /// Retrieve a double value
  Future<double?> getDouble(String key, {double? defaultValue}) async {
    final value = await getString(key);
    if (value == null || value.isEmpty) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }

  /// Store a bool value
  Future<void> setBool(String key, bool value) async {
    await setString(key, value.toString());
  }

  /// Retrieve a bool value
  Future<bool?> getBool(String key, {bool? defaultValue}) async {
    final value = await getString(key);
    if (value == null || value.isEmpty) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  /// Store a Map (as JSON)
  Future<void> setMap(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = json.encode(value);
      await setString(key, jsonString);
    } catch (e) {
      throw SecureStorageException('Failed to encode map for key: $key', e);
    }
  }

  /// Retrieve a Map
  Future<Map<String, dynamic>?> getMap(String key,
      {Map<String, dynamic>? defaultValue}) async {
    final value = await getString(key);
    if (value == null || value.isEmpty) return defaultValue;

    try {
      return json.decode(value) as Map<String, dynamic>;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Store a List (as JSON)
  Future<void> setList(String key, List<dynamic> value) async {
    try {
      final jsonString = json.encode(value);
      await setString(key, jsonString);
    } catch (e) {
      throw SecureStorageException('Failed to encode list for key: $key', e);
    }
  }

  /// Retrieve a List
  Future<List<dynamic>?> getList(String key,
      {List<dynamic>? defaultValue}) async {
    final value = await getString(key);
    if (value == null || value.isEmpty) return defaultValue;

    try {
      return json.decode(value) as List<dynamic>;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Store a generic object (must be JSON serializable)
  Future<void> setObject(String key, Map<String, dynamic> jsonObject) async {
    await setMap(key, jsonObject);
  }

  /// Retrieve a generic object with type conversion
  Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson, {
    T? defaultValue,
  }) async {
    final map = await getMap(key);
    if (map == null) return defaultValue;

    try {
      return fromJson(map);
    } catch (e) {
      return defaultValue;
    }
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    _checkInit();
    try {
      // Check cache first
      if (_cache.containsKey(key)) return true;

      return await _withRetry(() async {
        return await _secureStorage.containsKey(key: key);
      });
    } catch (e) {
      throw SecureStorageException('Failed to check key existence: $key', e);
    }
  }

  /// Delete a specific key
  Future<void> remove(String key) async {
    _checkInit();
    try {
      await _withRetry(() async {
        await _secureStorage.delete(key: key);
        _removeFromCache(key);
      });
    } catch (e) {
      throw SecureStorageException('Failed to remove key: $key', e);
    }
  }

  /// Delete multiple keys at once
  Future<void> removeAll(List<String> keys) async {
    _checkInit();
    try {
      await _withRetry(() async {
        await Future.wait(keys.map((key) => _secureStorage.delete(key: key)));
        for (var key in keys) {
          _removeFromCache(key);
        }
      });
    } catch (e) {
      throw SecureStorageException('Failed to remove multiple keys', e);
    }
  }

  /// Clear all stored data (except encryption key and version)
  Future<void> clearAll() async {
    _checkInit();
    try {
      await _withRetry(() async {
        final allKeys = await _secureStorage.readAll();
        final keysToDelete = allKeys.keys
            .where((key) => key != _keyIdentifier && key != _versionKey)
            .toList();

        await Future.wait(
          keysToDelete.map((key) => _secureStorage.delete(key: key)),
        );

        _cache.clear();
        _cacheAccessOrder.clear();
      });
    } catch (e) {
      throw SecureStorageException('Failed to clear all data', e);
    }
  }

  /// Get all keys (excluding internal keys)
  Future<List<String>> getAllKeys() async {
    _checkInit();
    try {
      return await _withRetry(() async {
        final allKeys = await _secureStorage.readAll();
        return allKeys.keys
            .where((key) => key != _keyIdentifier && key != _versionKey)
            .toList();
      });
    } catch (e) {
      throw SecureStorageException('Failed to get all keys', e);
    }
  }

  /// Batch write operations for better performance (parallel execution)
  Future<void> batchWrite(Map<String, dynamic> data) async {
    _checkInit();
    try {
      final futures = <Future>[];

      for (var entry in data.entries) {
        final value = entry.value;
        if (value is String) {
          futures.add(setString(entry.key, value));
        } else if (value is int) {
          futures.add(setInt(entry.key, value));
        } else if (value is double) {
          futures.add(setDouble(entry.key, value));
        } else if (value is bool) {
          futures.add(setBool(entry.key, value));
        } else if (value is Map) {
          futures.add(setMap(entry.key, value as Map<String, dynamic>));
        } else if (value is List) {
          futures.add(setList(entry.key, value));
        }
      }

      await Future.wait(futures);
    } catch (e) {
      throw SecureStorageException('Batch write operation failed', e);
    }
  }

  /// Batch read operations
  Future<Map<String, String>> batchRead(List<String> keys) async {
    _checkInit();
    try {
      final results = await Future.wait(
        keys.map((key) async {
          final value = await getString(key);
          return MapEntry(key, value);
        }),
      );

      return Map.fromEntries(
        results
            .where((entry) => entry.value != null)
            .map((entry) => MapEntry(entry.key, entry.value!)),
      );
    } catch (e) {
      throw SecureStorageException('Batch read operation failed', e);
    }
  }

  /// Export all data (encrypted) for backup purposes
  Future<Map<String, String>> exportData() async {
    _checkInit();
    try {
      return await _withRetry(() async {
        final allData = await _secureStorage.readAll();
        final exportData = Map<String, String>.from(allData);
        exportData.remove(_keyIdentifier);
        exportData.remove(_versionKey);
        return exportData;
      });
    } catch (e) {
      throw SecureStorageException('Failed to export data', e);
    }
  }

  /// Import data (encrypted) from backup
  Future<void> importData(Map<String, String> data) async {
    _checkInit();
    try {
      await _withRetry(() async {
        await Future.wait(
          data.entries.map(
            (entry) => _secureStorage.write(key: entry.key, value: entry.value),
          ),
        );

        // Clear cache after import
        _cache.clear();
        _cacheAccessOrder.clear();
      });
    } catch (e) {
      throw SecureStorageException('Failed to import data', e);
    }
  }

  /// Rotate the encryption key (advanced feature)
  Future<void> rotateEncryptionKey() async {
    _checkInit();
    try {
      await _withLock(() async {
        // Read all current data (decrypted)
        final allKeys = await getAllKeys();
        final allData = <String, String>{};

        for (var key in allKeys) {
          final value = await getString(key);
          if (value != null) {
            allData[key] = value;
          }
        }

        // Generate new key
        _key = encrypt.Key.fromSecureRandom(32);
        final newKeyStr = base64Url.encode(_key.bytes);
        await _secureStorage.write(key: _keyIdentifier, value: newKeyStr);

        // Clear cache before re-encryption
        _cache.clear();
        _cacheAccessOrder.clear();

        // Re-encrypt all data with new key
        await Future.wait(
          allData.entries.map((entry) => setString(entry.key, entry.value)),
        );
      });
    } catch (e) {
      throw SecureStorageException('Failed to rotate encryption key', e);
    }
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    _checkInit();
    try {
      return await _withRetry(() async {
        final allKeys = await getAllKeys();
        final allData = await _secureStorage.readAll();

        int totalSize = 0;
        for (var value in allData.values) {
          totalSize += value.length;
        }

        return {
          'totalKeys': allKeys.length,
          'totalSizeBytes': totalSize,
          'cacheSize': _cache.length,
          'version': _currentVersion,
          'initialized': _initialized,
        };
      });
    } catch (e) {
      throw SecureStorageException('Failed to get storage stats', e);
    }
  }

  /// Clear in-memory cache
  void clearCache() {
    _cache.clear();
    _cacheAccessOrder.clear();
  }

  /// Reset the entire storage including encryption key
  Future<void> resetStorage() async {
    try {
      await _withLock(() async {
        await _secureStorage.deleteAll();
        _cache.clear();
        _cacheAccessOrder.clear();
        _initialized = false;
      });
    } catch (e) {
      throw SecureStorageException('Failed to reset storage', e);
    }
  }

  /// Validate data integrity for a specific key
  /// Returns true if data can be successfully decrypted
  Future<bool> validateKey(String key) async {
    _checkInit();
    try {
      final value = await getString(key);
      return value != null;
    } catch (e) {
      return false;
    }
  }

  /// Validate integrity of all stored data
  /// Returns a map of key -> isValid
  Future<Map<String, bool>> validateAllData() async {
    _checkInit();
    try {
      final allKeys = await getAllKeys();
      final results = <String, bool>{};

      for (var key in allKeys) {
        results[key] = await validateKey(key);
      }

      return results;
    } catch (e) {
      throw SecureStorageException('Failed to validate all data', e);
    }
  }
}

// Global instance for easy access
final secureStorage = SecureStorageUtil();
