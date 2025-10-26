//
//  LocalDatabase.swift
//  NexusAI
//
//  Created on 10/22/25.
//

import Foundation
import SwiftData

// MARK: - Notification Names

extension Notification.Name {
    static let localDatabaseDidChange = Notification.Name("localDatabaseDidChange")
}

/// Local database wrapper for SwiftData operations
/// Provides a clean interface for CRUD operations and reactive queries
@available(iOS 17.0, *)
@MainActor
class LocalDatabase {
    
    // MARK: - Singleton
    
    /// Shared singleton instance
    static let shared: LocalDatabase = {
        do {
            return try LocalDatabase()
        } catch {
            fatalError("Failed to initialize LocalDatabase: \(error.localizedDescription)")
        }
    }()
    
    // MARK: - Properties
    
    /// SwiftData model container
    private let modelContainer: ModelContainer
    
    /// SwiftData model context for database operations
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    /// Initialize the local database with SwiftData schema
    /// - Throws: Error if ModelContainer initialization fails
    private init() throws {
        // Define the schema with all local models
        let schema = Schema([
            LocalMessage.self,
            LocalConversation.self,
            LocalUser.self,
            LocalAIMessage.self,
            LocalAIConversation.self,
            LocalActionItem.self
        ])
        
        // Create model configuration
        // isStoredInMemoryOnly: false means data persists to disk
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        // Initialize container
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        
        // Create main context
        self.modelContext = ModelContext(modelContainer)
        
        // Enable automatic save (for convenience)
        self.modelContext.autosaveEnabled = true
        
        print("✅ LocalDatabase initialized successfully")
    }
    
