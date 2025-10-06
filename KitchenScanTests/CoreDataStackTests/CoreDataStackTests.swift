//
//  CoreDataStackTests.swift
//  KitchenScanTests
//
//  Created by Ilya on 06.10.2025.
//

import XCTest
import CoreData
@testable import KitchenScan

final class CoreDataStackTests: XCTestCase {

    // MARK: - Temporary directories
    
    private var tmpDirs: [URL] = []

    // MARK: - Lifecycle
    
    override func tearDown() {
        super.tearDown()
        // Удаляем созданные временные каталоги/файлы
        let fm = FileManager.default
        tmpDirs.forEach { try? fm.removeItem(at: $0) }
        tmpDirs.removeAll()
    }

    // MARK: - Tests

    func test_inMemory_initializesAndHasExpectedPolicies() throws {
        let stack = try makeInMemoryStack()
        let viewContext = stack.viewContext
        
        guard let policy = viewContext.mergePolicy as? NSMergePolicy else {
                   return XCTFail("mergePolicy is not NSMergePolicy")
        }

        XCTAssertEqual(policy.mergeType, NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType)
        XCTAssertTrue(viewContext.automaticallyMergesChangesFromParent)
        XCTAssertNil(viewContext.undoManager)
    }

    func test_newBackgroundContext_inheritsKeySettings() throws {
        let stack = try makeInMemoryStack()
        let bg = stack.newBackgroundContext()

        guard let policy = bg.mergePolicy as? NSMergePolicy else {
                   return XCTFail("bg.mergePolicy is not NSMergePolicy")
        }
        
        XCTAssertEqual(policy.mergeType, NSMergePolicyType.mergeByPropertyObjectTrumpMergePolicyType)
        XCTAssertTrue(bg.automaticallyMergesChangesFromParent)
        XCTAssertNil(bg.undoManager)
    }

    func test_performWrite_savesWhenThereAreChanges_andDoesNotThrowWhenNoChanges() async throws {
        let (stack, _, _) = try makeIsolatedSQLiteStack()
        // 1) Объект должен сохранится при вызове performWrite на background context
        let inserted: Bool = try await stack.performWrite { ctx in
            guard let entity = NSEntityDescription.entity(forEntityName: "KitchenItem", in: ctx) else {
                throw XCTSkip("Entity 'KitchenItem' is missing in the test model")
            }
            _ = NSManagedObject(entity: entity, insertInto: ctx)
            return true
        }
        XCTAssertTrue(inserted)

        // Проверяем, что запись действительно попала в store
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "KitchenItem")
        let count = try stack.viewContext.count(for: fetch)
        XCTAssertEqual(count, 1, "Expected exactly 1 object saved by performWrite")

        // 2) Пустая транзакция не должна падать
        let ok: Bool = try await stack.performWrite { _ in true }
        XCTAssertTrue(ok)
    }

    func test_sqlite_store_usesProvidedURL() throws {
        let (stack, _, providedURL) = try makeIsolatedSQLiteStack()
        // Читаем фактический URL стора из координатора
        let storeURL = stack.container.persistentStoreCoordinator.persistentStores.first?.url
        XCTAssertEqual(storeURL?.standardizedFileURL, providedURL.standardizedFileURL)
    }

    func test_sqlite_store_defaultsToApplicationSupportWhenURLIsNil() throws {
        let modelName = "KitchenScan"
        let stack = try CoreDataStack(modelName: modelName, kind: .sqlite(nil))

        guard let actualURL = stack.container.persistentStoreCoordinator.persistentStores.first?.url else {
            return XCTFail("Persistent store URL is missing")
        }

        // Воспроизводим ожидаемый путь так же, как в прод-коде (метод defaultSQLiteURL из CoreDataStack):
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let expectedDir = base.appendingPathComponent(modelName, isDirectory: true)
        let expectedURL = expectedDir.appendingPathComponent("\(modelName).sqlite")

        XCTAssertEqual(actualURL.standardizedFileURL, expectedURL.standardizedFileURL)

        // Папка должна существовать и быть директорией
        var isDir: ObjCBool = false
        XCTAssertTrue(fm.fileExists(atPath: expectedDir.path, isDirectory: &isDir) && isDir.boolValue)
    }
    
    // MARK: - Helpers

    // Создание изолированного CoreDataStack c SQLite в уникальном временном каталоге.
    private func makeIsolatedSQLiteStack(modelName: String = "KitchenScan") throws -> (stack: CoreDataStack, dir: URL, storeURL: URL) {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        tmpDirs.append(dir)
        let storeURL = dir.appendingPathComponent("store.sqlite")
        let stack = try CoreDataStack(modelName: modelName, kind: .sqlite(storeURL))
        return (stack, dir, storeURL)
    }

    private func makeInMemoryStack(modelName: String = "KitchenScan") throws -> CoreDataStack {
        try CoreDataStack(modelName: modelName, kind: .inMemory)
    }
}
