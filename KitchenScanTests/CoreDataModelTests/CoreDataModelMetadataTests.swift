//
//  CoreDataModelMetadataTests.swift
//  CoreDataModelMetadataTests
//
//  Created by Ilya on 12.09.2025.
//

import XCTest
import CoreData
@testable import KitchenScan

final class CoreDataModelMetadataTests: XCTestCase {
    func test_modelMetadata_isValid() throws {
        // 1) проверка на корректность названия модели KitchenScan
        let url = Bundle.main.url(forResource: "KitchenScan", withExtension: "momd")
        XCTAssertNotNil(url, "Проверь, что .xcdatamodeld называется KitchenScan")
        
        // 2) проверка существования сущности KitchenItem
        let model = NSManagedObjectModel(contentsOf: url!)!
        let entity = model.entitiesByName["KitchenItem"]
        XCTAssertNotNil(entity, "Нет сущности KitchenItem")
        
        // 3) проверка уникальности barcode
        let barcode = entity!.attributesByName["barcode"]
        XCTAssertEqual(barcode?.attributeType, .stringAttributeType)
        XCTAssertEqual(barcode?.isOptional, false)
        
        let uc = entity!.uniquenessConstraints as? [[String]]
        XCTAssertTrue(uc?.contains(where: { $0 == ["barcode"] }) == true,
                      "Должен быть unique по barcode")
    }
}