    /// Initialize for testing with in-memory storage
    /// - Parameter inMemory: Whether to use in-memory storage (default: false)
    init(inMemory: Bool = false) throws {
        let schema = Schema([
            LocalMessage.self,
            LocalConversation.self,
            LocalUser.self,
            LocalAIMessage.self,
            LocalAIConversation.self,
            LocalActionItem.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
        
        print("✅ LocalDatabase initialized \(inMemory ? "(in-memory)" : "")")
    }
    
    // MARK: - Context Access
    
    /// Get the model context (for advanced operations)
    var context: ModelContext {
        return modelContext
    }
    
    /// Save any pending changes to disk
    /// - Throws: Error if save fails
    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
    
    /// Rollback any unsaved changes
    func rollback() {
        modelContext.rollback()
    }
    
    // MARK: - Generic CRUD Operations
    
    /// Insert a new entity into the database
    /// - Parameter entity: The entity to insert
    /// - Throws: DatabaseError if insertion fails
    func insert<T: PersistentModel>(_ entity: T) throws {
        do {
            modelContext.insert(entity)
            try save()
        } catch {
            throw DatabaseError.insertFailed(error.localizedDescription)
        }
    }
    
    /// Insert multiple entities into the database
    /// - Parameter entities: Array of entities to insert
    /// - Throws: DatabaseError if insertion fails
    func insertBatch<T: PersistentModel>(_ entities: [T]) throws {
        do {
            for entity in entities {
                modelContext.insert(entity)
            }
            try save()
        } catch {
            throw DatabaseError.insertFailed(error.localizedDescription)
        }
    }
    
    /// Update an existing entity in the database
    /// - Parameter entity: The entity to update (must already exist in context)
    /// - Throws: DatabaseError if update fails
    func update<T: PersistentModel>(_ entity: T) throws {
        do {
            // Entity is already in context, just save changes
            try save()
        } catch {
            throw DatabaseError.updateFailed(error.localizedDescription)
        }
    }
    
    /// Delete an entity from the database
    /// - Parameter entity: The entity to delete
    /// - Throws: DatabaseError if deletion fails
    func delete<T: PersistentModel>(_ entity: T) throws {
        do {
            modelContext.delete(entity)
            try save()
        } catch {
            throw DatabaseError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// Delete multiple entities from the database
    /// - Parameter entities: Array of entities to delete
    /// - Throws: DatabaseError if deletion fails
    func deleteBatch<T: PersistentModel>(_ entities: [T]) throws {
        do {
            for entity in entities {
                modelContext.delete(entity)
            }
            try save()
        } catch {
            throw DatabaseError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// Fetch all entities of a specific type with optional sorting
    /// - Parameters:
    ///   - type: The type of entity to fetch
    ///   - sortBy: Optional array of sort descriptors
    ///   - limit: Optional limit on number of results
    /// - Returns: Array of entities
    /// - Throws: DatabaseError if fetch fails
    func fetch<T: PersistentModel>(
        _ type: T.Type,
        sortBy: [SortDescriptor<T>] = [],
        limit: Int? = nil
    ) throws -> [T] {
        do {
            var descriptor = FetchDescriptor<T>(sortBy: sortBy)
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            return try modelContext.fetch(descriptor)
        } catch {
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch entities matching a predicate
    /// - Parameters:
    ///   - type: The type of entity to fetch
    ///   - predicate: Predicate to filter results
    ///   - sortBy: Optional array of sort descriptors
    ///   - limit: Optional limit on number of results
    /// - Returns: Array of matching entities
    /// - Throws: DatabaseError if fetch fails
    func fetch<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>,
        sortBy: [SortDescriptor<T>] = [],
        limit: Int? = nil
    ) throws -> [T] {
        do {
            var descriptor = FetchDescriptor<T>(
                predicate: predicate,
                sortBy: sortBy
            )
            if let limit = limit {
                descriptor.fetchLimit = limit
            }
            return try modelContext.fetch(descriptor)
        } catch {
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch a single entity matching a predicate
    /// - Parameters:
    ///   - type: The type of entity to fetch
    ///   - predicate: Predicate to filter results
    /// - Returns: The first matching entity, or nil if none found
    /// - Throws: DatabaseError if fetch fails
    func fetchOne<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>
    ) throws -> T? {
        do {
            var descriptor = FetchDescriptor<T>(predicate: predicate)
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first
        } catch {
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Count entities matching a predicate
    /// - Parameters:
    ///   - type: The type of entity to count
    ///   - predicate: Optional predicate to filter results
    /// - Returns: Number of matching entities
    /// - Throws: DatabaseError if count fails
    func count<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>? = nil
    ) throws -> Int {
        do {
            let descriptor: FetchDescriptor<T>
            if let predicate = predicate {
                descriptor = FetchDescriptor<T>(predicate: predicate)
            } else {
                descriptor = FetchDescriptor<T>()
            }
            return try modelContext.fetchCount(descriptor)
        } catch {
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Delete all entities of a specific type matching a predicate
    /// - Parameters:
    ///   - type: The type of entity to delete
    ///   - predicate: Predicate to filter which entities to delete
    /// - Throws: DatabaseError if deletion fails
    func deleteAll<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>
    ) throws {
        do {
            let entities = try fetch(type, where: predicate)
            try deleteBatch(entities)
        } catch {
            throw DatabaseError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Manual Refresh Notification
    
    /// Post a notification to trigger repository observers to refresh
    /// Call this after making updates that should propagate to observers immediately
    func notifyChanges() {
        // Post notification on main actor to trigger observers
        Task { @MainActor in
            NotificationCenter.default.post(name: .localDatabaseDidChange, object: nil)
        }
    }
    
    // MARK: - Reactive Queries (AsyncStream)
    
    /// Observe entities with real-time updates using AsyncStream
    /// - Parameters:
    ///   - type: The type of entity to observe
    ///   - predicate: Optional predicate to filter results
    ///   - sortBy: Optional array of sort descriptors
    /// - Returns: AsyncStream that emits arrays of entities whenever they change
    func observe<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = []
    ) -> AsyncStream<[T]> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                // Initial fetch
                do {
                    let initial: [T]
                    if let predicate = predicate {
                        initial = try fetch(type, where: predicate, sortBy: sortBy)
                    } else {
                        initial = try fetch(type, sortBy: sortBy)
                    }
                    continuation.yield(initial)
                } catch {
                    print("❌ LocalDatabase observe initial fetch failed: \(error)")
                    continuation.yield([])
                }
                
                // Listen to change notifications (event-driven, not polling)
                // Repositories and SyncEngine call database.notifyChanges() after writes
                for await _ in NotificationCenter.default.notifications(named: .localDatabaseDidChange) {
                    guard !Task.isCancelled else { break }
                    
                    do {
                        let updated: [T]
                        if let predicate = predicate {
                            updated = try fetch(type, where: predicate, sortBy: sortBy)
                        } else {
                            updated = try fetch(type, sortBy: sortBy)
                        }
                        continuation.yield(updated)
                    } catch {
                        print("❌ LocalDatabase observe update fetch failed: \(error)")
                    }
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Observe a single entity with real-time updates
    /// - Parameters:
    ///   - type: The type of entity to observe
    ///   - predicate: Predicate to identify the entity
    /// - Returns: AsyncStream that emits the entity whenever it changes
    func observeOne<T: PersistentModel>(
        _ type: T.Type,
        where predicate: Predicate<T>
    ) -> AsyncStream<T?> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                // Initial fetch
                do {
                    let initial = try fetchOne(type, where: predicate)
                    continuation.yield(initial)
                } catch {
                    print("❌ LocalDatabase observeOne initial fetch failed: \(error)")
                    continuation.yield(nil)
                }
                
                // Listen to change notifications (event-driven, not polling)
                for await _ in NotificationCenter.default.notifications(named: .localDatabaseDidChange) {
                    guard !Task.isCancelled else { break }
                    
                    do {
                        let updated = try fetchOne(type, where: predicate)
                        continuation.yield(updated)
                    } catch {
                        print("❌ LocalDatabase observeOne update fetch failed: \(error)")
                    }
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Database Errors

/// Errors that can occur during database operations
enum DatabaseError: LocalizedError {
    case initializationFailed(String)
    case insertFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case fetchFailed(String)
    case saveFailed(String)
    case entityNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Database initialization failed: \(message)"
        case .insertFailed(let message):
            return "Insert operation failed: \(message)"
        case .updateFailed(let message):
            return "Update operation failed: \(message)"
        case .deleteFailed(let message):
            return "Delete operation failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch operation failed: \(message)"
        case .saveFailed(let message):
            return "Save operation failed: \(message)"
        case .entityNotFound(let message):
            return "Entity not found: \(message)"
        }
    }
}

