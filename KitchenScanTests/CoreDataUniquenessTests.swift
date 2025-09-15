//
//  CoreDataUniquenessTests.swift
//  KitchenScanTests
//
//  Created by Ilya on 13.09.2025.
//

import XCTest
import CoreData
@testable import KitchenScan

final class CoreDataUniquenessTests: XCTestCase {
    private func makeSQLiteContainer() throws -> (NSPersistentContainer, URL) {
        let url  =
        Bundle.main.url(forResource: "KitchenScan", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: url)!
        
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KS-\(UUID().uuidString).sqlite")
        
        let desc = NSPersistentStoreDescription(url: storeURL)
        desc.type = NSSQLiteStoreType
        desc.shouldAddStoreAsynchronously = false
        desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        let container = NSPersistentContainer(name: "KitchenScan", managedObjectModel: model)
        container.persistentStoreDescriptions = [desc]
        
        var loadErr: Error?
        container.loadPersistentStores { _, e in loadErr = e }
        XCTAssertNil(loadErr)
        
        return (container, storeURL)
    }
    
    func test_entities_withSameBarcode_noExist() throws {
        let (container, storeURL) = try makeSQLiteContainer()
        defer {
            // в конце удаляем базу + журналы
            let fm = FileManager.default
            try? fm.removeItem(at: storeURL)
            try? fm.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            try? fm.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
        }
        
        let barcode = "4601234567890"
        
        // ctx1: базовая запись
        let ctx1 = container.newBackgroundContext()
        try ctx1.performAndWait {
            let e = NSEntityDescription.insertNewObject(forEntityName: "KitchenItem", into: ctx1)
            e.setValue(barcode, forKey: "barcode")
            e.setValue("Молоко", forKey: "name")
            e.setValue(1.0,      forKey: "count")
            e.setValue("pcs",    forKey: "unit")
            e.setValue(Int16(0), forKey: "locationRaw")
            try ctx1.save()
        }
        
        // ctx2: запись с тем же barcode
        let ctx2 = container.newBackgroundContext()
        ctx2.mergePolicy = NSErrorMergePolicy
        
        XCTAssertThrowsError(try ctx2.performAndWait {
            let e = NSEntityDescription.insertNewObject(forEntityName: "KitchenItem", into: ctx2)
            e.setValue(barcode, forKey: "barcode")
            e.setValue("Новое имя", forKey: "name")
            e.setValue(3.0,         forKey: "count")
            e.setValue("pcs",       forKey: "unit")
            e.setValue(Int16(0),    forKey: "locationRaw")
            try ctx2.save() // здесь должна быть выкинута ошибка, иначе уникальность не работает
        }, "Ожидалась ошибка уникальности по barcode") { _ in
            ctx2.rollback()
        }
        
        // Также проверяем существующее кол-во записей (без pending changes)
        let viewCtx = container.viewContext
        let req = NSFetchRequest<NSManagedObject>(entityName: "KitchenItem")
        req.predicate = NSPredicate(format: "barcode == %@", barcode)
        req.includesPendingChanges = false
        let rows = try viewCtx.fetch(req)
        XCTAssertEqual(rows.count, 1)
    }
}
