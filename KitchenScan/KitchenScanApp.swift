//
//  KitchenScanApp.swift
//  KitchenScan
//
//  Created by Ilya on 07.09.2025.
//

import SwiftUI

@main
struct KitchenScanApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
