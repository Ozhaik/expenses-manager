import SwiftUI

struct ContentView: View {
    @State private var currentCategoryIndex = 0
    @State private var amountText = ""
    @State private var expenses: [Expense] = []
    @State private var recurringExpenses: [RecurringExpense] = []
    @State private var categories = ExpenseCategory.placeholderCategories
    @State private var deletedCategoryBuckets: [DeletedCategoryBucket] = []
    @State private var appTheme: AppTheme = .system
    @State private var isSideMenuOpen = false
    @State private var selectedMenuOption: MenuOption?
    @State private var pendingExpense: Expense?
    @State private var expenseName = ""
    @State private var isNamingSheetPresented = false
    @State private var newCategoryName = ""
    @State private var newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
    @State private var newCategoryTintName = CategoryAppearanceOption.defaultTintName
    @State private var categoryNameError: String?
    @State private var isCategorySheetPresented = false
    @State private var isManageCategoriesPresented = false
    @State private var isSettingsPresented = false
    @State private var isRecurringExpensePresented = false
    @State private var isBackfillExpensePresented = false
    @State private var isManageRecurringExpensesPresented = false
    @State private var isPastExpensesPresented = false
    @State private var categoryForMonthlyDetails: ExpenseCategory?
    @State private var categoryForTargetEdit: ExpenseCategory?

    private let dragThreshold: CGFloat = 55

    var body: some View {
        ZStack(alignment: .topLeading) {
            mainContent

            menuButton
                .padding(.top, 14)
                .padding(.leading, 16)

            recurringExpenseButton
                .padding(.top, 16)
                .padding(.trailing, 18)

            if isSideMenuOpen {
                sideMenuOverlay
                    .transition(.opacity)
            }

            if isRecurringExpensePresented {
                recurringExpenseOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .background(Color(.systemGroupedBackground))
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(appTheme.colorScheme)
        .onAppear {
            loadStoredData()
        }
        .sheet(isPresented: $isNamingSheetPresented) {
            ExpenseNameView(
                expenseName: $expenseName,
                onSave: savePendingExpenseWithName,
                onSkip: savePendingExpenseWithoutName
            )
            .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $isCategorySheetPresented) {
            AddCategoryView(
                categoryName: $newCategoryName,
                selectedSystemImageName: $newCategorySystemImageName,
                selectedTintName: $newCategoryTintName,
                errorMessage: $categoryNameError,
                onSave: saveNewCategory,
                onCancel: closeCategorySheet
            )
            .presentationDetents([.height(430)])
        }
        .fullScreenCover(isPresented: $isManageCategoriesPresented) {
            ManageCategoriesView(
                categories: $categories,
                expenses: $expenses,
                recurringExpenses: recurringExpenses,
                deletedCategoryBuckets: $deletedCategoryBuckets,
                currentCategoryIndex: $currentCategoryIndex,
                monthlyTotal: monthlyTotal,
                onPersist: persistManagedCategories,
                onClose: {
                    isManageCategoriesPresented = false
                }
            )
        }
        .sheet(item: $categoryForMonthlyDetails) { category in
            CategoryMonthlyDetailsView(
                category: category,
                expenses: expenses.filter { $0.categoryId == category.id },
                recurringExpenses: recurringExpenses.filter { $0.categoryId == category.id },
                onSaveTarget: saveMonthlyTarget,
                onClose: {
                    categoryForMonthlyDetails = nil
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $categoryForTargetEdit) { category in
            EditMonthlyTargetView(
                categoryName: category.name,
                monthlyTarget: category.monthlyTarget,
                onSave: { target in
                    saveMonthlyTarget(category, target)
                    categoryForTargetEdit = nil
                },
                onCancel: {
                    categoryForTargetEdit = nil
                }
            )
            .presentationDetents([.height(240)])
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            SettingsView(
                onClose: {
                    isSettingsPresented = false
                }
            )
        }
        .fullScreenCover(isPresented: $isBackfillExpensePresented) {
            BackfillExpenseView(
                categories: categories,
                onSave: saveBackfillExpenses,
                onClose: {
                    isBackfillExpensePresented = false
                }
            )
        }
        .fullScreenCover(isPresented: $isPastExpensesPresented) {
            PastExpensesView(
                categories: categories,
                expenses: expenses,
                recurringExpenses: recurringExpenses,
                onClose: {
                    isPastExpensesPresented = false
                }
            )
        }
        .fullScreenCover(isPresented: $isManageRecurringExpensesPresented) {
            ManageRecurringExpensesView(
                categories: $categories,
                recurringExpenses: $recurringExpenses,
                onPersist: {
                    Storage.saveCategories(categories)
                    Storage.saveRecurringExpenses(recurringExpenses)
                },
                onClose: {
                    isManageRecurringExpensesPresented = false
                }
            )
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            Text(categoryPositionText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(height: 24)
                .padding(.bottom, 4)

            HStack(spacing: 8) {
                categoryNavigationButton(systemName: "chevron.right") {
                    selectNextCategory()
                }

                TabView(selection: $currentCategoryIndex) {
                    ForEach(categories.indices, id: \.self) { index in
                        CategoryCard(
                            category: categories[index],
                            isSelected: currentCategoryIndex == index,
                            monthlyTotal: monthlyTotal(for: categories[index])
                        )
                        .onTapGesture {
                            categoryForMonthlyDetails = categories[index]
                        }
                        .tag(index)
                        .padding(.horizontal, 12)
                        .simultaneousGesture(categoryDragGesture)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 300)
                .onChange(of: currentCategoryIndex) {
                    amountText = ""
                }

                categoryNavigationButton(systemName: "chevron.left") {
                    selectPreviousCategory()
                }
            }
            .padding(.horizontal, 8)

            Button {
                openCategorySheet()
            } label: {
                Label("הוסף קטגוריה", systemImage: "plus.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .padding(.top, 8)

            VStack(spacing: 14) {
                if selectedCategory != nil {
                    HStack(spacing: 0) {
                        Text("₪")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 54)

                        TextField("סכום", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .padding(.vertical, 12)
                            .onChange(of: amountText) { _, newValue in
                                let sanitized = sanitizeAmountInput(newValue)

                                if sanitized != newValue {
                                    amountText = sanitized
                                }
                            }
                    }
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 44)
                }
            }
            .frame(height: 126)

            Spacer(minLength: 20)

            Button {
                prepareExpenseNameStep()
            } label: {
                Text("הוסף")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isAmountValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private var menuButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.28)) {
                isSideMenuOpen = true
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("תפריט")
    }

    private var recurringExpenseButton: some View {
        HStack {
            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRecurringExpensePresented = true
                }
            } label: {
                ZStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 25, weight: .semibold))

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .background(Circle().fill(Color(.systemBackground)))
                }
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("הוסף הוצאה קבועה")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var sideMenuOverlay: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    closeSideMenu()
                }

            SideMenuView(
                appTheme: $appTheme,
                onThemeChanged: { theme in
                    Storage.saveAppTheme(theme)
                },
                onSelect: { option in
                    selectedMenuOption = option
                    closeSideMenu()

                    if option == .manageCategories {
                        isManageCategoriesPresented = true
                    } else if option == .settings {
                        isSettingsPresented = true
                    } else if option == .manageRecurringExpenses {
                        isManageRecurringExpensesPresented = true
                    } else if option == .pastExpenses {
                        isPastExpensesPresented = true
                    } else if option == .addToCategoryLater {
                        isBackfillExpensePresented = true
                    }
                }
            )
            .frame(width: 260)
            .frame(maxHeight: .infinity)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.18), radius: 18, x: 8, y: 0)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    private var recurringExpenseOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture {
                    isRecurringExpensePresented = false
                }

            RecurringExpenseModalView(
                categories: categories,
                onSave: saveRecurringExpense,
                onCancel: {
                    isRecurringExpensePresented = false
                }
            )
            .frame(maxWidth: 360)
            .padding(.horizontal, 22)
        }
        .ignoresSafeArea()
    }

    private var selectedCategory: ExpenseCategory? {
        guard categories.indices.contains(currentCategoryIndex) else {
            return nil
        }

        return categories[currentCategoryIndex]
    }

    private var categoryPositionText: String {
        guard !categories.isEmpty else {
            return "0/0"
        }

        return "\(currentCategoryIndex + 1)/\(categories.count)"
    }

    private var isAmountValid: Bool {
        guard selectedCategory != nil else {
            return false
        }

        let parts = amountText.split(separator: ".", omittingEmptySubsequences: false)

        guard !amountText.isEmpty,
              parts.count <= 2,
              parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
            return false
        }

        guard let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) else {
            return false
        }

