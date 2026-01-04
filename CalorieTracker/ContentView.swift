//
//  ContentView.swift
//  CalorieTracker
//
//  Created by Joanne Kuang on 2026/1/2.
//


//
//  ContentView.swift
//  CalorieTracker
//
//  Created by Joanne Kuang on 2026/1/2.
//

import SwiftUI
import Charts

// MARK: - Color Palette
extension Color {
    static let parchment = Color(red: 242/255, green: 236/255, blue: 226/255)
    static let sageGreen = Color(red: 184/255, green: 204/255, blue: 194/255)
    static let inkBlue = Color(red: 44/255, green: 62/255, blue: 80/255)
    static let roseDust = Color(red: 214/255, green: 188/255, blue: 179/255)
    static let softBackground = Color(red: 230/255, green: 225/255, blue: 218/255)
}

// MARK: - Keyboard Dismiss
extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}

// MARK: - Models
enum EnergyUnit: String, Codable, CaseIterable {
    case kcal, kj
}

struct FoodItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var value: Int
    var unit: EnergyUnit
    
    var kcalValue: Double {
        unit == .kcal ? Double(value) : Double(value) / 4.184
    }
}

struct DailyEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var foods: [FoodItem]
    var steps: Int
    var vomited: Bool
    
    var totalKcal: Int {
        Int(foods.map { $0.kcalValue }.reduce(0, +))
    }
}

// MARK: - Persistence
func saveEntries(_ entries: [DailyEntry]) {
    if let data = try? JSONEncoder().encode(entries) {
        UserDefaults.standard.set(data, forKey: "dailyEntries")
    }
}

func loadEntries() -> [DailyEntry] {
    if let data = UserDefaults.standard.data(forKey: "dailyEntries"),
       let decoded = try? JSONDecoder().decode([DailyEntry].self, from: data) {
        return decoded.sorted(by: { $0.date > $1.date })
    }
    return []
}

// MARK: - App Language
enum AppLanguage: String, CaseIterable {
    case english = "English"
    case chinese = "简体中文"
}

// MARK: - Card Helper
func card<Content: View>(background: Color = Color.parchment.opacity(0.65), @ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding()
        .background(background)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
}

// MARK: - Button Modifier
struct FilledButton: ViewModifier {
    var background: Color
    var foreground: Color = .white
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(14)
    }
}

extension View {
    func filledButton(background: Color, foreground: Color = .white) -> some View {
        modifier(FilledButton(background: background, foreground: foreground))
    }
}

// MARK: - Header View
struct AppHeader: View {
    var title: String
    var body: some View {
        ZStack {
            Text(title)
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(.inkBlue)
        }
        .frame(height: 60)
    }
}

// MARK: - ContentView
struct ContentView: View {
    
    // Today Page
    @State private var foodName = ""
    @State private var foodValue = ""
    @State private var foodUnit: EnergyUnit = .kcal
    @State private var foodList: [FoodItem] = []
    @State private var steps = ""
    @State private var vomited = false
    @State private var selectedDate = Date()
    
    // History
    @State private var entries: [DailyEntry] = loadEntries()
    @State private var expanded: Set<UUID> = []
    @State private var editMode: EditMode = .inactive
    @State private var selected: Set<UUID> = []
    
    // Calculate Mode
    @State private var showAvgCard = false
    @State private var calculatedAvg: Int = 0
    
    // Settings
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .english
    @AppStorage("showLineGraph") private var showLineGraph: Bool = false
    
