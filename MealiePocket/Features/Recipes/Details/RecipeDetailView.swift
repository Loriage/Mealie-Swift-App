import SwiftUI

struct RecipeDetailView: View {
    let recipeSummary: RecipeSummary
    
    @State private var viewModel: RecipeDetailViewModel
    @Environment(AppState.self) private var appState
    
    init(recipeSummary: RecipeSummary) {
        self.recipeSummary = recipeSummary
        _viewModel = State(initialValue: RecipeDetailViewModel(recipeSummary: recipeSummary))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let detail = viewModel.recipeDetail {
                    headerView(detail: detail)
                    
                    Divider().padding(.horizontal)
                    
                    ingredientsSection(ingredients: detail.recipeIngredient)
                    
                    Divider().padding(.horizontal)
                    
                    instructionsSection(instructions: detail.recipeInstructions)
                    
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable().scaledToFit().frame(width: 50, height: 50).foregroundColor(.orange)
                        Text("Error").font(.title2).fontWeight(.bold)
                        Text(errorMessage).font(.callout).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showingAddToPlanSheet = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .disabled(viewModel.recipeDetail == nil)
                
                Button {
                    hapticImpact(style: .light)
                    Task {
                        await viewModel.toggleFavorite(apiClient: appState.apiClient, userID: appState.currentUserID)
                    }
                } label: {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isFavorite ? .red : .primary)
                }
                .disabled(viewModel.recipeDetail == nil)
                
                NavigationLink {
                    if let detail = viewModel.recipeDetail {
                        EditRecipeView(
                            viewModel: EditRecipeViewModel(recipe: detail),
                            detailViewModel: viewModel,
                            apiClient: appState.apiClient
                        )
                    }
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(viewModel.recipeDetail == nil)
            }
        }
        .sheet(isPresented: $viewModel.showingAddToPlanSheet) {
            if let client = appState.apiClient {
                AddToMealPlanView(viewModel: viewModel, apiClient: client)
            }
        }
        .task {
            if viewModel.recipeDetail == nil || viewModel.needsRefresh {
                await viewModel.loadRecipeDetail(slug: recipeSummary.slug, apiClient: appState.apiClient, userID: appState.currentUserID)
            }
        }
    }

    private func headerView(detail: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.recipeDetail?.name ?? recipeSummary.name)
                .font(.title.bold())
            HStack(alignment: .top, spacing: 16) {
                AsyncImageView(
                    url: .makeImageURL(
                        baseURL: appState.apiClient?.baseURL,
                        recipeID: detail.id,
                        imageName: "original.webp"
                    )
                )
                .frame(width: 150, height: 150)
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 10) {
                    TimeInfoView(icon: "clock", label: "Total", value: detail.totalTime)
                    
                    HStack(spacing: 1) {
                        TimeInfoView(icon: "stopwatch", label: "Preparation", value: detail.prepTime)
                        Divider().padding()
                        TimeInfoView(icon: "frying.pan", label: "Cooking", value: detail.performTime)
                    }
                    .lineLimit(1)
                    
                    let servingsValue: Double? = detail.recipeServings
                    let isSingular: Bool = servingsValue == 1.0

                    let servingsLabel: LocalizedStringKey = isSingular ? "Portion" : "Portions"
                    let servingsIcon: String = isSingular ? "person" : "person.2"

                    if let servingsValue, servingsValue > 0 {
                        TimeInfoView(
                            icon: servingsIcon,
                            label: servingsLabel,
                            value: servingsValue
                        )
                    } else if let yield = detail.recipeYield, !yield.isEmpty {
                        TimeInfoView(
                            icon: "person.2",
                            label: "Portions",
                            value: yield
                        )
                    } else {
                        TimeInfoView(
                            icon: "person",
                            label: "Portion",
                            value: (nil as String?)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                if let description = detail.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(description)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your rating")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    let ratingBinding = Binding<Double>(
                        get: { viewModel.recipeDetail?.userRating ?? 0.0 },
                        set: { newRating in
                            Task {
                                await viewModel.setRating(newRating, slug: recipeSummary.slug, apiClient: appState.apiClient, userID: appState.currentUserID)
                            }
                        }
                    )
                    StarRatingView(rating: ratingBinding)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if let globalRating = detail.rating, globalRating > 0, globalRating != viewModel.recipeDetail?.userRating {
                    HStack(spacing: 4) {
                        Text("Overall rating:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label(String(format: "%.1f", globalRating), systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func ingredientsSection(ingredients: [RecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients").font(.title2.weight(.semibold)).padding(.horizontal)
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(ingredients) { ingredient in
                    IngredientRow(text: ingredient.display)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func instructionsSection(instructions: [RecipeInstruction]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Instructions").font(.title2.weight(.semibold)).padding(.horizontal)
            LazyVStack(alignment: .leading, spacing: 15) {
                ForEach(Array(instructions.enumerated()), id: \.element.id) { index, instruction in
                    InstructionRow(index: index, instruction: instruction, baseURL: appState.apiClient?.baseURL)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

private struct TimeInfoView: View {
    let label: LocalizedStringKey
    let icon: String
    private let stringText: String?
    private let rawDouble: Double?

    @Environment(\.locale) private var locale

    init(icon: String = "clock", label: LocalizedStringKey, value: String?) {
        self.label = label
        self.icon = icon
        self.stringText = value
        self.rawDouble = nil
    }

    init(icon: String, label: LocalizedStringKey, value: Double?) {
        self.label = label
        self.icon = icon
        self.stringText = nil
        self.rawDouble = value
    }

    private var displayText: String {
        if let d = rawDouble, d > 0 {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
            formatter.locale = locale
            return formatter.string(from: NSNumber(value: d)) ?? "N/A"
        }
        return stringText ?? "N/A"
    }

    var body: some View {
        VStack(alignment: .leading) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(displayText)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

private struct IngredientRow: View {
    let text: String
    @State private var isChecked = false
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .secondary)
                    .font(.title3)
                Text(text)
                    .strikethrough(isChecked, color: .secondary)
                    .foregroundColor(isChecked ? .secondary : .primary)
                    .font(.body)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct InstructionRow: View {
    let index: Int
    let instruction: RecipeInstruction
    let baseURL: URL?
    @State private var isCompleted = false

    private enum StepSegment {
        case text(String)
        case image(URL)
    }

    private var stepTitle: String {
        if let summary = instruction.summary, !summary.isEmpty {
            return summary
        } else if let title = instruction.title, !title.isEmpty {
            return title
        } else {
            return "Step \(index + 1)"
        }
    }

    private static let imgRegex = try? NSRegularExpression(
        pattern: #"<img[^>]+src="([^"]+)"[^>]*/?>"#,
        options: [.caseInsensitive]
    )

    private var segments: [StepSegment] {
        let text = instruction.text
        guard let regex = Self.imgRegex else {
            return [.text(text)]
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return [.text(text)] }

        var result: [StepSegment] = []
        var lastEnd = text.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }

            if lastEnd < matchRange.lowerBound {
                let part = String(text[lastEnd..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !part.isEmpty { result.append(.text(part)) }
            }

            if let srcRange = Range(match.range(at: 1), in: text) {
                let src = String(text[srcRange])
                if let url = resolveURL(src) { result.append(.image(url)) }
            }

            lastEnd = matchRange.upperBound
        }

        if lastEnd < text.endIndex {
            let part = String(text[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { result.append(.text(part)) }
        }

        return result.isEmpty ? [.text(text)] : result
    }

    private func resolveURL(_ src: String) -> URL? {
        if src.hasPrefix("http://") || src.hasPrefix("https://") {
            return URL(string: src)
        }
        guard let base = baseURL else { return nil }
        var baseString = base.absoluteString
        if baseString.hasSuffix("/") { baseString.removeLast() }
        return URL(string: baseString + src)
    }

    private func makeAttributedString(from markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(markdown)
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                isCompleted.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(stepTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .opacity(isCompleted ? 1 : 0)
                }

                if !isCompleted {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            segmentView(segment)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .foregroundColor(.primary)
            .padding()
            .background(.thinMaterial)
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func segmentView(_ segment: StepSegment) -> some View {
        switch segment {
        case .text(let content):
            Text(makeAttributedString(from: content))
                .font(.body)
        case .image(let url):
            StepImageView(url: url)
        }
    }
}

private struct StepImageView: View {
    let url: URL
    @State private var isExpanded = false

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Color(.secondarySystemBackground)
                    ProgressView()
                }
                .frame(width: 120, height: 120)
                .cornerRadius(8)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            isExpanded = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.bold())
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(5)
                        }
                        .buttonStyle(.plain)
                    }
            case .failure:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }
        .fullScreenCover(isPresented: $isExpanded) {
            ZoomableImageViewer(url: url, isPresented: $isExpanded)
        }
    }
}

private struct ZoomableImageViewer: View {
    let url: URL
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1, lastScale * value)
                                }
                                .onEnded { _ in
                                    if scale <= 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                        lastScale = 1
                                    } else {
                                        lastScale = scale
                                    }
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            guard scale > 1 else { return }
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                default:
                    ProgressView()
                }
            }

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

struct AddToMealPlanView: View {
    @Bindable var viewModel: RecipeDetailViewModel
    var apiClient: MealieAPIClient?
    
    @State private var selectedDate = Date()
    @State private var selectedMealType = "Dinner"
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Side"]
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                
                Picker("Meal Type", selection: $selectedMealType) {
                    ForEach(mealTypes, id: \.self) { type in
                        Text(LocalizedStringKey(type)).tag(type)
                    }
                }
            }
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await viewModel.addToMealPlan(date: selectedDate, mealType: selectedMealType, apiClient: apiClient)
                        }
                    }
                    .disabled(viewModel.recipeDetail == nil)
                }
            }
        }
    }
}