        return amount > 0
    }

    private var categoryDragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                if value.translation.width <= -dragThreshold {
                    selectNextCategory()
                } else if value.translation.width >= dragThreshold {
                    selectPreviousCategory()
                }
            }
    }

    private func prepareExpenseNameStep() {
        guard isAmountValid,
              let selectedCategory,
              let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
              amount > 0 else {
            return
        }

        pendingExpense = Expense(
            categoryId: selectedCategory.id,
            categoryName: selectedCategory.name,
            amount: amount,
            createdAt: Date(),
            name: nil
        )
        expenseName = ""
        isNamingSheetPresented = true
    }

    private func savePendingExpenseWithName() {
        let trimmedName = expenseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty,
              let pendingExpense else {
            return
        }

        saveExpense(pendingExpense.withName(trimmedName))
    }

    private func savePendingExpenseWithoutName() {
        guard let pendingExpense else {
            return
        }

        saveExpense(pendingExpense)
    }

    private func saveExpense(_ expense: Expense) {
        expenses.append(expense)
        Storage.saveExpenses(expenses)
        pendingExpense = nil
        expenseName = ""
        amountText = ""
        isNamingSheetPresented = false
    }

    private func selectNextCategory() {
        guard !categories.isEmpty else {
            return
        }

        currentCategoryIndex = (currentCategoryIndex + 1) % categories.count
    }

    private func selectPreviousCategory() {
        guard !categories.isEmpty else {
            return
        }

        currentCategoryIndex = (currentCategoryIndex + categories.count - 1) % categories.count
    }

    private func sanitizeAmountInput(_ input: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false

        for character in input {
            if character.isNumber {
                sanitized.append(character)
            } else if character == ".", !hasDecimalSeparator {
                sanitized.append(character)
                hasDecimalSeparator = true
            }
        }

        return sanitized
    }

    private func categoryNavigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .frame(width: 42, height: 76)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(systemName == "chevron.left" ? "הקטגוריה הבאה" : "הקטגוריה הקודמת")
    }

    private func monthlyTotal(for category: ExpenseCategory) -> Decimal {
        monthlyExpenses(for: category)
            .reduce(Decimal(0)) { total, expense in
                total + expense.amount
            }
    }

    private func monthlyExpenses(for category: ExpenseCategory) -> [Expense] {
        let calendar = Calendar.current
        let now = Date()

        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else {
            return []
        }

        return expenses
            .filter { expense in
                expense.categoryId == category.id && expense.createdAt >= monthStart
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func openCategorySheet() {
        newCategoryName = ""
        newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
        newCategoryTintName = CategoryAppearanceOption.defaultTintName
        categoryNameError = nil
        isCategorySheetPresented = true
    }

    private func closeCategorySheet() {
        newCategoryName = ""
        newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
        newCategoryTintName = CategoryAppearanceOption.defaultTintName
        categoryNameError = nil
        isCategorySheetPresented = false
    }

    private func saveNewCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return
        }

        if categories.contains(where: { $0.name.normalizedForComparison == trimmedName.normalizedForComparison }) {
            categoryNameError = "קטגוריה זו כבר קיימת"
            return
        }

        categories.append(ExpenseCategory(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            systemImageName: newCategorySystemImageName,
            tintName: newCategoryTintName
        ))
        currentCategoryIndex = categories.count - 1
        amountText = ""
        Storage.saveCategories(categories)
        closeCategorySheet()
    }

    private func saveMonthlyTarget(_ category: ExpenseCategory, _ monthlyTarget: Decimal?) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }

        categories[index] = categories[index].updated(
            name: categories[index].name,
            systemImageName: categories[index].systemImageName,
            tintName: categories[index].tintName,
            monthlyTarget: monthlyTarget
        )
        Storage.saveCategories(categories)
    }

    private func saveRecurringExpense(
        name: String,
        amount: Decimal,
        existingCategoryId: String?,
        newCategoryName: String?,
        newCategorySystemImageName: String,
        newCategoryTintName: String
    ) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, amount > 0 else {
            return "צריך שם וסכום תקין"
        }

        let category: ExpenseCategory

        if let existingCategoryId,
           let existingCategory = categories.first(where: { $0.id == existingCategoryId }) {
            category = existingCategory
        } else if let resolvedCategory = resolveCategory(
            existingCategoryId: nil,
            newCategoryName: newCategoryName,
            newCategorySystemImageName: newCategorySystemImageName,
            newCategoryTintName: newCategoryTintName
        ) {
            category = resolvedCategory
        } else {
            return "צריך לבחור או ליצור קטגוריה"
        }

        recurringExpenses.append(RecurringExpense(
            name: trimmedName,
            amount: amount,
            categoryId: category.id,
            categoryName: category.name,
            createdAt: Date()
        ))
        Storage.saveRecurringExpenses(recurringExpenses)
        isRecurringExpensePresented = false

        return nil
    }

    private func saveBackfillExpenses(
        mode: BackfillExpenseMode,
        amount: Decimal,
        month: Date,
        monthCount: Int,
        existingCategoryId: String?,
        newCategoryName: String?,
        expenseName: String
    ) -> String? {
        let trimmedExpenseName = expenseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedExpenseName.isEmpty else {
            return "צריך שם הוצאה"
        }

        guard amount > 0 else {
            return "צריך סכום תקין"
        }

        guard let category = resolveCategory(existingCategoryId: existingCategoryId, newCategoryName: newCategoryName) else {
            return "צריך לבחור או ליצור קטגוריה"
        }

        let calendar = Calendar.current
        let normalizedMonth = calendar.monthStart(for: month)
        let safeMonthCount = max(monthCount, 1)

        switch mode {
        case .oneTime:
            expenses.append(Expense(
                categoryId: category.id,
                categoryName: category.name,
                amount: amount,
                createdAt: normalizedMonth,
                name: trimmedExpenseName,
                source: .backfill
            ))
        case .recurring:
            for offset in 0..<safeMonthCount {
                guard let expenseMonth = calendar.date(byAdding: .month, value: -offset, to: normalizedMonth) else {
                    continue
                }

                expenses.append(Expense(
                    categoryId: category.id,
                    categoryName: category.name,
                    amount: amount,
                    createdAt: expenseMonth,
                    name: trimmedExpenseName,
                    source: .backfill
                ))
            }
        }

        Storage.saveExpenses(expenses)
        isBackfillExpensePresented = false

        return nil
    }

    private func resolveCategory(
        existingCategoryId: String?,
        newCategoryName: String?,
        newCategorySystemImageName: String = CategoryAppearanceOption.defaultSystemImageName,
        newCategoryTintName: String = CategoryAppearanceOption.defaultTintName
    ) -> ExpenseCategory? {
        if let existingCategoryId,
           let existingCategory = categories.first(where: { $0.id == existingCategoryId }) {
            return existingCategory
        }

        guard let newCategoryName else {
            return nil
        }

        let trimmedCategoryName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCategoryName.isEmpty else {
            return nil
        }

        if let existingCategory = categories.first(where: { $0.name.normalizedForComparison == trimmedCategoryName.normalizedForComparison }) {
            return existingCategory
        }

        let category = ExpenseCategory(
            id: "custom-\(UUID().uuidString)",
            name: trimmedCategoryName,
            systemImageName: newCategorySystemImageName,
            tintName: newCategoryTintName
        )
        categories.append(category)
        currentCategoryIndex = categories.count - 1
        Storage.saveCategories(categories)

        return category
    }

    private func closeSideMenu() {
        withAnimation(.snappy(duration: 0.24)) {
            isSideMenuOpen = false
        }
    }

    private func persistManagedCategories() {
        if currentCategoryIndex >= categories.count {
            currentCategoryIndex = max(categories.count - 1, 0)
        }

        Storage.saveExpenses(expenses)
        Storage.saveCategories(categories)
        Storage.saveDeletedCategoryBuckets(deletedCategoryBuckets)
    }

    private func loadStoredData() {
        expenses = Storage.loadExpenses()
        recurringExpenses = Storage.loadRecurringExpenses()
        categories = Storage.loadCategories(defaults: ExpenseCategory.placeholderCategories)
        deletedCategoryBuckets = Storage.loadDeletedCategoryBuckets()
        appTheme = Storage.loadAppTheme()
    }
}

private struct SideMenuView: View {
    @Binding var appTheme: AppTheme
    let onThemeChanged: (AppTheme) -> Void
    let onSelect: (MenuOption) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer()

                Button {
                    appTheme = appTheme.toggledLightDark
                    onThemeChanged(appTheme)
                } label: {
                    Image(systemName: appTheme.themeToggleSystemImageName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appTheme.themeToggleAccessibilityLabel)
            }
            .padding(.top, 54)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            ForEach(MenuOption.allCases) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.systemImageName)
                            .frame(width: 22)

                        Text(option.title)
                            .font(.headline)

                        Spacer()
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private enum MenuOption: String, CaseIterable, Identifiable {
    case settings
    case manageCategories
    case manageRecurringExpenses
    case pastExpenses
    case addToCategoryLater

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .settings:
            "הגדרות"
        case .manageCategories:
            "נהל קטגוריות"
        case .manageRecurringExpenses:
            "נהל הוצאות חוזרות"
        case .pastExpenses:
            "צפה בהוצאות בעבר"
        case .addToCategoryLater:
            "הוסף הוצאה בדיעבד"
        }
    }

    var systemImageName: String {
        switch self {
        case .settings:
            "gearshape"
        case .manageCategories:
            "square.grid.2x2"
        case .manageRecurringExpenses:
            "arrow.triangle.2.circlepath"
        case .pastExpenses:
            "calendar"
        case .addToCategoryLater:
            "clock.arrow.circlepath"
        }
    }
}