    let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f
    }()
    
    var body: some View {
        ZStack {
            Color.softBackground.ignoresSafeArea()
            
            TabView {
                
                // MARK: Today
                ScrollView {
                    VStack(spacing: 24) {
                        AppHeader(title: appText("Calorie Tracker"))
                        
                        card {
                            VStack(spacing: 16) {
                                DatePicker(appText("Date"), selection: $selectedDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                
                                TextField(appText("Food / Drink"), text: $foodName)
                                    .font(.system(.body, design: .monospaced))
                                
                                HStack {
                                    TextField(appText("Energy"), text: $foodValue)
                                        .keyboardType(.numberPad)
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Picker("", selection: $foodUnit) {
                                        ForEach(EnergyUnit.allCases, id: \.self) { Text($0.rawValue) }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                Button(appText("Add Food")) {
                                    if let v = Int(foodValue), !foodName.isEmpty {
                                        foodList.append(FoodItem(name: foodName, value: v, unit: foodUnit))
                                        foodName = ""
                                        foodValue = ""
                                        UIApplication.shared.hideKeyboard()
                                    }
                                }
                                .filledButton(background: .sageGreen, foreground: .inkBlue)
                                
                                ForEach(foodList) { food in
                                    HStack {
                                        Text(food.name)
                                        Spacer()
                                        if food.unit == .kcal {
                                            Text("\(food.value) kcal")
                                        } else {
                                            Text("\(Int(food.kcalValue)) kcal (\(food.value) kJ)")
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .font(.system(.body, design: .monospaced))
                                }
                                
                                Text("\(appText("Daily Total")): \(totalTodayKcal()) kcal")
                                    .bold()
                                
                                TextField(appText("Steps Walked"), text: $steps)
                                    .keyboardType(.numberPad)
                                    .font(.system(.body, design: .monospaced))
                                
                                Toggle(appText("Binge Eating"), isOn: $vomited)
                                    .tint(.roseDust)
                                
                                Button(appText("Save Entry")) {
                                    saveTodayEntry()
                                }
                                .filledButton(background: .inkBlue)
                            }
                        }
                    }
                    .padding()
                }
                .onTapGesture { UIApplication.shared.hideKeyboard() }
                .tabItem { Label(appText("Today"), systemImage: "plus") }
                
                // MARK: History
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // Graph card on top
                            if !entries.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    ZStack(alignment: .leading) {
                                        VStack {
                                            card(background: .white) {
                                                Chart {
                                                    if showLineGraph {
                                                        ForEach(entries.sorted(by: { $0.date < $1.date }), id: \.id) { entry in
                                                            LineMark(
                                                                x: .value("Date", shortDateFormatter.string(from: entry.date)),
                                                                y: .value("Calories", entry.totalKcal)
                                                            )
                                                        }
                                                    } else {
                                                        ForEach(entries.sorted(by: { $0.date < $1.date }), id: \.id) { entry in
                                                            BarMark(
                                                                x: .value("Date", shortDateFormatter.string(from: entry.date)),
                                                                y: .value("Calories", entry.totalKcal)
                                                            )
                                                            .annotation(position: .top) {
                                                                Text("\(entry.totalKcal)")
                                                                    .font(.caption2)
                                                                    .foregroundColor(.inkBlue)
                                                            }
                                                            
                                                        }
                                                    }
                                                }
                                                .frame(width: max(CGFloat(entries.count) * 40, 300), height: 250)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // History entries: allow reorder in EditMode
                            LazyVStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    EntryRow(entry: entry, editMode: $editMode, expanded: $expanded, selected: $selected, bindingForEntry: bindingForEntry(_:), deleteFood: deleteFood, deleteSteps: deleteSteps)
                                }
                            }
                        }
                        .padding(.vertical)
                        .padding(.bottom, 120) // extra space so floating buttons don't cover last row
                    }
                    
                    // Floating buttons
                    HStack(spacing: 16) {
                        // Manage button
                        Button {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                                selected.removeAll()
                                showAvgCard = false
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .filledButton(background: .inkBlue)
                        
                        if editMode == .active && !selected.isEmpty {
                            // Calculate Avg Icon
                            Button {
                                if !showAvgCard {
                                    calculateAverage()
                                } else {
                                    showAvgCard = false
                                    selected.removeAll()
                                }
                            } label: {
                                Image(systemName: "sum")
                                    .font(.title2)
                            }
                            .filledButton(background: .sageGreen, foreground: .inkBlue)
                            
                            // Delete Icon
                            Button {
                                deleteSelectedEntries()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.title2)
                            }
                            .filledButton(background: .red, foreground: .white)
                        }
                    }
                    .padding()
                }
                .tabItem { Label(appText("History"), systemImage: "list.bullet") }
                
                // MARK: Settings
                SettingsView(appLanguage: $appLanguage, showLineGraph: $showLineGraph)
                    .tabItem { Label(appText("Settings"), systemImage: "gearshape") }
            }
            .accentColor(.inkBlue)
            
            // Popup card for calculate
            if showAvgCard {
                VStack {
                    Spacer()
                    card {
                        Text("Average kcal: \(calculatedAvg)")
                            .font(.body)
                            .bold()
                    }
                    .padding()
                }
                .transition(.opacity)
            }
        }
    }
    
    // MARK: Functions
    func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }
    
    func toggleSelection(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) }
        else { selected.insert(id) }
    }
    
    func totalTodayKcal() -> Int {
        Int(foodList.map { $0.kcalValue }.reduce(0, +))
    }
    
    func resetToday() {
        foodList = []
        steps = ""
        vomited = false
        selectedDate = Date()
        UIApplication.shared.hideKeyboard()
    }
    
    func saveTodayEntry() {
        if let index = entries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
            entries[index].foods.append(contentsOf: foodList)
            entries[index].steps += Int(steps) ?? 0
            entries[index].vomited = entries[index].vomited || vomited
        } else {
            let entry = DailyEntry(date: selectedDate, foods: foodList, steps: Int(steps) ?? 0, vomited: vomited)
            entries.insert(entry, at: 0)
        }
        entries.sort(by: { $0.date > $1.date })
        saveEntries(entries)
        resetToday()
    }
    
    func bindingForEntry(_ entry: DailyEntry) -> Binding<Date> {
        Binding<Date>(
            get: { entry.date },
            set: { newDate in
                if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[idx].date = newDate
                    saveEntries(entries)
                }
            }
        )
    }
    
    func deleteSelectedEntries() {
        entries.removeAll { selected.contains($0.id) }
        saveEntries(entries)
        selected.removeAll()
    }

    func deleteFood(entry: DailyEntry, foodID: UUID) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].foods.removeAll { $0.id == foodID }
            saveEntries(entries)
        }
    }
    
    func deleteSteps(entry: DailyEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].steps = 0
            saveEntries(entries)
        }
    }
    
    func calculateAverage() {
        let selectedEntries = entries.filter { selected.contains($0.id) }
        guard !selectedEntries.isEmpty else { return }
        
        let total = selectedEntries.map { $0.totalKcal }.reduce(0, +)
        calculatedAvg = Int(Double(total) / Double(selectedEntries.count))
        
        showAvgCard = true
    }
    
    func appText(_ english: String) -> String {
        switch appLanguage {
        case .english: return english
        case .chinese:
            switch english {
            case "Date": return "日期"
            case "Food / Drink": return "食物/饮料"
            case "Energy": return "能量"
            case "Add Food": return "添加食物"
            case "Daily Total": return "每日总量"
            case "Steps Walked": return "步数"
            case "Binge Eating": return "是否暴食"
            case "Save Entry": return "保存记录"
            case "Today": return "今日"
            case "History": return "历史"
            case "Settings": return "设置"
            default: return english
            }
        }
    }
}

