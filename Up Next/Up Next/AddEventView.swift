//
//  Events.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UserNotifications
import WidgetKit // Add this import

struct AddEventView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showAddEventSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var selectedColor: CodableColor // Use CodableColor to store color
    @Binding var notificationsEnabled: Bool // New binding for notificationsEnabled
    @EnvironmentObject var appData: AppData
    @FocusState private var isTitleFocused: Bool // Add this line to manage focus state
    @State private var repeatOption: RepeatOption = .never // Changed from .none to .never
    @State private var repeatUntil: Date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
    @State private var repeatUntilOption: RepeatUntilOption = .indefinitely // New state variable
    @State private var repeatCount: Int = 1 // New state variable for number of repetitions
    @State private var showCategoryManagementView = false // Add this state variable

    var body: some View {
        NavigationView {
            EventForm(
                newEventTitle: $newEventTitle,
                newEventDate: $newEventDate,
                newEventEndDate: $newEventEndDate,
                showEndDate: $showEndDate,
                selectedCategory: $selectedCategory,
                selectedColor: $selectedColor,
                notificationsEnabled: $notificationsEnabled,
                repeatOption: $repeatOption,
                repeatUntil: $repeatUntil,
                repeatUntilOption: $repeatUntilOption,
                repeatCount: $repeatCount,
                showCategoryManagementView: $showCategoryManagementView
            )
            .environmentObject(appData)
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showAddEventSheet = false
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveNewEvent()
                        showAddEventSheet = false
                    }) {
                        Group {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(getCategoryColor())
                                    .frame(width: 60, height: 32)
                                Text("Add")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(newEventTitle.isEmpty ? 0.3 : 1.0)
                    }
                    .disabled(newEventTitle.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showCategoryManagementView) {
            NavigationView {
                CategoriesView()
                    .environmentObject(appData)
            }
            .presentationDetents([.medium, .large], selection: .constant(.medium))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
            if selectedCategory == nil {
                selectedCategory = "None" // Set default category to "None"
            }
        }
        .onDisappear {
            isTitleFocused = false
        }
    }

    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
        }
    }

    func saveNewEvent() {
        let repeatUntilDate: Date?
        switch repeatUntilOption {
        case .indefinitely:
            repeatUntilDate = nil
        case .after:
            repeatUntilDate = calculateRepeatUntilDate(for: repeatOption, from: newEventDate, count: repeatCount)
        case .onDate:
            repeatUntilDate = repeatUntil
        }

        let newEvent = Event(
            title: newEventTitle,
            date: newEventDate,
            endDate: showEndDate ? newEventEndDate : nil,
            color: selectedColor,
            category: selectedCategory,
            notificationsEnabled: notificationsEnabled,
            repeatOption: repeatOption,
            repeatUntil: repeatUntilDate
        )

        // Create new events based on the repeat options
        let newEvents = generateRepeatingEvents(for: newEvent)
        events.append(contentsOf: newEvents)

        saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }

    func calculateRepeatUntilDate(for option: RepeatOption, from startDate: Date, count: Int) -> Date? {
        switch option {
        case .never:
            return nil
        case .daily:
            return Calendar.current.date(byAdding: .day, value: count - 1, to: startDate)
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: count - 1, to: startDate)
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: count - 1, to: startDate)
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: count - 1, to: startDate)
        }
    }

    func generateRepeatingEvents(for event: Event) -> [Event] {
        var repeatingEvents = [Event]()
        var currentEvent = event
        repeatingEvents.append(currentEvent)
        
        var repetitionCount = 1
        let maxRepetitions: Int
        
        switch repeatUntilOption {
        case .indefinitely:
            maxRepetitions = 100 // Set a reasonable upper limit to prevent crashes
        case .after:
            maxRepetitions = repeatCount
        case .onDate:
            maxRepetitions = 100 // Set a reasonable upper limit to prevent crashes
        }
        
        print("Generating repeating events for \(event.title)")
        print("Repeat option: \(event.repeatOption)")
        print("Repeat until: \(String(describing: event.repeatUntil))")
        print("Max repetitions: \(maxRepetitions)")
        
        while let nextDate = getNextRepeatDate(for: currentEvent), 
              nextDate <= (event.repeatUntil ?? Date.distantFuture), 
              repetitionCount < maxRepetitions {
            currentEvent = Event(
                title: event.title,
                date: nextDate,
                endDate: event.endDate,
                color: event.color,
                category: event.category,
                notificationsEnabled: event.notificationsEnabled,
                repeatOption: event.repeatOption,
                repeatUntil: event.repeatUntil
            )
            repeatingEvents.append(currentEvent)
            repetitionCount += 1
            
            print("Added event on \(nextDate)")
        }
        
        print("Generated \(repeatingEvents.count) events")
        return repeatingEvents
    }

    func getNextRepeatDate(for event: Event) -> Date? {
        switch event.repeatOption {
        case .never:
            return nil
        case .daily:
            return Calendar.current.date(byAdding: .day, value: 1, to: event.date)
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: event.date)
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: 1, to: event.date)
        case .yearly:
            return Calendar.current.date(byAdding: .year, value: 1, to: event.date)
        }
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            // print("Saved events: \(events)")
        } else {
            print("Failed to encode events.")
        }
    }
    
    // Helper function to get the color of the selected category
    func getCategoryColor() -> Color {
        if let selectedCategory = selectedCategory,
           let category = appData.categories.first(where: { $0.name == selectedCategory }) {
            return category.color // Assuming category.color is of type Color
        }
        return Color.blue // Default color if no category is selected
    }
    
}

// Helper function to hide the keyboard
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

enum RepeatUntilOption: String, CaseIterable {
    case indefinitely = "Never" // Changed from "Indefinitely" to "Never"
    case after = "After"
    case onDate = "On"
}

// Custom date formatter
private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM, d, yyyy"
    return formatter
}