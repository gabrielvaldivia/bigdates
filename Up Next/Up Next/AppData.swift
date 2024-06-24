//
//  AppData.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

struct Event: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var endDate: Date?
    var color: String // Store color as a String
    var category: String? // New property for category, now optional
}

struct CategoryData: Codable {
    var name: String
    var color: String // Store color as a hex string
}

class AppData: ObservableObject {
    @Published var categories: [(name: String, color: Color)] = []

    func loadCategories() {
        let decoder = JSONDecoder()
        if let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "categories"),
           let decoded = try? decoder.decode([CategoryData].self, from: data) {
            self.categories = decoded.map { CategoryData in
                let color = Color(UIColor(hex: CategoryData.color) ?? UIColor.gray)
                return (name: CategoryData.name, color: color)
            }
            print("Categories loaded successfully.")
        } else {
            print("Failed to load categories.")
            // Set a default category if categories fail to load
            self.categories = [("Work", .blue)] // Default to "Work" if nothing is loaded
        }
    }
}