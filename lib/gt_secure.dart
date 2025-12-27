/// GT Secure - Production-Ready Secure Storage for Flutter
///
/// A high-performance, encrypted local storage solution featuring:
/// - AES-256-CBC encryption with unique IVs per encryption
/// - Automatic encryption key management and rotation
/// - Type-safe storage (String, int, bool, double, Map, List)
/// - In-memory caching with LRU eviction
/// - Thread-safe operations with locks
/// - App reinstallation detection and cleanup
/// - Comprehensive error handling with custom exceptions
library;

export 'secure_storage/secure_storage_utils.dart'
    show SecureStorageUtil, SecureStorageException, secureStorage;
