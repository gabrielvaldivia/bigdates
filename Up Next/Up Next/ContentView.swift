//
//  ContentView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import Foundation


struct ContentView: View {
    @State private var events: [Event] = []
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var newEventEndDate: Date = Date()
    @State private var showAddEventSheet: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var selectedEvent: Event?
    @State private var showEndDate: Bool = false
    @State private var showPastEventsSheet: Bool = false // State for showing past events
    @State private var selectedCategoryFilter: String? = nil // State to track selected category for filtering
    @State private var showCategoryManagementView: Bool = false // State to show category management view
    @State private var selectedColor: String = "Black" // Default color set to Black
    @State private var selectedCategory: String? = nil // Default category set to nil

    @EnvironmentObject var appData: AppData
    @Environment(\.colorScheme) var colorScheme // Inject the color scheme environment variable

    let itemDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
         NavigationView {
            ZStack(alignment: .bottom) {
                VStack {
                    
                    // Category Pills
                    let filteredCategories = appData.categories.filter { category in
                        let startOfToday = Calendar.current.startOfDay(for: Date())
                        return events.contains { event in
                            event.category == category.name && event.date >= startOfToday
                        }
                    }
                    
                    if filteredCategories.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(filteredCategories, id: \.name) { category in
                                    Button(action: {
                                        self.selectedCategoryFilter = self.selectedCategoryFilter == category.name ? nil : category.name
                                    }) {
                                        Text(category.name)
                                            .font(.footnote)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(self.selectedCategoryFilter == category.name ? category.color : Color.clear) // Change background color based on selection
                                            .foregroundColor(self.selectedCategoryFilter == category.name ? .white : (colorScheme == .dark ? .white : .black)) // Adjust foreground color based on color scheme
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.gray, lineWidth: 1) // Gray border for all
                                            )
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                    
                    // List of events
                    let groupedEvents = Dictionary(grouping: filteredEvents().sorted(by: { $0.date < $1.date }), by: { $0.date.relativeDate() })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key2)))
                        return date1 < date2
                    }
                    if sortedKeys.isEmpty {
                        VStack {
                            Spacer()
                            Text("No upcoming events")
                                .font(.headline)
                            Text("Add something you're looking forward to")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(sortedKeys, id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key.uppercased())
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.gray) 
                                        .frame(width: 100, alignment: .leading) 
                                        .padding(.vertical, 14)
                                    VStack(alignment: .leading) {
                                        ForEach(groupedEvents[key]!, id: \.id) { event in
                                            EventRow(event: event, formatter: itemDateFormatter,
                                                     selectedEvent: $selectedEvent,
                                                     newEventTitle: $newEventTitle,
                                                     newEventDate: $newEventDate,
                                                     newEventEndDate: $newEventEndDate,
                                                     showEndDate: $showEndDate,
                                                     selectedCategory: $selectedCategory,
                                                     categories: appData.categories)
                                                .onTapGesture { // Add tap gesture to open EditEventView
                                                    self.selectedEvent = event
                                                    self.newEventTitle = event.title
                                                    self.newEventDate = event.date
                                                    self.newEventEndDate = event.endDate ?? Date()
                                                    self.showEndDate = event.endDate != nil
                                                    self.selectedCategory = event.category
                                                    self.showEditSheet = true
                                                }
                                                .listRowSeparator(.hidden) // Hide dividers
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .listRowSeparator(.hidden)
                    }
                }

                // Navigation Bar
                .navigationTitle("Events")
                .navigationBarItems(
                    leading: Button(action: {
                        self.showPastEventsSheet = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath") // Icon for past events
                            .bold() 
                    },
                    trailing: Button(action: {
                        self.showCategoryManagementView = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .bold()
                    }
                )
                .onAppear {
                    loadEvents()
                    appData.loadCategories() // Load categories from UserDefaults
                }

                // Add event Button
                Button(action: {
                    self.newEventTitle = ""
                    self.newEventDate = Date()
                    self.newEventEndDate = Date()
                    self.showEndDate = false
                    self.selectedCategory = appData.defaultCategory // Set the default category to the selected default category
                    self.showAddEventSheet = true // This will now trigger the bottom sheet
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .bold() // Make the icon thicker
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(40)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }

        // Add Event Sheet
        .sheet(isPresented: $showAddEventSheet) {
            AddEventView(events: $events, selectedEvent: $selectedEvent, newEventTitle: $newEventTitle, newEventDate: $newEventDate, newEventEndDate: $newEventEndDate, showEndDate: $showEndDate, showAddEventSheet: $showAddEventSheet, selectedCategory: $selectedCategory, selectedColor: $selectedColor, appData: _appData)
        }

        // Edit Event Sheet
        .sheet(isPresented: $showEditSheet) {
            EditEventView(
                events: $events,
                selectedEvent: $selectedEvent,
                newEventTitle: $newEventTitle,
                newEventDate: $newEventDate,
                newEventEndDate: $newEventEndDate,
                showEndDate: $showEndDate,
                showEditSheet: $showEditSheet,
                selectedCategory: $selectedCategory,
                selectedColor: $selectedColor,
                saveEvent: saveEvent // Provide the saveEvent function
            )
        }

        // Past events Sheet
        .sheet(isPresented: $showPastEventsSheet) {
            PastEventsView(events: $events, selectedEvent: $selectedEvent, newEventTitle: $newEventTitle, newEventDate: $newEventDate, newEventEndDate: $newEventEndDate, showEndDate: $showEndDate, selectedCategory: $selectedCategory, showPastEventsSheet: $showPastEventsSheet, showEditSheet: $showEditSheet, selectedColor: $selectedColor, categories: appData.categories, itemDateFormatter: itemDateFormatter, saveEvents: saveEvents)
                .environmentObject(appData)
        }

        // Categories Sheet
        .sheet(isPresented: $showCategoryManagementView) {
            CategoriesView()
                .environmentObject(appData)
        }
    }

    func filteredEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var allEvents = [Event]()

        for event in events {
            if let filter = selectedCategoryFilter {
                if event.category == filter && (event.date >= startOfToday || (event.endDate != nil && event.date < startOfToday && event.endDate! >= startOfToday)) {
                    allEvents.append(event)
                }
            } else {
                if event.date >= startOfToday || (event.endDate != nil && event.date < startOfToday && event.endDate! >= startOfToday) {
                    allEvents.append(event)
                }
            }
        }

        return allEvents.sorted { $0.date < $1.date }
    }

    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
            saveEvents()  // Save after deleting
        }
    }

      
    // Load events from UserDefaults
    func loadEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            events = decoded
            print("Loaded events: \(events)")
        } else {
            print("No events found in shared UserDefaults.")
        }
    }

    // Save events to UserDefaults
    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            print("Saved events: \(events)")
        } else {
            print("Failed to encode events.")
        }
    }
    
    func saveEvent() {
        if let selectedEvent = selectedEvent,
           let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            events[index].endDate = showEndDate ? newEventEndDate : nil
            events[index].category = selectedCategory
            events[index].color = selectedColor
            saveEvents()
        }
        showEditSheet = false
    }
}

// Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppData())
    }
}