private struct ExpenseNameView: View {
    @Binding var expenseName: String
    let onSave: () -> Void
    let onSkip: () -> Void

    private var isNameValid: Bool {
        !expenseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 22) {
            Text("שם להוצאה")
                .font(.title3.bold())

            TextField("לדוגמה: קפה, סופר, דלק", text: $expenseName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding(.vertical, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                Button("מ׳כפת׳ך") {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("שמור") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isNameValid)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct AddCategoryView: View {
    @Binding var categoryName: String
    @Binding var selectedSystemImageName: String
    @Binding var selectedTintName: String
    @Binding var errorMessage: String?
    let onSave: () -> Void
    let onCancel: () -> Void

    private var isNameValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("שם קטגוריה")
                .font(.title3.bold())

            TextField("לדוגמה: אוכל בחוץ", text: $categoryName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding(.vertical, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: categoryName) {
                    errorMessage = nil
                }

            CategoryAppearancePicker(
                selectedSystemImageName: $selectedSystemImageName,
                selectedTintName: $selectedTintName
            )

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button("ביטול") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("שמור") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isNameValid)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct SettingsView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {}
            .navigationTitle("הגדרות")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct ManageRecurringExpensesView: View {
    @Binding var categories: [ExpenseCategory]
    @Binding var recurringExpenses: [RecurringExpense]
    let onPersist: () -> Void
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var selectedCategoryGroup: RecurringExpenseCategoryGroup?
    @State private var expenseBeingEdited: RecurringExpense?
    @State private var isAddRecurringPresented = false

    private var categoryGroups: [RecurringExpenseCategoryGroup] {
        Dictionary(grouping: recurringExpenses, by: \.categoryId)
            .compactMap { _, expenses in
                guard let firstExpense = expenses.first else {
                    return nil
                }

                return RecurringExpenseCategoryGroup(
                    categoryId: firstExpense.categoryId,
                    categoryName: firstExpense.categoryName,
                    systemImageName: groupCategory(for: firstExpense)?.systemImageName ?? CategoryAppearanceOption.defaultSystemImageName,
                    tintName: groupCategory(for: firstExpense)?.tintName ?? CategoryAppearanceOption.defaultTintName,
                    expenses: expenses.sorted { $0.name < $1.name }
                )
            }
            .sorted { $0.categoryName < $1.categoryName }
    }

    private func groupCategory(for expense: RecurringExpense) -> ExpenseCategory? {
        categories.first { $0.id == expense.categoryId }
    }

    private var searchResults: [RecurringExpense] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).normalizedForComparison

        guard !query.isEmpty else {
            return []
        }

        return recurringExpenses
            .filter { $0.name.normalizedForComparison.contains(query) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("חיפוש לפי שם הוצאה קבועה", text: $searchText)
                        .keyboardType(.default)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }

                if !searchResults.isEmpty {
                    Section("תוצאות חיפוש") {
                        ForEach(searchResults) { expense in
                            VStack(alignment: .trailing, spacing: 4) {
                                highlightedExpenseName(expense.name)
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    CategoryIconView(
                                        systemImageName: groupCategory(for: expense)?.systemImageName ?? CategoryAppearanceOption.defaultSystemImageName,
                                        tint: (groupCategory(for: expense)?.tintName ?? CategoryAppearanceOption.defaultTintName).categoryTint,
                                        size: 16
                                    )

                                    Text("\(expense.categoryName) - \(expense.name) - \(expense.amount.formattedShekelAmount)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }

                Section("קטגוריות עם הוצאות חוזרות") {
                    if categoryGroups.isEmpty {
                        Text("אין עדיין הוצאות חוזרות")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(categoryGroups) { group in
                            RecurringCategoryGroupRow(group: group) {
                                selectedCategoryGroup = group
                            }
                        }
                    }
                }
            }
            .navigationTitle("נהל הוצאות חוזרות")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddRecurringPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("הוסף הוצאה חוזרת")
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $isAddRecurringPresented) {
            RecurringExpenseModalView(
                categories: categories,
                onSave: saveNewRecurringExpense,
                onCancel: {
                    isAddRecurringPresented = false
                }
            )
            .presentationDetents([.height(620)])
        }
        .sheet(item: $selectedCategoryGroup) { group in
            RecurringExpenseGroupDetailView(
                group: group,
                onEdit: { expense in
                    selectedCategoryGroup = nil
                    expenseBeingEdited = expense
                },
                onDelete: deleteRecurringExpense,
                onClose: {
                    selectedCategoryGroup = nil
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $expenseBeingEdited) { expense in
            EditRecurringExpenseView(
                expense: expense,
                onSave: saveEditedRecurringExpense,
                onCancel: {
                    expenseBeingEdited = nil
                }
            )
            .presentationDetents([.height(320)])
        }
    }

    private func highlightedExpenseName(_ name: String) -> Text {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty,
              let range = name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return Text(name)
        }

        let prefix = String(name[..<range.lowerBound])
        let match = String(name[range])
        let suffix = String(name[range.upperBound...])

        return Text(prefix) + Text(match).bold() + Text(suffix)
    }

    private func saveNewRecurringExpense(
        name: String,
        amount: Decimal,
        existingCategoryId: String?,
        newCategoryName: String?,
        newCategorySystemImageName: String,
        newCategoryTintName: String
    ) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, amount > 0 else {
            return "צריך שם וסכום תקין"
        }

        guard let category = resolveRecurringCategory(
            existingCategoryId: existingCategoryId,
            newCategoryName: newCategoryName,
            newCategorySystemImageName: newCategorySystemImageName,
            newCategoryTintName: newCategoryTintName
        ) else {
            return "צריך לבחור או ליצור קטגוריה"
        }

        recurringExpenses.append(RecurringExpense(
            name: trimmedName,
            amount: amount,
            categoryId: category.id,
            categoryName: category.name,
            createdAt: Date()
        ))
        onPersist()
        isAddRecurringPresented = false
        return nil
    }

    private func resolveRecurringCategory(
        existingCategoryId: String?,
        newCategoryName: String?,
        newCategorySystemImageName: String,
        newCategoryTintName: String
    ) -> ExpenseCategory? {
        if let existingCategoryId,
           let existingCategory = categories.first(where: { $0.id == existingCategoryId }) {
            return existingCategory
        }

        guard let newCategoryName else {
            return nil
        }

        let trimmedCategoryName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCategoryName.isEmpty else {
            return nil
        }

        if let existingCategory = categories.first(where: { $0.name.normalizedForComparison == trimmedCategoryName.normalizedForComparison }) {
            return existingCategory
        }

        let category = ExpenseCategory(
            id: "custom-\(UUID().uuidString)",
            name: trimmedCategoryName,
            systemImageName: newCategorySystemImageName,
            tintName: newCategoryTintName
        )
        categories.append(category)
        return category
    }

    private func deleteRecurringExpense(_ expense: RecurringExpense) {
        recurringExpenses.removeAll { $0.id == expense.id }
        onPersist()
    }

    private func saveEditedRecurringExpense(_ expense: RecurringExpense, name: String, amount: Decimal) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return "צריך שם הוצאה"
        }

        guard amount > 0 else {
            return "צריך סכום תקין"
        }

        guard let index = recurringExpenses.firstIndex(where: { $0.id == expense.id }) else {
            expenseBeingEdited = nil
            return nil
        }

        recurringExpenses[index] = expense.updated(name: trimmedName, amount: amount)
        onPersist()
        expenseBeingEdited = nil
        return nil
    }
}

private struct RecurringCategoryGroupRow: View {
    let group: RecurringExpenseCategoryGroup
    let onDetails: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(
                systemImageName: group.systemImageName,
                tint: group.tintName.categoryTint,
                size: 22
            )
            .frame(width: 34, height: 34)

            VStack(alignment: .trailing, spacing: 5) {
                Text(group.categoryName)
                    .font(.headline)

                Text(group.totalAmount.formattedShekelAmount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onDetails()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("פירוט הוצאות חוזרות")
        }
        .padding(.vertical, 6)
    }
}

private struct RecurringExpenseGroupDetailView: View {
    let group: RecurringExpenseCategoryGroup
    let onEdit: (RecurringExpense) -> Void
    let onDelete: (RecurringExpense) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(group.expenses) { expense in
                        HStack(spacing: 12) {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(expense.name)
                                    .font(.headline)

                                Text(expense.amount.formattedShekelAmount)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                onEdit(expense)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                onDelete(expense)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    HStack(spacing: 8) {
                        CategoryIconView(
                            systemImageName: group.systemImageName,
                            tint: group.tintName.categoryTint,
                            size: 16
                        )

                        Text(group.categoryName)
                    }
                }
            }
            .navigationTitle("הוצאות חוזרות")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

private struct CategoryMonthlyDetailsView: View {
    let category: ExpenseCategory
    let expenses: [Expense]
    let recurringExpenses: [RecurringExpense]
    let onSaveTarget: (ExpenseCategory, Decimal?) -> Void
    let onClose: () -> Void

    @State private var selectedMonth = Date()
    @State private var monthlyTarget: Decimal?
    @State private var isTargetEditorPresented = false

    init(
        category: ExpenseCategory,
        expenses: [Expense],
        recurringExpenses: [RecurringExpense],
        onSaveTarget: @escaping (ExpenseCategory, Decimal?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.category = category
        self.expenses = expenses
        self.recurringExpenses = recurringExpenses
        self.onSaveTarget = onSaveTarget
        self.onClose = onClose
        _monthlyTarget = State(initialValue: category.monthlyTarget)
    }

    private var filteredExpenses: [Expense] {
        expenses
            .filter { Calendar.current.isDate($0.createdAt, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var monthTotal: Decimal {
        filteredExpenses.reduce(Decimal(0)) { total, expense in
            total + expense.amount
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthNavigationView(selectedMonth: $selectedMonth)

                    MonthlyTargetSummaryView(
                        categoryName: category.name,
                        monthlyTarget: monthlyTarget,
                        spent: monthTotal,
                        selectedMonth: selectedMonth
                    )

                    Button("שנה יעד") {
                        isTargetEditorPresented = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Section("הוצאות החודש") {
                    if filteredExpenses.isEmpty {
                        Text("אין הוצאות בחודש הזה")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredExpenses) { expense in
                            ExpenseDetailRow(expense: expense)
                        }
                    }
                }

                if !recurringExpenses.isEmpty {
                    Section("הוצאות חוזרות") {
                        ForEach(recurringExpenses) { expense in
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.blue)
                                    .frame(width: 26)

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(expense.name)
                                        .font(.headline)
                                        .foregroundStyle(.blue)

                                    Text(expense.amount.formattedShekelAmount)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.blue.opacity(0.8))
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(category.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $isTargetEditorPresented) {
            EditMonthlyTargetView(
                categoryName: category.name,
                monthlyTarget: monthlyTarget,
                onSave: { target in
                    monthlyTarget = target
                    onSaveTarget(category, target)
                    isTargetEditorPresented = false
                },
                onCancel: {
                    isTargetEditorPresented = false
                }
            )
            .presentationDetents([.height(240)])
        }
    }
}

private struct PastExpensesView: View {
    let categories: [ExpenseCategory]
    let expenses: [Expense]
    let recurringExpenses: [RecurringExpense]
    let onClose: () -> Void

    @State private var selectedMonth = Date()
    @State private var selectedCategoryId: String?

    private var visibleCategories: [ExpenseCategory] {
        let activeCategoryIds = Set(expensesForSelectedMonth.map(\.categoryId))
        return categories.filter { activeCategoryIds.contains($0.id) }
    }

    private var expensesForSelectedMonth: [Expense] {
        expenses
            .filter { Calendar.current.isDate($0.createdAt, equalTo: selectedMonth, toGranularity: .month) }
            .filter { expense in
                guard let selectedCategoryId else {
                    return true
                }

                return expense.categoryId == selectedCategoryId
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var groupedExpenses: [ExpenseCategoryExpenseGroup] {
        Dictionary(grouping: expensesForSelectedMonth, by: \.categoryId)
            .compactMap { categoryId, groupedExpenses in
                let categoryName = categories.first(where: { $0.id == categoryId })?.name
                    ?? groupedExpenses.first?.categoryName
                    ?? "קטגוריה"

                return ExpenseCategoryExpenseGroup(
                    categoryId: categoryId,
                    categoryName: categoryName,
                    expenses: groupedExpenses
                )
            }
            .sorted { $0.categoryName < $1.categoryName }
    }

    private var total: Decimal {
        expensesForSelectedMonth.reduce(Decimal(0)) { total, expense in
            total + expense.amount
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthNavigationView(selectedMonth: $selectedMonth)

                    Picker("קטגוריה", selection: selectedCategoryBinding) {
                        Text("כל הקטגוריות").tag(Optional<String>.none)

                        ForEach(visibleCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }

                    Text("סה״כ \(total.formattedShekelAmount)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if groupedExpenses.isEmpty {
                    Section {
                        Text("אין הוצאות בחודש הזה")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(groupedExpenses) { group in
                        Section("\(group.categoryName) - \(group.total.formattedShekelAmount)") {
                            ForEach(group.expenses) { expense in
                                ExpenseDetailRow(expense: expense)
                            }
                        }
                    }
                }
            }
            .navigationTitle("הוצאות בעבר")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var selectedCategoryBinding: Binding<String?> {
        Binding(
            get: { selectedCategoryId },
            set: { selectedCategoryId = $0 }
        )
    }
}

private struct EditMonthlyTargetView: View {
    let categoryName: String
    let monthlyTarget: Decimal?
    let onSave: (Decimal?) -> Void
    let onCancel: () -> Void

    @State private var targetText: String
    @State private var errorMessage: String?

    init(
        categoryName: String,
        monthlyTarget: Decimal?,
        onSave: @escaping (Decimal?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.categoryName = categoryName
        self.monthlyTarget = monthlyTarget
        self.onSave = onSave
        self.onCancel = onCancel
        _targetText = State(initialValue: monthlyTarget?.plainString ?? "")
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 18) {
            Text("שנה יעד")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(categoryName)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 0) {
                Text("₪")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42)

                TextField("הוסף יעד חודשי", text: $targetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold))
                    .padding(.vertical, 12)
                    .onChange(of: targetText) { _, newValue in
                        let sanitized = sanitizeAmountInput(newValue)

                        if sanitized != newValue {
                            targetText = sanitized
                        }

                        errorMessage = nil
                    }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button("ביטול") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("שמור") {
                    let trimmedValue = targetText.trimmingCharacters(in: .whitespacesAndNewlines)

                    if trimmedValue.isEmpty {
                        onSave(nil)
                        return
                    }

                    guard let target = Decimal(string: trimmedValue, locale: Locale(identifier: "en_US_POSIX")),
                          target > 0 else {
                        errorMessage = "יעד חייב להיות חיובי"
                        return
                    }

                    onSave(target)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func sanitizeAmountInput(_ input: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false

        for character in input {
            if character.isNumber {
                sanitized.append(character)
            } else if character == ".", !hasDecimalSeparator {
                sanitized.append(character)
                hasDecimalSeparator = true
            }
        }

        return sanitized
    }
}

private struct MonthlyTargetSummaryView: View {
    let categoryName: String
    let monthlyTarget: Decimal?
    let spent: Decimal
    let selectedMonth: Date

    private var target: Decimal? {
        monthlyTarget
    }

    private var targetPercentage: Decimal? {
        guard let target, target > 0 else {
            return nil
        }

        return (spent / target) * 100
    }

    private var remainingAmount: Decimal? {
        guard let target else {
            return nil
        }

        return target - spent
    }

    private var categoryNameColor: Color {
        guard let percentage = targetPercentage, percentage > 100 else {
            return .primary
        }

        return percentage > 105 ? .red : .yellow
    }

    private var daysLeftInMonth: Int {
        Calendar.current.daysLeftInMonth(from: selectedMonth)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if let target, target > 0, let targetPercentage, let remainingAmount {
                (
                    Text("מתחילת החודש הוצאת על ")
                    + Text(categoryName).foregroundColor(categoryNameColor).bold()
                    + Text(" \(spent.formattedShekelAmount), שהם \(targetPercentage.formattedPercentText) מסך היעד החודשי שלך.")
                )
                .font(.headline)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

                if remainingAmount >= 0 {
                    Text("נותרו \(remainingAmount.formattedShekelAmount) להוצאה עד סוף החודש.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text("יש חריגה של \((remainingAmount * -1).formattedShekelAmount) מהיעד החודשי.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(targetPercentage > 105 ? .red : .yellow)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Text("נותרו \(daysLeftInMonth) ימים לסוף החודש.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("סה״כ \(spent.formattedShekelAmount)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("לא הוגדר יעד חודשי לקטגוריה הזו.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct MonthNavigationView: View {
    @Binding var selectedMonth: Date

    var body: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            Spacer()

            DatePicker("חודש", selection: $selectedMonth, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
        }
    }

    private func moveMonth(by value: Int) {
        selectedMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) ?? selectedMonth
    }
}

private struct ExpenseDetailRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            if expense.source == .backfill {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.red)
                    .frame(width: 26)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.name ?? "הוצאה")
                    .font(.headline)
                    .foregroundStyle(expense.source == .backfill ? .red : .primary)

                Text("\(expense.createdAt.shortDateText) - \(expense.amount.formattedShekelAmount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(expense.source == .backfill ? .red.opacity(0.8) : .secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 4)
    }
}

private struct EditRecurringExpenseView: View {
    let expense: RecurringExpense
    let onSave: (RecurringExpense, String, Decimal) -> String?
    let onCancel: () -> Void

    @State private var name: String
    @State private var amountText: String
    @State private var errorMessage: String?

    init(
        expense: RecurringExpense,
        onSave: @escaping (RecurringExpense, String, Decimal) -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.expense = expense
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: expense.name)
        _amountText = State(initialValue: expense.amount.plainString)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("עריכת הוצאה חוזרת")
                .font(.title3.bold())

            TextField("שם הוצאה", text: $name)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .font(.headline)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: name) {
                    errorMessage = nil
                }

            HStack(spacing: 0) {
                Text("₪")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42)

                TextField("סכום", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold))
                    .padding(.vertical, 12)
                    .onChange(of: amountText) { _, newValue in
                        let sanitized = sanitizeAmountInput(newValue)

                        if sanitized != newValue {
                            amountText = sanitized
                        }

                        errorMessage = nil
                    }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button("ביטול") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("שמור") {
                    guard let amount = parsedAmount else {
                        errorMessage = "סכום לא תקין"
                        return
                    }

                    errorMessage = onSave(expense, name, amount)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func sanitizeAmountInput(_ input: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false

        for character in input {
            if character.isNumber {
                sanitized.append(character)
            } else if character == ".", !hasDecimalSeparator {
                sanitized.append(character)
                hasDecimalSeparator = true
            }
        }

        return sanitized
    }
}

private struct EditCategoryView: View {
    let category: ExpenseCategory
    let onSave: (ExpenseCategory, String, String, String, Decimal?) -> String?
    let onCancel: () -> Void

    @State private var categoryName: String
    @State private var selectedSystemImageName: String
    @State private var selectedTintName: String
    @State private var monthlyTargetText: String
    @State private var errorMessage: String?

    init(
        category: ExpenseCategory,
        onSave: @escaping (ExpenseCategory, String, String, String, Decimal?) -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.category = category
        self.onSave = onSave
        self.onCancel = onCancel
        _categoryName = State(initialValue: category.name)
        _selectedSystemImageName = State(initialValue: category.systemImageName)
        _selectedTintName = State(initialValue: category.tintName)
        _monthlyTargetText = State(initialValue: category.monthlyTarget?.plainString ?? "")
    }

    private var isNameValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("עריכת קטגוריה")
                .font(.title3.bold())

            TextField("שם קטגוריה", text: $categoryName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding(.vertical, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: categoryName) {
                    errorMessage = nil
                }

            CategoryAppearancePicker(
                selectedSystemImageName: $selectedSystemImageName,
                selectedTintName: $selectedTintName
            )

            HStack(spacing: 0) {
                Text("₪")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42)

                TextField("הוסף יעד חודשי", text: $monthlyTargetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical, 12)
                    .onChange(of: monthlyTargetText) { _, newValue in
                        let sanitized = sanitizeAmountInput(newValue)

                        if sanitized != newValue {
                            monthlyTargetText = sanitized
                        }

                        errorMessage = nil
                    }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button("ביטול") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("שמור") {
                    if !monthlyTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       monthlyTarget == nil {
                        errorMessage = "יעד חייב להיות חיובי"
                        return
                    }

                    errorMessage = onSave(
                        category,
                        categoryName,
                        selectedSystemImageName,
                        selectedTintName,
                        monthlyTarget
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isNameValid)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var monthlyTarget: Decimal? {
        let trimmedValue = monthlyTargetText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else {
            return nil
        }

        guard let target = Decimal(string: trimmedValue, locale: Locale(identifier: "en_US_POSIX")),
              target > 0 else {
            return nil
        }

        return target
    }

    private func sanitizeAmountInput(_ input: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false

        for character in input {
            if character.isNumber {
                sanitized.append(character)
            } else if character == ".", !hasDecimalSeparator {
                sanitized.append(character)
                hasDecimalSeparator = true
            }
        }

        return sanitized
    }
}

private struct CategoryAppearancePicker: View {
    @Binding var selectedSystemImageName: String
    @Binding var selectedTintName: String

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(42), spacing: 10), count: 4), spacing: 10) {
                ForEach(CategoryAppearanceOption.systemImages, id: \.self) { systemImageName in
                    Button {
                        selectedSystemImageName = systemImageName
                    } label: {
                        CategoryAppearanceOptionButton(
                            value: systemImageName,
                            selectedValue: selectedSystemImageName,
                            tintName: selectedTintName
                        )
                    }
                    .buttonStyle(.plain)
                }

            }

            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Circle()
                            .stroke(selectedSystemImageName.categoryEmoji == nil ? .clear : selectedTintName.categoryTint, lineWidth: 3)
                    }

                if selectedSystemImageName.categoryEmoji == nil {
                    Image(systemName: "face.smiling")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(selectedTintName.categoryTint)
                }

                TextField("", text: emojiBinding)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .opacity(selectedSystemImageName.categoryEmoji == nil ? 0.02 : 1)
                    .accessibilityLabel("בחר אימוג׳י")
            }

            HStack(spacing: 10) {
                ForEach(CategoryAppearanceOption.tintNames, id: \.self) { tintName in
                    Button {
                        selectedTintName = tintName
                    } label: {
                        Circle()
                            .fill(tintName.categoryTint)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle()
                                    .stroke(.primary.opacity(selectedTintName == tintName ? 0.8 : 0), lineWidth: 3)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emojiBinding: Binding<String> {
        Binding(
            get: {
                selectedSystemImageName.categoryEmoji ?? ""
            },
            set: { newValue in
                guard let firstCharacter = newValue.trimmingCharacters(in: .whitespacesAndNewlines).first else {
                    return
                }

                selectedSystemImageName = "emoji:\(String(firstCharacter))"
            }
        )
    }
}

private struct CategoryAppearanceOptionButton: View {
    let value: String
    let selectedValue: String
    let tintName: String

    var body: some View {
        CategoryIconView(
            systemImageName: value,
            tint: tintName.categoryTint,
            size: 20
        )
        .frame(width: 38, height: 38)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedValue == value ? tintName.categoryTint : .clear, lineWidth: 3)
        }
    }
}

private struct CategoryIconView: View {
    let systemImageName: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        if let emoji = systemImageName.categoryEmoji {
            Text(emoji)
                .font(.system(size: size + 5))
        } else {
            Image(systemName: systemImageName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

private struct BackfillExpenseView: View {
    let categories: [ExpenseCategory]
    let onSave: (BackfillExpenseMode, Decimal, Date, Int, String?, String?, String) -> String?
    let onClose: () -> Void

    @State private var mode: BackfillExpenseMode = .oneTime
    @State private var expenseName = ""
    @State private var amountText = ""
    @State private var selectedMonth = Date()
    @State private var monthCount = 1
    @State private var categoryMode: RecurringCategoryMode = .existing
    @State private var selectedCategoryId: String?
    @State private var newCategoryName = ""
    @State private var shouldContinueAddingToCategory = true
    @State private var errorMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        let hasName = !expenseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidAmount = (parsedAmount ?? 0) > 0
        let hasCategory = categoryMode == .existing
            ? selectedCategoryId != nil
            : !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return hasName && hasValidAmount && hasCategory && monthCount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("סוג הוצאה", selection: $mode) {
                        ForEach(BackfillExpenseMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(mode.detailsTitle) {
                    TextField("שם ההוצאה", text: $expenseName)
                        .keyboardType(.default)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: expenseName) {
                            errorMessage = nil
                        }

                    HStack(spacing: 0) {
                        Text("₪")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 42)

                        TextField("סכום", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: amountText) { _, newValue in
                                let sanitized = sanitizeAmountInput(newValue)

                                if sanitized != newValue {
                                    amountText = sanitized
                                }

                                errorMessage = nil
                            }
                    }

                    DatePicker("בחר תאריך", selection: $selectedMonth, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    if mode == .recurring {
                        Stepper(value: $monthCount, in: 1...120) {
                            Text("\(monthCount) חודשים")
                        }
                    }
                }

                Section("שיוך לקטגוריה") {
                    Picker("אפשרות", selection: $categoryMode) {
                        Text("קטגוריה קיימת").tag(RecurringCategoryMode.existing)
                        Text("קטגוריה חדשה").tag(RecurringCategoryMode.new)
                    }
                    .pickerStyle(.segmented)

            if categoryMode == .existing, !categories.isEmpty {
                Picker("קטגוריה", selection: selectedCategoryBinding) {
                    ForEach(categories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                        }
            } else {
                TextField("שם קטגוריה חדשה", text: $newCategoryName)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: newCategoryName) {
                        errorMessage = nil
                    }
                    }
                }

                if mode == .recurring {
                    Section("האם להמשיך להוסיף לקטגוריה שנבחרה?") {
                        Picker("המשך הוספה", selection: $shouldContinueAddingToCategory) {
                            Text("כן").tag(true)
                            Text("לא").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("הוסף הוצאה בדיעבד")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("הוסף") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            selectedCategoryId = categories.first?.id

            if categories.isEmpty {
                categoryMode = .new
            }
        }
    }

    private var selectedCategoryBinding: Binding<String?> {
        Binding(
            get: {
                selectedCategoryId ?? categories.first?.id
            },
            set: { selectedCategoryId = $0 }
        )
    }

    private func save() {
        guard let amount = parsedAmount else {
            errorMessage = "סכום לא תקין"
            return
        }

        errorMessage = onSave(
            mode,
            amount,
            selectedMonth,
            mode == .recurring ? monthCount : 1,
            categoryMode == .existing ? selectedCategoryId : nil,
            categoryMode == .new ? newCategoryName : nil,
            expenseName
        )
    }

    private func sanitizeAmountInput(_ input: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false

        for character in input {
            if character.isNumber {
                sanitized.append(character)
            } else if character == ".", !hasDecimalSeparator {
                sanitized.append(character)
                hasDecimalSeparator = true
            }
        }

        return sanitized
    }
}

private struct RecurringExpenseModalView: View {
    let categories: [ExpenseCategory]
    let onSave: (String, Decimal, String?, String?, String, String) -> String?
    let onCancel: () -> Void

    @State private var name = ""
    @State private var amountText = ""
    @State private var categoryMode: RecurringCategoryMode = .existing
    @State private var selectedCategoryId: String?
    @State private var newCategoryName = ""
    @State private var newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
    @State private var newCategoryTintName = CategoryAppearanceOption.defaultTintName
    @State private var errorMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidAmount = (parsedAmount ?? 0) > 0
        let hasCategory = categoryMode == .existing
            ? selectedCategoryId != nil
            : !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return hasName && hasValidAmount && hasCategory
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("סגור")

                Spacer()

                Text("הוסף הוצאה קבועה")
                    .font(.title3.bold())
            }

            TextField("שם ההוצאה", text: $name)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.center)
                .font(.headline)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: name) {
                    errorMessage = nil
                }

            HStack(spacing: 0) {
                Text("₪")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44)

                TextField("סכום", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title2.weight(.semibold))
                    .padding(.vertical, 12)
                    .onChange(of: amountText) { _, newValue in
                        let sanitized = sanitizeAmountInput(newValue)

                        if sanitized != newValue {
                            amountText = sanitized
                        }

                        errorMessage = nil
                    }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

            Picker("קטגוריה", selection: $categoryMode) {
                Text("בחר קיימת").tag(RecurringCategoryMode.existing)
                Text("צור חדשה").tag(RecurringCategoryMode.new)
            }
            .pickerStyle(.segmented)

            if categoryMode == .existing, !categories.isEmpty {
                Picker("בחר קטגוריה", selection: selectedCategoryBinding) {
                    ForEach(categories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                TextField("שם קטגוריה חדשה", text: $newCategoryName)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: newCategoryName) {
                        errorMessage = nil
                    }

                CategoryAppearancePicker(
                    selectedSystemImageName: $newCategorySystemImageName,
                    selectedTintName: $newCategoryTintName
                )
            }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .frame(height: 18)

            Button {
                guard let amount = parsedAmount else {
                    errorMessage = "סכום לא תקין"
                    return
                }

                errorMessage = onSave(
                    name,
                    amount,
                    categoryMode == .existing ? selectedCategoryId : nil,
                    categoryMode == .new ? newCategoryName : nil,
                    newCategorySystemImageName,
                    newCategoryTintName
                )
            } label: {
                Text("שמור")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            selectedCategoryId = categories.first?.id

            if categories.isEmpty {
                categoryMode = .new
            }
        }
    }

    private var selectedCategoryBinding: Binding<String?> {
        Binding(
            get: {
                selectedCategoryId ?? categories.first?.id
            },
            set: { selectedCategoryId = $0 }
        )
    }

    private func sanitizeAmountInput(_ input: String) -> String {
        var sanitized = ""
        var hasDecimalSeparator = false

        for character in input {
            if character.isNumber {
                sanitized.append(character)
            } else if character == ".", !hasDecimalSeparator {
                sanitized.append(character)
                hasDecimalSeparator = true
            }
        }

        return sanitized
    }
}

private enum RecurringCategoryMode {
    case existing
    case new
}

private enum BackfillExpenseMode: String, CaseIterable, Identifiable {
    case oneTime
    case recurring

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .oneTime:
            "חד פעמית"
        case .recurring:
            "חוזרת"
        }
    }

    var detailsTitle: String {
        switch self {
        case .oneTime:
            "סכום ותאריך"
        case .recurring:
            "סכום ומשך"
        }
    }
}

private enum ReassignCategoryMode {
    case existing
    case new
}

private struct ManageCategoriesView: View {
    @Binding var categories: [ExpenseCategory]
    @Binding var expenses: [Expense]
    let recurringExpenses: [RecurringExpense]
    @Binding var deletedCategoryBuckets: [DeletedCategoryBucket]
    @Binding var currentCategoryIndex: Int

    let monthlyTotal: (ExpenseCategory) -> Decimal
    let onPersist: () -> Void
    let onClose: () -> Void

    @State private var categoryBeingRenamed: ExpenseCategory?
    @State private var categoryPendingDelete: ExpenseCategory?
    @State private var bucketPendingReassignment: DeletedCategoryBucket?
    @State private var reassignMode: ReassignCategoryMode = .existing
    @State private var reassignNewCategoryName = ""
    @State private var categoryForMonthlyDetails: ExpenseCategory?
    @State private var categoryForTargetEdit: ExpenseCategory?

    var body: some View {
        NavigationStack {
            List {
                Section("קטגוריות פעילות") {
                    ForEach(categories) { category in
                        CategoryManagementRow(
                            category: category,
                            monthlyTotal: monthlyTotal(category),
                            onRename: {
                                startRenaming(category)
                            },
                            onDetails: {
                                categoryForMonthlyDetails = category
                            },
                            onChangeTarget: {
                                categoryForTargetEdit = category
                            },
                            onDelete: {
                                startDeleting(category)
                            }
                        )
                    }
                }

                if !deletedCategoryBuckets.isEmpty {
                    Section("קטגוריות שנמחקו") {
                        ForEach(deletedCategoryBuckets) { bucket in
                            DeletedCategoryBucketRow(
                                bucket: bucket,
                                onReassign: {
                                    startReassigning(bucket)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("נהל קטגוריות")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(item: $categoryBeingRenamed) { category in
            EditCategoryView(
                category: category,
                onSave: saveEditedCategory,
                onCancel: clearRenameState
            )
            .presentationDetents([.height(460)])
        }
        .sheet(item: $categoryForMonthlyDetails) { category in
            CategoryMonthlyDetailsView(
                category: category,
                expenses: currentMonthExpenses(for: category),
                recurringExpenses: recurringExpenses.filter { $0.categoryId == category.id },
                onSaveTarget: saveMonthlyTargetFromManagement,
                onClose: {
                    categoryForMonthlyDetails = nil
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $categoryForTargetEdit) { category in
            EditMonthlyTargetView(
                categoryName: category.name,
                monthlyTarget: category.monthlyTarget,
                onSave: { target in
                    saveMonthlyTargetFromManagement(category, target)
                    categoryForTargetEdit = nil
                },
                onCancel: {
                    categoryForTargetEdit = nil
                }
            )
            .presentationDetents([.height(240)])
        }
        .confirmationDialog(
            "לאן להעביר את ההוצאות?",
            isPresented: deleteDialogBinding,
            titleVisibility: .visible
        ) {
            if let pendingCategory = categoryPendingDelete {
                let transferTargets = categories.filter { $0.id != pendingCategory.id }

                ForEach(transferTargets) { category in
                    Button("העבר ל\(category.name)") {
                        deleteCategory(pendingCategory, transferTo: category)
                    }
                }

                Button("שייך יותר מאוחר") {
                    deleteCategoryLater(pendingCategory)
                }

                Button("ביטול", role: .cancel) {
                    categoryPendingDelete = nil
                }
            }
        } message: {
            if let categoryPendingDelete {
                Text("בקטגוריה \(categoryPendingDelete.name) יש \(monthlyTotal(categoryPendingDelete).formattedShekelAmount) החודש.")
            }
        }
        .confirmationDialog(
            "שייך מחדש",
            isPresented: reassignDialogBinding,
            titleVisibility: .visible
        ) {
            if let bucketPendingReassignment {
                if !categories.isEmpty {
                    ForEach(categories) { category in
                        Button("שייך ל\(category.name)") {
                            reassign(bucketPendingReassignment, to: category)
                        }
                    }
                }

                Button("צור קטגוריה חדשה") {
                    reassignMode = .new
                    reassignNewCategoryName = bucketPendingReassignment.originalCategoryName
                }

                Button("ביטול", role: .cancel) {
                    clearReassignState()
                }
            }
        } message: {
            if let bucketPendingReassignment {
                Text("\(bucketPendingReassignment.displayName) - \(bucketPendingReassignment.amount.formattedShekelAmount)")
            }
        }
        .alert("קטגוריה חדשה", isPresented: newReassignCategoryAlertBinding) {
            TextField("שם קטגוריה", text: $reassignNewCategoryName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)

            Button("ביטול", role: .cancel) {
                clearReassignState()
            }

            Button("שמור") {
                createCategoryAndReassign()
            }
            .disabled(reassignNewCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("בחר שם לקטגוריה שאליה נשייך את הסכום.")
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { categoryPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    categoryPendingDelete = nil
                }
            }
        )
    }

    private var reassignDialogBinding: Binding<Bool> {
        Binding(
            get: { bucketPendingReassignment != nil && reassignMode == .existing },
            set: { isPresented in
                if !isPresented, reassignMode == .existing {
                    clearReassignState()
                }
            }
        )
    }

    private var newReassignCategoryAlertBinding: Binding<Bool> {
        Binding(
            get: { bucketPendingReassignment != nil && reassignMode == .new },
            set: { isPresented in
                if !isPresented, reassignMode == .new {
                    clearReassignState()
                }
            }
        )
    }

    private func startRenaming(_ category: ExpenseCategory) {
        categoryBeingRenamed = category
    }

    private func clearRenameState() {
        categoryBeingRenamed = nil
    }

    private func startReassigning(_ bucket: DeletedCategoryBucket) {
        bucketPendingReassignment = bucket
        reassignMode = .existing
        reassignNewCategoryName = ""
    }

    private func clearReassignState() {
        bucketPendingReassignment = nil
        reassignMode = .existing
        reassignNewCategoryName = ""
    }

    private func reassign(_ bucket: DeletedCategoryBucket, to category: ExpenseCategory) {
        let expenseIds = Set(bucket.expenseIds)

        expenses = expenses.map { expense in
            expenseIds.contains(expense.id) ? expense.withCategory(category) : expense
        }
        deletedCategoryBuckets.removeAll { $0.id == bucket.id }
        onPersist()
        clearReassignState()
    }

    private func createCategoryAndReassign() {
        guard let bucket = bucketPendingReassignment else {
            clearReassignState()
            return
        }

        let trimmedName = reassignNewCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return
        }

        if let existingCategory = categories.first(where: { $0.name.normalizedForComparison == trimmedName.normalizedForComparison }) {
            reassign(bucket, to: existingCategory)
            return
        }

        let newCategory = ExpenseCategory(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            systemImageName: CategoryAppearanceOption.defaultSystemImageName,
            tintName: CategoryAppearanceOption.defaultTintName
        )
        categories.append(newCategory)
        currentCategoryIndex = categories.count - 1
        reassign(bucket, to: newCategory)
    }

    private func saveEditedCategory(
        category: ExpenseCategory,
        name: String,
        systemImageName: String,
        tintName: String,
        monthlyTarget: Decimal?
    ) -> String? {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            clearRenameState()
            return nil
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return "צריך שם קטגוריה"
        }

        let editedCategoryId = category.id
        let isDuplicate = categories.contains { existingCategory in
            existingCategory.id != editedCategoryId &&
            existingCategory.name.normalizedForComparison == trimmedName.normalizedForComparison
        }

        guard !isDuplicate else {
            return "קטגוריה זו כבר קיימת"
        }

        categories[index] = category.updated(
            name: trimmedName,
            systemImageName: systemImageName,
            tintName: tintName,
            monthlyTarget: monthlyTarget
        )
        onPersist()
        clearRenameState()
        return nil
    }

    private func saveMonthlyTargetFromManagement(_ category: ExpenseCategory, _ monthlyTarget: Decimal?) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }

        categories[index] = categories[index].updated(
            name: categories[index].name,
            systemImageName: categories[index].systemImageName,
            tintName: categories[index].tintName,
            monthlyTarget: monthlyTarget
        )
        onPersist()
    }

    private func startDeleting(_ category: ExpenseCategory) {
        if monthlyTotal(category) > 0 {
            categoryPendingDelete = category
        } else {
            removeCategory(category)
        }
    }

    private func deleteCategory(_ sourceCategory: ExpenseCategory, transferTo destinationCategory: ExpenseCategory) {
        let expenseIds = currentMonthExpenseIds(for: sourceCategory)

        expenses = expenses.map { expense in
            expenseIds.contains(expense.id) ? expense.withCategory(destinationCategory) : expense
        }

        removeCategory(sourceCategory)
        categoryPendingDelete = nil
    }

    private func deleteCategoryLater(_ category: ExpenseCategory) {
        let expenseIds = currentMonthExpenseIds(for: category)
        let amount = expenses
            .filter { expenseIds.contains($0.id) }
            .reduce(Decimal(0)) { total, expense in
                total + expense.amount
            }

        deletedCategoryBuckets.append(DeletedCategoryBucket(
            originalCategoryId: category.id,
            originalCategoryName: category.name,
            amount: amount,
            expenseIds: expenseIds,
            createdAt: Date()
        ))

        removeCategory(category)
        categoryPendingDelete = nil
    }

    private func removeCategory(_ category: ExpenseCategory) {
        categories.removeAll { $0.id == category.id }

        if currentCategoryIndex >= categories.count {
            currentCategoryIndex = max(categories.count - 1, 0)
        }

        onPersist()
    }

    private func currentMonthExpenseIds(for category: ExpenseCategory) -> [UUID] {
        currentMonthExpenses(for: category).map(\.id)
    }

    private func currentMonthExpenses(for category: ExpenseCategory) -> [Expense] {
        let calendar = Calendar.current

        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        ) else {
            return []
        }

        return expenses
            .filter { expense in
                expense.categoryId == category.id && expense.createdAt >= monthStart
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

private struct CategoryManagementRow: View {
    let category: ExpenseCategory
    let monthlyTotal: Decimal
    let onRename: () -> Void
    let onDetails: () -> Void
    let onChangeTarget: () -> Void
    let onDelete: () -> Void

    @State private var isActionsPresented = false

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(systemImageName: category.systemImageName, tint: category.tint, size: 22)
                .frame(width: 30)

            VStack(alignment: .trailing, spacing: 4) {
                Text(category.name)
                    .font(.headline)

                Text("החודש \(monthlyTotal.formattedShekelAmount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isActionsPresented = true
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("אפשרויות קטגוריה")
            .confirmationDialog("אפשרויות קטגוריה", isPresented: $isActionsPresented, titleVisibility: .visible) {
                Button("פירוט הוצאות") {
                    onDetails()
                }

                Button("שנה יעד") {
                    onChangeTarget()
                }

                Button("ביטול", role: .cancel) {}
            }

            Button {
                onRename()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("שנה שם")

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("מחק")
        }
        .padding(.vertical, 6)
    }
}

private struct DeletedCategoryBucketRow: View {
    let bucket: DeletedCategoryBucket
    let onReassign: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full")
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .trailing, spacing: 4) {
                Text(bucket.displayName)
                    .font(.headline)

                Text(bucket.amount.formattedShekelAmount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onReassign()
            } label: {
                Label("שייך", systemImage: "arrow.right.arrow.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("שייך מחדש")
        }
        .padding(.vertical, 6)
    }
}

private struct CategoryCard: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let monthlyTotal: Decimal

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 3) {
                Text("החודש")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(monthlyTotal.formattedShekelAmount)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.tint.opacity(isSelected ? 0.24 : 0.14))

                CategoryIconView(systemImageName: category.systemImageName, tint: category.tint, size: 78)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.tint : .clear, lineWidth: 4)
            }

            Text(category.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(.isButton)
    }
}

private extension Decimal {
    var formattedShekelAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₪"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "he_IL")

        return formatter.string(from: self as NSDecimalNumber) ?? "₪0"
    }

    var plainString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    var formattedPercentText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.locale = Locale(identifier: "he_IL")

        let value = formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
        return "\(value)%"
    }
}

private extension String {
    var normalizedForComparison: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var categoryEmoji: String? {
        guard hasPrefix("emoji:") else {
            return nil
        }

        return String(dropFirst("emoji:".count))
    }

    var categoryTint: Color {
        switch self {
        case "green":
            .green
        case "blue":
            .blue
        case "orange":
            .orange
        case "pink":
            .pink
        case "red":
            .red
        case "purple":
            .purple
        case "teal":
            .teal
        case "yellow":
            .yellow
        default:
            .gray
        }
    }
}

private extension Calendar {
    func monthStart(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }

    func daysLeftInMonth(from date: Date) -> Int {
        let now = Date()
        let referenceDate = isDate(now, equalTo: date, toGranularity: .month) ? now : date

        guard let monthInterval = dateInterval(of: .month, for: referenceDate) else {
            return 0
        }

        let startOfTomorrow = startOfDay(for: referenceDate).addingTimeInterval(24 * 60 * 60)
        let days = dateComponents([.day], from: startOfTomorrow, to: monthInterval.end).day ?? 0

        return max(days, 0)
    }
}

private extension Date {
    var shortDateText: String {
        formatted(.dateTime.day().month().year())
    }
}

private enum CategoryAppearanceOption {
    static let defaultSystemImageName = "square.grid.2x2.fill"
    static let defaultTintName = "purple"

    static let systemImages = [
        "square.grid.2x2.fill",
        "fork.knife",
        "car.fill",
        "house.fill",
        "bag.fill",
        "cross.case.fill",
        "creditcard.fill",
        "cart.fill"
    ]

    static let tintNames = [
        "purple",
        "green",
        "blue",
        "orange",
        "pink",
        "red",
        "teal",
        "yellow"
    ]
}

private enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            "לפי המכשיר"
        case .light:
            "מצב בהיר"
        case .dark:
            "מצב כהה"
        }
    }

    var menuTitle: String {
        switch self {
        case .system:
            "מערכת"
        case .light:
            "בהיר"
        case .dark:
            "כהה"
        }
    }

    var systemImageName: String {
        switch self {
        case .system:
            "iphone"
        case .light:
            "sun.max"
        case .dark:
            "moon"
        }
    }

    var toggledLightDark: AppTheme {
        self == .dark ? .light : .dark
    }

    var themeToggleSystemImageName: String {
        self == .dark ? "sun.max.fill" : "moon.fill"
    }

    var themeToggleAccessibilityLabel: String {
        self == .dark ? "עבור למצב בהיר" : "עבור למצב כהה"
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

private struct ExpenseCategory: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let systemImageName: String
    let tintName: String
    let monthlyTarget: Decimal?

    var tint: Color {
        tintName.categoryTint
    }

    init(
        id: String,
        name: String,
        systemImageName: String,
        tintName: String,
        monthlyTarget: Decimal? = nil
    ) {
        self.id = id
        self.name = name
        self.systemImageName = systemImageName
        self.tintName = tintName
        self.monthlyTarget = monthlyTarget
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case systemImageName
        case tintName
        case monthlyTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        systemImageName = try container.decode(String.self, forKey: .systemImageName)
        tintName = try container.decode(String.self, forKey: .tintName)
        monthlyTarget = try container.decodeIfPresent(Decimal.self, forKey: .monthlyTarget)
    }

    static let placeholderCategories: [ExpenseCategory] = [
        ExpenseCategory(id: "food", name: "אוכל", systemImageName: "fork.knife", tintName: "green"),
        ExpenseCategory(id: "transport", name: "נסיעות", systemImageName: "car.fill", tintName: "blue"),
        ExpenseCategory(id: "home", name: "בית", systemImageName: "house.fill", tintName: "orange"),
        ExpenseCategory(id: "shopping", name: "קניות", systemImageName: "bag.fill", tintName: "pink"),
        ExpenseCategory(id: "health", name: "בריאות", systemImageName: "cross.case.fill", tintName: "red")
    ]

    func renamed(to newName: String) -> ExpenseCategory {
        ExpenseCategory(
            id: id,
            name: newName,
            systemImageName: systemImageName,
            tintName: tintName,
            monthlyTarget: monthlyTarget
        )
    }

    func updated(name: String, systemImageName: String, tintName: String, monthlyTarget: Decimal?) -> ExpenseCategory {
        ExpenseCategory(
            id: id,
            name: name,
            systemImageName: systemImageName,
            tintName: tintName,
            monthlyTarget: monthlyTarget
        )
    }
}

private struct RecurringExpense: Identifiable, Codable {
    let id: UUID
    let name: String
    let amount: Decimal
    let categoryId: String
    let categoryName: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        categoryId: String,
        categoryName: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.createdAt = createdAt
    }

    func updated(name: String, amount: Decimal) -> RecurringExpense {
        RecurringExpense(
            id: id,
            name: name,
            amount: amount,
            categoryId: categoryId,
            categoryName: categoryName,
            createdAt: createdAt
        )
    }
}

private struct RecurringExpenseCategoryGroup: Identifiable {
    let categoryId: String
    let categoryName: String
    let systemImageName: String
    let tintName: String
    let expenses: [RecurringExpense]

    var id: String {
        categoryId
    }

    var totalAmount: Decimal {
        expenses.reduce(Decimal(0)) { total, expense in
            total + expense.amount
        }
    }
}

private struct ExpenseCategoryExpenseGroup: Identifiable {
    let categoryId: String
    let categoryName: String
    let expenses: [Expense]

    var id: String {
        categoryId
    }

    var total: Decimal {
        expenses.reduce(Decimal(0)) { total, expense in
            total + expense.amount
        }
    }
}

private struct DeletedCategoryBucket: Identifiable, Codable {
    let id: UUID
    let originalCategoryId: String
    let originalCategoryName: String
    let amount: Decimal
    let expenseIds: [UUID]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        originalCategoryId: String,
        originalCategoryName: String,
        amount: Decimal,
        expenseIds: [UUID],
        createdAt: Date
    ) {
        self.id = id
        self.originalCategoryId = originalCategoryId
        self.originalCategoryName = originalCategoryName
        self.amount = amount
        self.expenseIds = expenseIds
        self.createdAt = createdAt
    }

    var displayName: String {
        "שייך מחדש מ\(originalCategoryName)"
    }
}

private enum ExpenseSource: String, Codable {
    case regular
    case backfill
}

private struct Expense: Identifiable, Codable {
    let id: UUID
    let categoryId: String
    let categoryName: String
    let amount: Decimal
    let createdAt: Date
    let name: String?
    let source: ExpenseSource

    init(
        id: UUID = UUID(),
        categoryId: String,
        categoryName: String,
        amount: Decimal,
        createdAt: Date,
        name: String?,
        source: ExpenseSource = .regular
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.amount = amount
        self.createdAt = createdAt
        self.name = name
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId
        case categoryName
        case amount
        case createdAt
        case name
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        amount = try container.decode(Decimal.self, forKey: .amount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        source = try container.decodeIfPresent(ExpenseSource.self, forKey: .source) ?? .regular
    }

    func withName(_ name: String) -> Expense {
        Expense(
            id: id,
            categoryId: categoryId,
            categoryName: categoryName,
            amount: amount,
            createdAt: createdAt,
            name: name,
            source: source
        )
    }

    func withCategory(_ category: ExpenseCategory) -> Expense {
        Expense(
            id: id,
            categoryId: category.id,
            categoryName: category.name,
            amount: amount,
            createdAt: createdAt,
            name: name,
            source: source
        )
    }
}

private enum Storage {
    private static let expensesKey = "expenses"
    private static let recurringExpensesKey = "recurringExpenses"
    private static let categoriesKey = "categories"
    private static let deletedCategoryBucketsKey = "deletedCategoryBuckets"
    private static let appThemeKey = "appTheme"

    static func loadExpenses() -> [Expense] {
        guard let data = UserDefaults.standard.data(forKey: expensesKey) else {
            return []
        }

        return (try? JSONDecoder().decode([Expense].self, from: data)) ?? []
    }

    static func saveExpenses(_ expenses: [Expense]) {
        guard let data = try? JSONEncoder().encode(expenses) else {
            return
        }

        UserDefaults.standard.set(data, forKey: expensesKey)
    }

    static func loadRecurringExpenses() -> [RecurringExpense] {
        guard let data = UserDefaults.standard.data(forKey: recurringExpensesKey) else {
            return []
        }

        return (try? JSONDecoder().decode([RecurringExpense].self, from: data)) ?? []
    }

    static func saveRecurringExpenses(_ expenses: [RecurringExpense]) {
        guard let data = try? JSONEncoder().encode(expenses) else {
            return
        }

        UserDefaults.standard.set(data, forKey: recurringExpensesKey)
    }

    static func loadCategories(defaults: [ExpenseCategory]) -> [ExpenseCategory] {
        guard let data = UserDefaults.standard.data(forKey: categoriesKey),
              let categories = try? JSONDecoder().decode([ExpenseCategory].self, from: data),
              !categories.isEmpty else {
            return defaults
        }

        return categories
    }

    static func saveCategories(_ categories: [ExpenseCategory]) {
        guard let data = try? JSONEncoder().encode(categories) else {
            return
        }

        UserDefaults.standard.set(data, forKey: categoriesKey)
    }

    static func loadDeletedCategoryBuckets() -> [DeletedCategoryBucket] {
        guard let data = UserDefaults.standard.data(forKey: deletedCategoryBucketsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([DeletedCategoryBucket].self, from: data)) ?? []
    }

    static func saveDeletedCategoryBuckets(_ buckets: [DeletedCategoryBucket]) {
        guard let data = try? JSONEncoder().encode(buckets) else {
            return
        }

        UserDefaults.standard.set(data, forKey: deletedCategoryBucketsKey)
    }

    static func loadAppTheme() -> AppTheme {
        guard let rawValue = UserDefaults.standard.string(forKey: appThemeKey),
              let theme = AppTheme(rawValue: rawValue) else {
            return .system
        }

        return theme
    }

    static func saveAppTheme(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: appThemeKey)
    }
}

#Preview {
    ContentView()
}
