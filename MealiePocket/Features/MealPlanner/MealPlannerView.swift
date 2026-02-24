import SwiftUI

struct MealPlannerView: View {
    @Environment(MealPlannerViewModel.self) private var viewModel
    @Environment(AppState.self) private var appState
    
    @State private var selectedTabIndex = 1
    @State private var currentlyVisibleMonth: Date = Date().startOfMonth()
    @State private var scrollViewFrame: CGRect = .zero
    private var daysOfWeek: [String] {
        var cal = Calendar.current
        cal.locale = locale
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }
    
    @State private var showingMealTypeSelection = false
    @State private var selectedMealType = "Dinner"
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Side"]
    
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) var dismiss
    
    @Namespace var unionNamespace
    
    var body: some View {
        VStack {
            header
            
            if viewModel.isLoadingPast { ProgressView().progressViewStyle(.circular) }
            
            if viewModel.isLoading && viewModel.mealPlanEntries.isEmpty {
                ProgressView()
                Spacer()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                calendarContent
            }
            
            if viewModel.isLoadingFuture { ProgressView().progressViewStyle(.circular) }
        }
        .navigationTitle("planner.navigationTitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("View mode", selection: Binding(
                    get: { viewModel.viewMode },
                    set: { viewModel.viewMode = $0 }
                )) {
                    ForEach(MealPlannerViewModel.ViewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .overlay(alignment: .bottom) {
            HStack {
                Button("planner.today") {
                    viewModel.goToToday(apiClient: appState.apiClient)
                }
                .font(.headline)
                .foregroundStyle(Color.primary)
                .padding()
                .glassEffect(.regular.tint(.clear).interactive())
                
                Spacer()
                
                if viewModel.viewMode == .day {
                    GlassEffectContainer(spacing: 5) {
                        HStack {
                            Button {
                                viewModel.addDay(apiClient: appState.apiClient)
                            } label: {
                                Image(systemName: "text.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(Color.primary)
                                    .padding()
                            }
                            .glassEffect(.regular.tint(.clear).interactive())
                            .glassEffectUnion(id: "add-buttons", namespace: unionNamespace)
                            
                            Button {
                                hapticImpact(style: .light)
                                viewModel.presentRandomMealTypeSheet(for: viewModel.selectedDate)
                            } label: {
                                Image(systemName: "dice")
                                    .font(.title3)
                                    .foregroundStyle(Color.primary)
                                    .padding()
                            }
                            .glassEffect(.regular.tint(.clear).interactive())
                            .glassEffectUnion(id: "add-buttons", namespace: unionNamespace)
                            
                            Button {
                                hapticImpact(style: .light)
                                viewModel.presentAddRecipeSheet(for: viewModel.selectedDate)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .padding()
                            }
                            .glassEffect(.regular.tint(.clear).interactive())
                            .glassEffectUnion(id: "add-buttons", namespace: unionNamespace)
                        }
                    }
                } else if viewModel.viewMode == .week {
                    Button {
                        viewModel.addWeek(apiClient: appState.apiClient)
                    } label: {
                        Image(systemName: "text.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Color.primary)
                            .padding()
                    }
                    .glassEffect(.regular.tint(.clear).interactive(), in: .circle)
                } else {
                    Button {
                        viewModel.addRange()
                    } label: {
                        Image(systemName: "text.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Color.primary)
                            .padding()
                    }
                    .glassEffect(.regular.tint(.clear).interactive(), in: .circle)
                }
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 20)
        }
        .task {
            currentlyVisibleMonth = viewModel.selectedDate.startOfMonth()
            await viewModel.loadMealPlan(apiClient: appState.apiClient)
        }
        .onChange(of: viewModel.viewMode) { _, _ in
            if viewModel.viewMode == .month {
                currentlyVisibleMonth = viewModel.selectedDate.startOfMonth()
            }
            Task { await viewModel.loadMealPlan(apiClient: appState.apiClient) }
        }
        .onChange(of: viewModel.selectedDate) { _, newDate in
            if viewModel.viewMode == .day {
                Task { await viewModel.loadMealPlan(apiClient: appState.apiClient) }
            }
        }
        .navigationDestination(for: RecipeSummary.self) { recipe in
            RecipeDetailView(recipeSummary: recipe)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingAddRecipeSheet },
            set: { viewModel.showingAddRecipeSheet = $0 }
        )) {
            if let date = viewModel.dateForAddingRecipe {
                SelectRecipeForDayView(viewModel: viewModel, date: date, apiClient: appState.apiClient)
            } else {
                Text("planner.errorDateNotSelected")
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingMealTypeSelection },
            set: { viewModel.showingMealTypeSelection = $0 }
        )) {
            if let date = viewModel.dateForAddingRecipe {
                MealTypeSelectionView(
                    selectedMealType: $selectedMealType,
                    mealTypes: mealTypes,
                    onConfirm: {
                        Task {
                            await viewModel.addRandomMeal(date: date, mealType: selectedMealType)
                        }
                        viewModel.showingMealTypeSelection = false
                    },
                    onCancel: {
                        viewModel.showingMealTypeSelection = false
                    }
                )
                .presentationDetents([.height(200)])
            } else {
                Text("planner.errorDateNotSelected")
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingDateRangePicker },
            set: { viewModel.showingDateRangePicker = $0}
        )) {
            MealPlannerDateRangePickerView(viewModel: viewModel)
        }
        .sheet(isPresented: Binding (
            get : { viewModel.showingShoppingListSelection },
            set : { viewModel.showingShoppingListSelection = $0}
        )) {
            ShoppingListSelectionView(viewModel: viewModel, apiClient: appState.apiClient)
        }
        .onChange(of: viewModel.searchQueryForSelection) { _, _ in
            Task { await viewModel.searchRecipesForSelection(apiClient: appState.apiClient) }
        }
    }
    
    private var header: some View {
        VStack(spacing: 5) {
            if viewModel.viewMode == .month {
                HStack {
                    Spacer()
                    Text(currentlyVisibleMonth.formatted(.dateTime.locale(locale).month(.wide).year()))
                        .font(.headline)
                        .id(currentlyVisibleMonth)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                
                HStack {
                    ForEach(daysOfWeek.indices, id: \.self) { index in
                        Text(daysOfWeek[index])
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 5)
            } else {
                HStack {
                    Button {
                        viewModel.changeDate(-1)
                        Task { await viewModel.loadMealPlan(apiClient: appState.apiClient) }
                    } label: { Image(systemName: "chevron.left") }
                        .padding(.leading)
                        .disabled(!viewModel.canChangeDateBack)
                    Spacer()
                    Text(dateRangeTitle)
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.changeDate(1)
                        Task { await viewModel.loadMealPlan(apiClient: appState.apiClient) }
                    } label: { Image(systemName: "chevron.right") }
                        .padding(.trailing)
                }
                .padding(.vertical, 12)
            }
        }
    }
    
    private var calendarContent: some View {
        Group {
            if viewModel.viewMode == .month {
                GeometryReader { scrollViewProxy in
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.displayedMonths, id: \.self) { monthStart in
                                    GeometryReader { monthProxy in
                                        CalendarMonthView(
                                            days: viewModel.daysInSpecificMonth(monthStart),
                                            mealPlanEntries: viewModel.mealPlanEntries,
                                            selectedMonthDate: monthStart,
                                            baseURL: appState.apiClient?.baseURL,
                                            onDateSelected: { date in
                                                viewModel.selectDateAndView(date: date)
                                            }
                                        )
                                        .id(monthStart)
                                        .preference(key: VisibleMonthPreferenceKey.self, value: [MonthVisibilityInfo(month: monthStart, frame: monthProxy.frame(in: .global))])
                                    }
                                    .frame(height: CGFloat(viewModel.daysInSpecificMonth(monthStart).count / 7) * 100)
                                }
                                
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMoreMonths(direction: 1, apiClient: appState.apiClient)
                                        }
                                    }
                            }
                        }
                        .coordinateSpace(name: "scrollView")
                        .onPreferenceChange(VisibleMonthPreferenceKey.self) { preferences in
                            updateVisibleMonth(preferences: preferences, scrollFrame: scrollViewProxy.frame(in: .global))
                        }
                        .onChange(of: viewModel.selectedDate) { _, newDate in
                            if viewModel.viewMode == .month {
                                let targetMonth = newDate.startOfMonth()
                                currentlyVisibleMonth = targetMonth
                                withAnimation {
                                    scrollProxy.scrollTo(targetMonth, anchor: .top)
                                }
                            }
                        }
                        .onAppear {
                            scrollViewFrame = scrollViewProxy.frame(in: .global)
                        }
                        .onChange(of: scrollViewProxy.frame(in: .global)) { _, newFrame in
                            scrollViewFrame = newFrame
                        }
                    }
                }
            } else {
                ScrollView {
                    if viewModel.viewMode == .week {
                        weekView
                    } else {
                        dayView
                    }
                }
            }
        }
    }
    
    private func updateVisibleMonth(preferences: [MonthVisibilityInfo], scrollFrame: CGRect) {
        let scrollCenterY = scrollFrame.midY
        var closestMonth: Date? = nil
        var minDistance = CGFloat.infinity
        
        for info in preferences {
            if info.frame.intersects(scrollFrame) {
                let distance = abs(info.frame.midY - scrollCenterY)
                if distance < minDistance {
                    minDistance = distance
                    closestMonth = info.month
                }
            }
        }
        
        if let month = closestMonth, month != currentlyVisibleMonth {
            currentlyVisibleMonth = month
        }
    }
    
    private var weekView: some View {
        let days = viewModel.daysInWeek
        return VStack(alignment: .leading, spacing: 15) {
            ForEach(days, id: \.self) { date in
                VStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        Text(date.formatted(.dateTime.locale(locale).weekday(.wide)))
                            .font(.headline)
                        Text(date.formatted(.dateTime.locale(locale).day()))
                            .font(.headline)
                            .bold(Calendar.current.isDateInToday(date))
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button {
                                hapticImpact(style: .light)
                                viewModel.presentRandomMealTypeSheet(for: date)
                            } label: {
                                Image(systemName: "dice")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .frame(width: 25, height: 25)
                                    .glassEffect(.regular.tint(.clear), in: .circle)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                hapticImpact(style: .light)
                                viewModel.presentAddRecipeSheet(for: date)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .frame(width: 25, height: 25)
                                    .glassEffect(.regular.tint(.accentColor), in: .circle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 5)
                    
                    mealEntriesList(for: date, showType: true)
                }
                
                if date != days.last {
                    Divider()
                } else {
                    Spacer(minLength: 40)
                }
            }
        }
        .padding()
    }
    
    private var dayView: some View {
        let date = Calendar.current.startOfDay(for: viewModel.selectedDate)
        return VStack(alignment: .leading) {
            mealEntriesList(for: date, showType: true)
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func mealEntriesList(for date: Date, showType: Bool = false) -> some View {
        let entries = viewModel.mealPlanEntries[Calendar.current.startOfDay(for: date)] ?? []
        let sortedEntries = entries.sorted {
            let typeOrder: [String: Int] = ["breakfast": 0, "lunch": 1, "dinner": 2, "side": 3]
            let order1 = typeOrder[$0.entryType.lowercased()] ?? 4
            let order2 = typeOrder[$1.entryType.lowercased()] ?? 4
            if order1 != order2 {
                return order1 < order2
            }
            let name1 = $0.recipe?.name ?? $0.title
            let name2 = $1.recipe?.name ?? $1.title
            return name1 < name2
        }
        
        if entries.isEmpty {
            if viewModel.viewMode == .day {
                Text("planner.nothingPlanned")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
            } else {
                Spacer().frame(height: 1)
            }
        } else {
            VStack(alignment: .leading, spacing: viewModel.viewMode == .month ? 1 : 8) {
                ForEach(sortedEntries) { entry in
                    mealEntryView(entry: entry, showType: showType)
                }
                .onDelete(perform: deleteEntry)
            }
            .padding(.horizontal, viewModel.viewMode == .month ? 0 : 5)
            .padding(.vertical, viewModel.viewMode == .month ? 0 : 5)
        }
    }
    
    @ViewBuilder
    private func mealEntryView(entry: ReadPlanEntry, showType: Bool) -> some View {
        HStack {
            if let recipe = entry.recipe {
                NavigationLink(value: recipe) {
                    labelView(entry: entry, recipeName: recipe.name, showType: showType)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                labelView(entry: entry, recipeName: nil, showType: showType)
                    .contentShape(Rectangle())
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteMealEntry(entryID: entry.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func labelView(entry: ReadPlanEntry, recipeName: String?, showType: Bool) -> some View {
        let isMonthView = viewModel.viewMode == .month
        let showTimes = !isMonthView && entry.recipe != nil &&
        ((entry.recipe?.totalTime?.isEmpty == false) || (entry.recipe?.prepTime?.isEmpty == false))
        
        let baseImageSize: CGFloat = isMonthView ? 16 : (showTimes ? 40 : 30)
        let placeholderSize: CGFloat = isMonthView ? 16 : 30
        
        HStack(spacing: isMonthView ? 4 : 8) {
            if let recipe = entry.recipe {
                AsyncImageView(url: .makeImageURL(
                    baseURL: appState.apiClient?.baseURL,
                    recipeID: recipe.id,
                    imageName: "min-original.webp",
                    cacheBuster: viewModel.imageLoadID.uuidString
                ))
                .frame(width: baseImageSize, height: baseImageSize)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: iconForEntryType(entry.entryType))
                    .foregroundColor(.accentColor)
                    .font(isMonthView ? .system(size: 10) : .callout)
                    .frame(width: placeholderSize, height: placeholderSize, alignment: .center)
                    .background(.thinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 3))
            }
            
            VStack(alignment: .leading, spacing: isMonthView ? 0 : 2) {
                if !isMonthView && (showType || viewModel.viewMode == .day) {
                    Text(entry.entryType.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(recipeName ?? (entry.title.isEmpty ? entry.text : entry.title))
                    .font(isMonthView ? .system(size: 9) : .body)
                    .lineLimit(1)
                
                if showTimes, let recipe = entry.recipe {
                    HStack(spacing: 6) {
                        if let totalTime = recipe.totalTime, !totalTime.isEmpty {
                            Label(totalTime, systemImage: "clock")
                        }
                        if let prepTime = recipe.prepTime, !prepTime.isEmpty {
                            Label(prepTime, systemImage: "stopwatch")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .id(entry.id)
        .padding(.vertical, isMonthView ? 2 : (showTimes ? 10 : 8))
        .padding(.horizontal, isMonthView ? 2 : 10)
        .background(
            isMonthView ? AnyShapeStyle(.clear) : AnyShapeStyle(.thinMaterial),
            in: RoundedRectangle(cornerRadius: isMonthView ? 3 : 8)
        )
    }
    
    private var dateRangeTitle: String {
        let dateToShow = viewModel.viewMode == .month ? currentlyVisibleMonth : viewModel.selectedDate

        switch viewModel.viewMode {
        case .day:
            return dateToShow.formatted(Date.FormatStyle(date: .complete, time: .omitted).locale(locale))
        case .week:
            guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: dateToShow) else { return "" }
            let start = interval.start
            let end = interval.end.addingTimeInterval(-1)

            let startYear = Calendar.current.component(.year, from: start)
            let endYear = Calendar.current.component(.year, from: end)

            let monthDayFormat = Date.FormatStyle().locale(locale).month(.abbreviated).day()
            let monthDayYearFormat = Date.FormatStyle().locale(locale).month(.abbreviated).day().year()

            if startYear == endYear {
                return "\(start.formatted(monthDayFormat)) - \(end.formatted(monthDayFormat)), \(startYear)"
            } else {
                return "\(start.formatted(monthDayYearFormat)) - \(end.formatted(monthDayYearFormat))"
            }
        case .month:
            return dateToShow.formatted(.dateTime.locale(locale).month(.wide).year())
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        let dateKey = Calendar.current.startOfDay(for: viewModel.selectedDate)
        guard let entries = viewModel.mealPlanEntries[dateKey] else { return }
        let sortedEntries = entries.sorted {
            let typeOrder: [String: Int] = ["breakfast": 0, "lunch": 1, "dinner": 2, "side": 3]
            let order1 = typeOrder[$0.entryType.lowercased()] ?? 4
            let order2 = typeOrder[$1.entryType.lowercased()] ?? 4
            if order1 != order2 {
                return order1 < order2
            }
            let name1 = $0.recipe?.name ?? $0.title
            let name2 = $1.recipe?.name ?? $1.title
            return name1 < name2
        }
        
        let idsToDelete = offsets.map { sortedEntries[$0].id }
        
        Task {
            for entryID in idsToDelete {
                await viewModel.deleteMealEntry(entryID: entryID)
            }
        }
    }
    
    private func iconForEntryType(_ type: String) -> String {
        switch type.lowercased() {
        case "breakfast": return "sun.horizon.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "side": return "fork.knife"
        default: return "note.text"
        }
    }
}

struct MonthVisibilityInfo: Equatable {
    let month: Date
    let frame: CGRect
}

struct VisibleMonthPreferenceKey: PreferenceKey {
    typealias Value = [MonthVisibilityInfo]
    
    static var defaultValue: Value = []
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}