// MARK: - Entry Row Subview
struct EntryRow: View {
    var entry: DailyEntry
    @Binding var editMode: EditMode
    @Binding var expanded: Set<UUID>
    @Binding var selected: Set<UUID>
    
    var bindingForEntry: (DailyEntry) -> Binding<Date>
    var deleteFood: (DailyEntry, UUID) -> Void
    var deleteSteps: (DailyEntry) -> Void
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                
                HStack {
                    if editMode == .active {
                        Button(action: { toggleSelection(entry.id) }) {
                            Image(systemName: selected.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(.inkBlue)
                        }
                    }
                    
                    if editMode == .active {
                        DatePicker("", selection: bindingForEntry(entry), displayedComponents: .date)
                            .labelsHidden()
                            .frame(width: 140)
                    } else {
                        Text(entry.date, formatter: DateFormatter.shortDateFormatter)
                            .bold()
                    }
                    
                    if entry.vomited {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                    }
                    
                    Spacer()
                    Text("\(entry.totalKcal) kcal")
                    
                    if editMode == .inactive {
                        Button(action: { toggle(entry.id) }) {
                            Image(systemName: expanded.contains(entry.id) ? "chevron.up" : "chevron.down")
                        }
                    }
                }
                
                if expanded.contains(entry.id) {
                    Divider()
                    
                    ForEach(entry.foods) { food in
                        HStack {
                            Text(food.name)
                            Spacer()
                            if food.unit == .kcal {
                                Text("\(food.value) kcal")
                            } else {
                                Text("\(Int(food.kcalValue)) kcal (\(food.value) kJ)")
                            }
                            if editMode == .active {
                                Button {
                                    deleteFood(entry, food.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    HStack {
                        Text("Steps: \(entry.steps)")
                        Spacer()
                        if editMode == .active {
                            Button {
                                deleteSteps(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 350) // narrower entry blocks
    }
    
    private func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) }
        else { selected.insert(id) }
    }
}

// MARK: - Settings Page
struct SettingsView: View {
    @Binding var appLanguage: AppLanguage
    @Binding var showLineGraph: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            AppHeader(title: "Settings")
            
            VStack(spacing: 16) {
                Picker("Language", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                
                Picker("Graph Type", selection: $showLineGraph) {
                    Text("Histogram").tag(false)
                    Text("Line").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            Spacer()
        }
        .background(Color.softBackground.ignoresSafeArea())
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f
    }()
}

// MARK: - Preview
#Preview {
    ContentView()
}
