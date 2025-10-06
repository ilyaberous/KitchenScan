//
//  CoreDataStack.swift
//  KitchenScan
//
//  Created by Ilya on 16.09.2025.
//

import Foundation
import CoreData

public enum CoreDataStoreKind {
    case inMemory
    case sqlite(URL?)
}

public final class CoreDataStack {
    // MARK: - Properties
    
    public let container: NSPersistentContainer
    public var viewContext: NSManagedObjectContext { container.viewContext }
    
    // MARK: - Init

    public init(modelName: String = "KitchenScan", kind: CoreDataStoreKind) throws {
        let modelURL =
            Bundle.main.url(forResource: modelName, withExtension: "momd")
            ?? Bundle(for: CoreDataStack.self).url(forResource: modelName, withExtension: "momd")
        
        guard let modelURL, let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(domain: "CoreDataStack",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Не найдена модель \(modelName).momd"])
        }

        container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        let desc = makeStoreDescription(modelName: modelName, kind: kind)
        container.persistentStoreDescriptions = [desc]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let error = loadError { throw error }

        configure(viewContext: container.viewContext)
    }
    
    // MARK: - Public Methods
    
    public func newBackgroundContext() -> NSManagedObjectContext {
        newBackgroundContext(mergePolicy: .mergeByPropertyObjectTrump)
    }

    public func newBackgroundContext(mergePolicy: NSMergePolicy) -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.name = "CoreDataStack.bg"
        ctx.mergePolicy = mergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        ctx.undoManager = nil
        return ctx
    }

    @discardableResult
    public func performWrite<T>(
        mergePolicy: NSMergePolicy = .mergeByPropertyObjectTrump,
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let ctx = newBackgroundContext(mergePolicy: mergePolicy)
        return try await ctx.perform {
            let result = try block(ctx)
            if ctx.hasChanges { try ctx.save() }
            return result
        }
    }

    // MARK: - Private Methods

    private func configure(viewContext: NSManagedObjectContext) {
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.shouldDeleteInaccessibleFaults = true
        viewContext.undoManager = nil
    }
    
    private func makeStoreDescription(modelName: String, kind: CoreDataStoreKind) -> NSPersistentStoreDescription {
        let desc: NSPersistentStoreDescription
        switch kind {
        case .inMemory:
            desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
        case .sqlite(let customURL):
            let url = customURL ?? Self.defaultSQLiteURL(modelName: modelName)
            desc = NSPersistentStoreDescription(url: url)
            desc.type = NSSQLiteStoreType
            desc.shouldAddStoreAsynchronously = false
        }

        desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        return desc
    }

    private static func defaultSQLiteURL(modelName: String) -> URL {
        let fm = FileManager.default
        let base = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent(modelName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("\(modelName).sqlite")
    }

}
