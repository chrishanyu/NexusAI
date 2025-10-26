//
//  ImageCacheService.swift
//  NexusAI
//
//  Created on 10/26/25.
//

import Foundation
import CryptoKit

/// Actor-based service for caching profile images locally
/// Uses file system storage with LRU eviction strategy
actor ImageCacheService {
    
    // MARK: - Singleton
    
    static let shared = ImageCacheService()
    
    // MARK: - Properties
    
    /// Directory for cached profile images
    private let cacheDirectory: URL
    
    /// Metadata file path (URL → filename mapping)
    private let metadataPath: URL
    
    /// In-memory metadata cache
    private var metadata: [String: CacheMetadata] = [:]
    
    /// Maximum cache size in bytes (100 MB)
    private let maxCacheSize: Int64 = 100 * 1024 * 1024
    
    // MARK: - Initialization
    
    private init() {
        // Setup cache directory
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("ProfileImages", isDirectory: true)
        self.metadataPath = cacheDirectory.appendingPathComponent("metadata.json")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load metadata from disk using nonisolated static method
        self.metadata = Self.loadMetadataFromDisk(at: metadataPath)
        
        print("✅ ImageCacheService: Initialized with cache directory: \(cacheDirectory.path)")
    }
    
    // MARK: - Public Methods
    
    /// Cache an image for a given URL
    /// - Parameters:
    ///   - data: Image data to cache
    ///   - url: Original image URL
    func cacheImage(_ data: Data, for url: String) async throws {
        let filename = generateFilename(for: url)
        let filePath = cacheDirectory.appendingPathComponent(filename)
        
        // Write image data to disk
        try data.write(to: filePath)
        
        // Update metadata
        let meta = CacheMetadata(
            url: url,
            filename: filename,
            lastAccess: Date(),
            fileSize: Int64(data.count)
        )
        metadata[url] = meta
        
        // Save metadata to disk
        saveMetadata()
        
        // Check if we need to prune cache
        let currentSize = await cacheSize()
        if currentSize > maxCacheSize {
            try await pruneCache(maxSize: maxCacheSize)
        }
        
        print("✅ ImageCacheService: Cached image for URL (size: \(data.count) bytes)")
    }
    
    /// Retrieve cached image for a URL
    /// - Parameter url: Image URL
    /// - Returns: Image data if cached, nil otherwise
    func getCachedImage(for url: String) async -> Data? {
        guard let meta = metadata[url] else {
            return nil
        }
        
        let filePath = cacheDirectory.appendingPathComponent(meta.filename)
        
        guard let data = try? Data(contentsOf: filePath) else {
            // File doesn't exist, remove from metadata
            metadata[url] = nil
            saveMetadata()
            return nil
        }
        
        // Update last access time
        metadata[url]?.lastAccess = Date()
        saveMetadata()
        
        print("✅ ImageCacheService: Cache hit for URL")
        return data
    }
    
    /// Check if image is cached
    /// - Parameter url: Image URL
    /// - Returns: True if cached, false otherwise
    func isCached(url: String) async -> Bool {
        guard let meta = metadata[url] else {
            return false
        }
        
        let filePath = cacheDirectory.appendingPathComponent(meta.filename)
        return FileManager.default.fileExists(atPath: filePath.path)
    }
    
    /// Get total cache size in bytes
    /// - Returns: Total size of all cached images
    func cacheSize() async -> Int64 {
        var totalSize: Int64 = 0
        
        for meta in metadata.values {
            totalSize += meta.fileSize
        }
        
        return totalSize
    }
    
    /// Clear entire cache
    func clearCache() async throws {
        // Remove all files
        let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            if url.lastPathComponent != "metadata.json" {
                try FileManager.default.removeItem(at: url)
            }
        }
        
        // Clear metadata
        metadata.removeAll()
        saveMetadata()
        
        print("✅ ImageCacheService: Cache cleared")
    }
    
    /// Prune cache using LRU strategy
    /// - Parameter maxSize: Maximum cache size in bytes
    func pruneCache(maxSize: Int64) async throws {
        let currentSize = await cacheSize()
        
        guard currentSize > maxSize else {
            print("ℹ️ ImageCacheService: Cache size within limit, no pruning needed")
            return
        }
        
        // Sort by last access (oldest first)
        let sortedEntries = metadata.values.sorted { $0.lastAccess < $1.lastAccess }
        
        var freedSpace: Int64 = 0
        var removedCount = 0
        
        // Remove oldest entries until we're under 80% of max size
        let targetSize = Int64(Double(maxSize) * 0.8)
        
        for entry in sortedEntries {
            guard currentSize - freedSpace > targetSize else {
                break
            }
            
            // Delete file
            let filePath = cacheDirectory.appendingPathComponent(entry.filename)
            try? FileManager.default.removeItem(at: filePath)
            
            // Remove from metadata
            metadata[entry.url] = nil
            
            freedSpace += entry.fileSize
            removedCount += 1
        }
        
        // Save updated metadata
        saveMetadata()
        
        print("✅ ImageCacheService: Pruned \(removedCount) entries, freed \(freedSpace) bytes")
    }
    
    // MARK: - Private Methods
    
    /// Generate filename from URL using SHA256 hash
    /// - Parameter url: Image URL
    /// - Returns: Hashed filename with extension
    private func generateFilename(for url: String) -> String {
        let hash = SHA256.hash(data: Data(url.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Preserve file extension if possible
        let urlObj = URL(string: url)
        let ext = urlObj?.pathExtension ?? "jpg"
        
        return "\(String(hashString.prefix(16))).\(ext)"
    }
    
    /// Load metadata from disk (nonisolated for use in init)
    /// - Parameter path: Path to metadata file
    /// - Returns: Dictionary of metadata
    private nonisolated static func loadMetadataFromDisk(at path: URL) -> [String: CacheMetadata] {
        guard let data = try? Data(contentsOf: path),
              let decoded = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    /// Save metadata to disk
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(metadata) else {
            print("⚠️ ImageCacheService: Failed to encode metadata")
            return
        }
        
        try? data.write(to: metadataPath)
    }
}

// MARK: - Cache Metadata

/// Metadata for a cached image
struct CacheMetadata: Codable {
    let url: String
    let filename: String
    var lastAccess: Date
    let fileSize: Int64
}

