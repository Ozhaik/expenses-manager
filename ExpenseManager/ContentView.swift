import SwiftUI

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .he
}

private extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

private final class AppSettingsStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            Storage.saveAppLanguage(language)
        }
    }

    init(language: AppLanguage = Storage.loadAppLanguage()) {
        self.language = language
    }
}

private extension View {
    func localizedPresentationEnvironment(_ language: AppLanguage) -> some View {
        environment(\.appLanguage, language)
            .environment(\.layoutDirection, language.layoutDirection)
            .environment(\.locale, Locale(identifier: language.localeIdentifier))
    }

    func localizedTextInput(_ language: AppLanguage) -> some View {
        multilineTextAlignment(.center)
            .environment(\.layoutDirection, language.layoutDirection)
            .environment(\.locale, Locale(identifier: language.localeIdentifier))
    }

    func localizedFieldMessage(_ language: AppLanguage) -> some View {
        multilineTextAlignment(language.textAlignment)
            .frame(maxWidth: .infinity, alignment: language.frameAlignment)
    }
}

private func categoryTargetRatioText(_ status: CategoryMonthlyTargetStatus, language: AppLanguage) -> String {
    let usedPercentage = status.targetAmount > 0 ? status.spentAmount / status.targetAmount * 100 : 0
    return language.text(
        he: "נוצל \(status.spentAmount.formattedShekelAmount) מתוך \(status.targetAmount.formattedShekelAmount) (\(usedPercentage.formattedPercentText))",
        en: "Used \(status.spentAmount.formattedShekelAmount) of \(status.targetAmount.formattedShekelAmount) (\(usedPercentage.formattedPercentText))"
    )
}

private func categoryTargetStatusLineText(_ status: CategoryMonthlyTargetStatus, language: AppLanguage) -> String {
    if status.isOverBudget {
        let overBudgetPercentage = status.overBudgetPercentage ?? 0
        return language.text(
            he: "חרגת ב־\(status.overBudgetAmount.formattedShekelAmount) (\(overBudgetPercentage.formattedPercentText))",
            en: "Over by \(status.overBudgetAmount.formattedShekelAmount) (\(overBudgetPercentage.formattedPercentText))"
        )
    }

    let remainingPercentage = status.targetAmount > 0 ? status.remainingAmount / status.targetAmount * 100 : 0
    return language.text(
        he: "נשאר \(status.remainingAmount.formattedShekelAmount) לבזבז (\(remainingPercentage.formattedPercentText))",
        en: "\(status.remainingAmount.formattedShekelAmount) left to spend (\(remainingPercentage.formattedPercentText))"
    )
}

private func leftToRightNumberSegment(_ text: String, language: AppLanguage) -> String {
    language == .he ? "\u{2066}\(text)\u{2069}" : text
}

private func compactCurrencyAmountText(_ amount: Decimal, language: AppLanguage) -> String {
    let symbol = Storage.loadCurrency().symbol
    return language == .he ? "\(amount.plainString)\(symbol)" : "\(symbol)\(amount.plainString)"
}

private func compactAmountText(_ amount: Decimal) -> String {
    amount.plainString
}

private func compactTargetRatioText(spentAmount: Decimal, targetAmount: Decimal, language: AppLanguage) -> String {
    if language == .he {
        return "\(compactAmountText(spentAmount))/\(compactAmountText(targetAmount))"
    }

    return "\(compactCurrencyAmountText(spentAmount, language: language))/\(compactCurrencyAmountText(targetAmount, language: language))"
}

private func compactTargetPercentText(spentAmount: Decimal, targetAmount: Decimal) -> String {
    let usedPercentage = targetAmount > 0 ? spentAmount / targetAmount * 100 : 0
    return "(\(usedPercentage.formattedPercentText))"
}

private func categoryTargetMainProgressText(_ status: CategoryMonthlyTargetStatus, language: AppLanguage) -> String {
    let progressText = "\(compactTargetRatioText(spentAmount: status.spentAmount, targetAmount: status.targetAmount, language: language)) \(compactTargetPercentText(spentAmount: status.spentAmount, targetAmount: status.targetAmount))"
    return leftToRightNumberSegment(progressText, language: language)
}

private func categoryTargetMainSentenceText(_ status: CategoryMonthlyTargetStatus, categoryName: String, language: AppLanguage) -> String {
    let progressText = categoryTargetMainProgressText(status, language: language)
    return language.text(
        he: "הוצאת \(progressText) על \(categoryName)",
        en: "Spent \(progressText) on \(categoryName)"
    )
}

private func categoryNoTargetMainSentenceText(spentAmount: Decimal, categoryName: String, language: AppLanguage) -> String {
    let spentText = leftToRightNumberSegment(compactCurrencyAmountText(spentAmount, language: language), language: language)
    return language.text(
        he: "הוצאת \(spentText) על \(categoryName)",
        en: "Spent \(spentText) on \(categoryName)"
    )
}

private func categoryMonthlyTargetStatusText(_ status: CategoryMonthlyTargetStatus, language: AppLanguage) -> String {
    "\(categoryTargetRatioText(status, language: language))\n\(categoryTargetStatusLineText(status, language: language))"
}

private func isValidSetupUserName(_ name: String) -> Bool {
    let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalizedName.isEmpty else {
        return false
    }

    return !["qa", "user", "משתמש"].contains(normalizedName)
}

private struct FixedHebrewVisualText: View {
    let parts: [String]
    let accessibilityLabel: String
    let fontSize: CGFloat
    let minimumScaleFactor: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part)
                    .environment(\.layoutDirection, containsHebrew(part) ? .rightToLeft : .leftToRight)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .font(.system(size: fontSize, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(minimumScaleFactor)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func containsHebrew(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0590...0x05FF).contains(Int(scalar.value))
        }
    }
}


struct ContentView: View {
    @StateObject private var appSettings = AppSettingsStore()
    @State private var currentCategoryIndex = 0
    @State private var amountText = ""
    @State private var mainSelectedCurrency: CurrencyOption = Storage.loadTemporaryCurrency(primaryCurrency: Storage.loadCurrency())
    @State private var temporaryCurrencyStartDate: Date? = Storage.loadTemporaryCurrencyStartDate()
    @State private var temporaryCurrencyExpirationDate: Date? = Storage.loadTemporaryCurrencyExpirationDate()
    @State private var isTemporaryCurrencyForCurrentExpenseOnly = false
    @State private var isTemporaryCurrencySheetPresented = false
    @State private var expenses: [Expense] = []
    @State private var recurringExpenses: [RecurringExpense] = []
    @State private var salaryEntries: [SalaryEntry] = []
    @State private var categories = ExpenseCategory.placeholderCategories
    @State private var deletedCategoryBuckets: [DeletedCategoryBucket] = []
    @State private var appTheme: AppTheme = .system
    @State private var userName = ""
    @State private var currency: CurrencyOption = .ils
    @State private var dateDisplayFormat: DateDisplayFormat = .dayMonthYear
    @State private var salaryReceiptDay = 1
    @State private var checkingBalance: Decimal?
    @State private var isUserNamePromptPresented = false
    @State private var isSalaryPromptPresented = false
    @State private var didSkipSalaryPromptThisSession = false
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
    @State private var isAddExpensePresented = false
    @State private var mainAddExpenseIsRecurring = false
    @State private var isMainAddSelectorPresented = false
    @State private var mainSelectedAddAction: FinancialAddAction?
    @State private var isMainAddTypeSelectorPresented = false
    @State private var isMainAddSavingPresented = false
    @State private var isMainRecurringSavingPresented = false
    @State private var isMainAddDebtDirectionPresented = false
    @State private var isMainAddDebtPresented = false
    @State private var mainAddDebtDirection: DebtDirection = .owedToMe
    @State private var mainAlertMessage: String?
    @State private var isBackfillExpensePresented = false
    @State private var isManageRecurringExpensesPresented = false
    @State private var isPastExpensesPresented = false
    @State private var isSalaryHistoryPresented = false
    @State private var isAnalyticsPresented = false
    @State private var categoryForMonthlyDetails: ExpenseCategory?
    @State private var isSavingsManagementPresented = false
    @State private var isDebtsManagementPresented = false
    @State private var categoryTransitionDirection: CGFloat = -1
    @State private var isNavigatingCategory = false
    @State private var categoryNavigationLockID = 0
    @State private var rootRefreshID = UUID()
    @State private var isLanguageRefreshOverlayPresented = false
    @State private var isInitialSetupPresented = false

    private let dragThreshold: CGFloat = 55
    private let categoryNavigationLockDuration: TimeInterval = 0.34

    private var appLanguage: AppLanguage {
        appSettings.language
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { appSettings.language },
            set: { appSettings.language = $0 }
        )
    }

    private var currencyBinding: Binding<CurrencyOption> {
        Binding(
            get: { currency },
            set: { newValue in
                let previousPrimaryCurrency = currency
                currency = newValue
                Storage.saveCurrency(newValue)
                CurrencyExchangeService.markRatesStale()

                if mainSelectedCurrency == previousPrimaryCurrency {
                    mainSelectedCurrency = newValue
                    temporaryCurrencyExpirationDate = nil
                    Storage.clearTemporaryCurrency()
                } else {
                    validateTemporaryCurrencySelection(primaryCurrency: newValue)
                }

                refreshCurrencyUI()
            }
        )
    }

    private var dateDisplayFormatBinding: Binding<DateDisplayFormat> {
        Binding(
            get: { dateDisplayFormat },
            set: { newValue in
                dateDisplayFormat = newValue
                Storage.saveDateDisplayFormat(newValue)
                refreshDateFormatUI()
            }
        )
    }

    private var currencyConversionUnavailableMessage: String {
        appLanguage.text(
            he: "לא ניתן להמיר מטבע כרגע. נסה שוב אחרי עדכון שערים.",
            en: "Currency conversion is unavailable. Try again after rates update."
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            mainContent

            menuButton
                .padding(.top, 14)
                .padding(.leading, 16)

            addExpenseButton
                .padding(.top, 16)
                .padding(.trailing, 18)

            if isSideMenuOpen {
                sideMenuOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }

            if isAddExpensePresented {
                addExpenseOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isMainAddSavingPresented {
                centeredModalOverlay {
                    AddSavingView(
                        kind: .deposit,
                        availableBalance: Saving.balance(for: Storage.loadSavings()),
                        goals: Storage.loadSavingGoals(),
                        onSave: saveMainSaving,
                        onCancel: {
                            isMainAddSavingPresented = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isMainRecurringSavingPresented {
                centeredModalOverlay {
                    RecurringSavingEditorView(
                        goals: Storage.loadSavingGoals(),
                        onSave: saveMainRecurringSaving,
                        onCancel: {
                            isMainRecurringSavingPresented = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isMainAddDebtDirectionPresented {
                centeredModalOverlay(maxWidth: 340) {
                    DebtDirectionChooserView(
                        onSelect: { direction in
                            mainAddDebtDirection = direction
                            isMainAddDebtDirectionPresented = false
                            isMainAddDebtPresented = true
                        },
                        onCancel: {
                            isMainAddDebtDirectionPresented = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isMainAddDebtPresented {
                centeredModalOverlay {
                    AddDebtView(
                        direction: mainAddDebtDirection,
                        onSave: saveMainDebt,
                        onCancel: {
                            isMainAddDebtPresented = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isLanguageRefreshOverlayPresented {
                languageRefreshOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .background(Color(.systemGroupedBackground))
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.appLanguage, appLanguage)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .preferredColorScheme(appTheme.colorScheme)
        .id(rootRefreshID)
        .onAppear {
            loadStoredData()
            if !isInitialSetupPresented {
                presentSalaryPromptIfNeeded()
            }
        }
        .onChange(of: appSettings.language) { _, _ in
            refreshLanguageUI()
        }
        .fullScreenCover(isPresented: $isInitialSetupPresented) {
            FirstLaunchSetupView(
                initialLanguage: appLanguage,
                onComplete: completeInitialSetup
            )
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isUserNamePromptPresented) {
            UserNamePromptView(
                initialName: userName,
                title: appLanguage.text(he: "איך קוראים לך?", en: "What is your name?"),
                saveTitle: appLanguage.text(he: "שמור", en: "Save"),
                onSave: { name in
                    userName = name
                    Storage.saveUserName(name)
                    isUserNamePromptPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .interactiveDismissDisabled()
            .presentationDetents([.height(240)])
        }
        .sheet(isPresented: $isTemporaryCurrencySheetPresented) {
            TemporaryCurrencySheet(
                selectedCurrency: mainSelectedCurrency,
                primaryCurrency: currency,
                onSelectCurrentExpense: selectTemporaryCurrencyForCurrentExpense,
                onSelectDateRange: selectTemporaryCurrencyRange,
                onClose: {
                    isTemporaryCurrencySheetPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.fraction(0.72), .large])
        }
        .sheet(isPresented: $isNamingSheetPresented) {
            ExpenseNameView(
                expenseName: $expenseName,
                onSave: savePendingExpenseWithName,
                onSkip: savePendingExpenseWithoutName
            )
            .localizedPresentationEnvironment(appLanguage)
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
            .localizedPresentationEnvironment(appLanguage)
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
            .localizedPresentationEnvironment(appLanguage)
        }
        .sheet(item: $categoryForMonthlyDetails) { category in
            CategoryMonthlyDetailsView(
                category: category,
                expenses: $expenses,
                recurringExpenses: recurringExpenses.filter { $0.categoryId == category.id },
                onClose: {
                    categoryForMonthlyDetails = nil
                },
                onPersist: {
                    Storage.saveExpenses(expenses)
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            SettingsView(
                userName: userName,
                currency: currencyBinding,
                appLanguage: appLanguageBinding,
                dateDisplayFormat: dateDisplayFormatBinding,
                salaryReceiptDay: $salaryReceiptDay,
                checkingBalance: $checkingBalance,
                onSaveUserName: { name in
                    userName = name
                    Storage.saveUserName(name)
                },
                onPersistSettings: persistAppSettings,
                onResetApp: resetAppWithSnapshot,
                onRestoreSnapshot: restoreSnapshot,
                onCreateTestData: createDebugTestData,
                onClearTestData: clearDebugTestData,
                onClose: {
                    isSettingsPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
        }
        .fullScreenCover(isPresented: $isBackfillExpensePresented) {
            BackfillExpenseView(
                categories: categories,
                onSave: saveBackfillExpenses,
                onClose: {
                    isBackfillExpensePresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
        }
        .fullScreenCover(isPresented: $isPastExpensesPresented) {
            PastDataView(
                categories: categories,
                expenses: $expenses,
                salaryEntries: $salaryEntries,
                onClose: {
                    isPastExpensesPresented = false
                },
                onPersist: {
                    Storage.saveExpenses(expenses)
                    Storage.saveSalaryEntries(salaryEntries)
                }
            )
            .localizedPresentationEnvironment(appLanguage)
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
            .localizedPresentationEnvironment(appLanguage)
        }
        .fullScreenCover(isPresented: $isSalaryHistoryPresented) {
            SalaryHistoryView(
                salaryEntries: $salaryEntries,
                expenses: expenses,
                savings: Storage.loadSavings(),
                appLanguage: appLanguage,
                onClose: {
                    isSalaryHistoryPresented = false
                },
                onPersist: {
                    Storage.saveSalaryEntries(salaryEntries)
                }
            )
            .localizedPresentationEnvironment(appLanguage)
        }
        .fullScreenCover(isPresented: $isAnalyticsPresented) {
            AnalyticsView(
                categories: categories,
                expenses: expenses,
                salaryEntries: salaryEntries,
                savings: Storage.loadSavings(),
                debts: Storage.loadDebts(),
                onClose: {
                    isAnalyticsPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
        }
        .fullScreenCover(isPresented: $isSavingsManagementPresented) {
            SavingsManagementView(
                userName: userName,
                onClose: {
                    isSavingsManagementPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
        }
        .sheet(isPresented: $isSalaryPromptPresented) {
            SalaryPromptView(
                currencySymbol: currency.symbol,
                onSave: saveCurrentMonthSalary,
                onSkip: {
                    didSkipSalaryPromptThisSession = true
                    isSalaryPromptPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .interactiveDismissDisabled()
            .presentationDetents([.height(260)])
        }
        .alert(appLanguage.text(he: "עדיין לא זמין", en: "Not available yet"), isPresented: mainAlertBinding) {
            Button(appLanguage.text(he: "אישור", en: "OK"), role: .cancel) {
                mainAlertMessage = nil
            }
        } message: {
            Text(mainAlertMessage ?? "")
        }
        .fullScreenCover(isPresented: $isDebtsManagementPresented) {
            DebtsManagementView(
                onClose: {
                    isDebtsManagementPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
        }
        .task {
            await CurrencyExchangeService.refreshIfNeeded()
            validateTemporaryCurrencySelection(primaryCurrency: currency)
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            validateTemporaryCurrencySelection(primaryCurrency: currency)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 24)

            VStack(spacing: 4) {
                Text(welcomeText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                monthlyExpenseSummaryView
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 58)
            .padding(.bottom, 24)

            HStack(spacing: 8) {
                categoryNavigationButton(
                    systemName: leadingCategoryNavigationSystemName,
                    accessibilityLabel: leadingCategoryNavigationLabel
                ) {
                    leadingCategoryNavigationAction()
                }

                ZStack {
                    if let selectedCategory {
                        CategoryCard(
                            category: selectedCategory,
                            isSelected: true,
                            positionText: categoryPositionText,
                            monthlyTotal: monthlyTotal(for: selectedCategory),
                            monthlyTargetStatus: selectedCategoryTargetStatus,
                            onAddTarget: {
                                categoryForMonthlyDetails = selectedCategory
                            }
                        )
                        .id(selectedCategory.id)
                        .transition(categoryTransition)
                        .onTapGesture {
                            guard !isNavigatingCategory else {
                                return
                            }

                            categoryForMonthlyDetails = selectedCategory
                        }
                        .allowsHitTesting(!isNavigatingCategory)
                        .simultaneousGesture(categoryDragGesture)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 296)
                .clipped()

                categoryNavigationButton(
                    systemName: trailingCategoryNavigationSystemName,
                    accessibilityLabel: trailingCategoryNavigationLabel
                ) {
                    trailingCategoryNavigationAction()
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            CategoryPageDots(count: categories.count, currentIndex: currentCategoryIndex)
                .padding(.top, 12)

            if let selectedCategory {
                Text(selectedCategory.displayName(for: appLanguage))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 16)
            }

            Button {
                openCategorySheet()
            } label: {
                Label(appLanguage.text(he: "הוסף קטגוריה", en: "Add Category"), systemImage: "plus.circle")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            VStack(spacing: 14) {
                if selectedCategory != nil {
                    AmountInputField(
                        amountText: $amountText,
                        selectedCurrency: $mainSelectedCurrency,
                        onCurrencyButtonTapped: {
                            isTemporaryCurrencySheetPresented = true
                        }
                    )
                        .frame(width: 250)
                }
            }
            .padding(.top, 2)
            .frame(height: 54)

            Spacer(minLength: 20)

            Button {
                prepareExpenseNameStep()
            } label: {
                Text(appLanguage.text(he: "הוסף", en: "Add"))
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
        .accessibilityLabel(appLanguage.text(he: "תפריט", en: "Menu"))
    }

    private var addExpenseButton: some View {
        HStack {
            Spacer()

            Button {
                isMainAddSelectorPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(.thinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLanguage.text(he: "הוסף נתון", en: "Add Record"))
            .popover(isPresented: $isMainAddSelectorPresented, attachmentAnchor: .point(.bottom), arrowEdge: appLanguage == .he ? .top : .top) {
                AddActionBubbleView(
                    title: appLanguage.text(he: "מה תרצה להוסיף?", en: "What would you like to add?"),
                    actions: FinancialAddAction.allCases,
                    appLanguage: appLanguage,
                    onSelect: { action in
                        mainSelectedAddAction = action
                        isMainAddSelectorPresented = false
                        isMainAddTypeSelectorPresented = true
                    }
                )
                .presentationCompactAdaptation(.popover)
            }
            .popover(isPresented: $isMainAddTypeSelectorPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                AddOccurrenceBubbleView(
                    title: mainSelectedAddAction?.typePrompt(for: appLanguage)
                        ?? appLanguage.text(he: "סוג פעולה", en: "Action Type"),
                    appLanguage: appLanguage,
                    onSelect: handleMainAddTypeSelection
                )
                .presentationCompactAdaptation(.popover)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var sideMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture {
                    closeSideMenu()
                }

            HStack(spacing: 0) {
                if appLanguage != .he {
                    sideMenuPanel
                }

                Spacer(minLength: 0)

                if appLanguage == .he {
                    sideMenuPanel
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .ignoresSafeArea()
    }

    private var sideMenuPanel: some View {
        SideMenuView(
            appTheme: $appTheme,
            appLanguage: appLanguage,
            onThemeChanged: { theme in
                Storage.saveAppTheme(theme)
            },
            onSelect: handleMenuSelection
        )
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
        .shadow(color: .black.opacity(0.18), radius: 18, x: appLanguage == .he ? -8 : 8, y: 0)
        .transition(.move(edge: sideMenuEdge).combined(with: .opacity))
    }

    private var addExpenseOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture {
                    isAddExpensePresented = false
                }

            AddExpenseModalView(
                categories: categories,
                initialIsRecurring: mainAddExpenseIsRecurring,
                onSave: saveAddedExpense,
                onCancel: {
                    isAddExpensePresented = false
                }
            )
            .frame(maxWidth: 392)
            .padding(.horizontal, 16)
        }
    }

    private func centeredModalOverlay<Content: View>(
        maxWidth: CGFloat = 392,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            content()
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
        }
        .zIndex(9)
    }

    private var languageRefreshOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            Text(appLanguage.loadingText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
        }
        .ignoresSafeArea()
    }

    private var selectedCategory: ExpenseCategory? {
        guard categories.indices.contains(currentCategoryIndex) else {
            return nil
        }

        return categories[currentCategoryIndex]
    }

    private var mainAlertBinding: Binding<Bool> {
        Binding(
            get: { mainAlertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    mainAlertMessage = nil
                }
            }
        )
    }

    private var sideMenuEdge: Edge {
        appLanguage == .he ? .trailing : .leading
    }

    private var leadingCategoryNavigationSystemName: String {
        appLanguage == .he ? "chevron.right" : "chevron.left"
    }

    private var trailingCategoryNavigationSystemName: String {
        appLanguage == .he ? "chevron.left" : "chevron.right"
    }

    private var leadingCategoryNavigationLabel: String {
        appLanguage == .he
            ? appLanguage.text(he: "הקטגוריה הקודמת", en: "Previous category")
            : appLanguage.text(he: "הקטגוריה הקודמת", en: "Previous category")
    }

    private var trailingCategoryNavigationLabel: String {
        appLanguage == .he
            ? appLanguage.text(he: "הקטגוריה הבאה", en: "Next category")
            : appLanguage.text(he: "הקטגוריה הבאה", en: "Next category")
    }

    private func leadingCategoryNavigationAction() {
        if appLanguage == .he {
            selectNextCategory()
        } else {
            selectPreviousCategory()
        }
    }

    private func trailingCategoryNavigationAction() {
        if appLanguage == .he {
            selectPreviousCategory()
        } else {
            selectNextCategory()
        }
    }

    private var categoryTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: categoryTransitionDirection < 0 ? .trailing : .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.94)),
            removal: .move(edge: categoryTransitionDirection < 0 ? .leading : .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.94))
        )
    }

    private var categoryPositionText: String {
        guard !categories.isEmpty else {
            return appLanguage.text(he: "אין קטגוריות עדיין", en: "No categories yet")
        }

        return "\(currentCategoryIndex + 1)/\(categories.count)"
    }

    private var welcomeText: String {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return appLanguage.text(he: "ברוך הבא", en: "Welcome")
        }

        return appLanguage.text(
            he: "ברוך הבא, \(trimmedName)",
            en: "Welcome, \(trimmedName)"
        )
    }

    private var currentMonthExpenseTotal: Decimal {
        ExpenseCalculations.monthlyNetExpenseTotal(for: expenseCalculationEntries, month: Date())
    }

    private var expenseCalculationEntries: [ExpenseCalculations.DatedNetAmount] {
        expenses.map { expense in
            ExpenseCalculations.DatedNetAmount(
                categoryId: expense.categoryId,
                date: expense.date,
                netAmount: expense.netAmount
            )
        }
    }

    private var monthlyTargetProgress: ExpenseCalculations.MonthlyTargetProgress? {
        let targets = Dictionary(uniqueKeysWithValues: categories.compactMap { category -> (String, Decimal)? in
            guard let monthlyTarget = category.monthlyTarget, monthlyTarget > 0 else {
                return nil
            }

            return (category.id, monthlyTarget)
        })

        return ExpenseCalculations.monthlyTargetProgress(
            for: expenseCalculationEntries,
            categoryTargets: targets,
            month: Date()
        )
    }

    @ViewBuilder
    private var monthlyExpenseSummaryView: some View {
        if expenses.isEmpty && currentMonthExpenseTotal == 0 {
            Text(appLanguage.text(he: "אין הוצאות עדיין", en: "No expenses yet"))
        } else if let monthlyTargetProgress {
            let ratioText = compactTargetRatioText(
                spentAmount: monthlyTargetProgress.spentAmount,
                targetAmount: monthlyTargetProgress.targetAmount,
                language: appLanguage
            )
            let percentText = compactTargetPercentText(
                spentAmount: monthlyTargetProgress.spentAmount,
                targetAmount: monthlyTargetProgress.targetAmount
            )

            if appLanguage == .he {
                FixedHebrewVisualText(
                    parts: ["הוצאת החודש", ratioText, percentText],
                    accessibilityLabel: "הוצאת החודש \(ratioText) \(percentText)",
                    fontSize: 15,
                    minimumScaleFactor: 0.78
                )
                .frame(height: 18)
                .fixedSize(horizontal: true, vertical: false)
            } else {
                Text("Spent this month \(ratioText) \(percentText)")
            }
        } else {
            let spentText = appLanguage == .he
                ? compactAmountText(currentMonthExpenseTotal)
                : compactCurrencyAmountText(currentMonthExpenseTotal, language: appLanguage)

            if appLanguage == .he {
                FixedHebrewVisualText(
                    parts: ["הוצאת החודש", spentText],
                    accessibilityLabel: "הוצאת החודש \(spentText)",
                    fontSize: 15,
                    minimumScaleFactor: 0.78
                )
                .frame(height: 18)
                .fixedSize(horizontal: true, vertical: false)
            } else {
                Text("Spent this month \(spentText)")
            }
        }
    }

    private var selectedCategoryTargetStatus: CategoryMonthlyTargetStatus? {
        guard let selectedCategory else {
            return nil
        }

        return categoryMonthlyTargetStatus(category: selectedCategory, expenses: expenses, month: Date())
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

        guard let conversion = CurrencyExchangeService.convert(amount: amount, from: mainSelectedCurrency, to: currency) else {
            mainAlertMessage = currencyConversionUnavailableMessage
            return
        }

        pendingExpense = Expense(
            categoryId: selectedCategory.id,
            categoryName: selectedCategory.name,
            amount: conversion.convertedAmount,
            createdAt: Date(),
            name: nil,
            originalAmount: amount,
            originalCurrencyCode: mainSelectedCurrency.code,
            exchangeRate: conversion.exchangeRate,
            exchangeRateDate: conversion.exchangeRateDate,
            convertedAmount: conversion.convertedAmount,
            convertedCurrencyCode: currency.code
        )
        expenseName = ""
        isNamingSheetPresented = true
    }

    private func selectTemporaryCurrencyForCurrentExpense(_ selectedCurrency: CurrencyOption) {
        mainSelectedCurrency = selectedCurrency
        temporaryCurrencyStartDate = nil
        temporaryCurrencyExpirationDate = nil
        isTemporaryCurrencyForCurrentExpenseOnly = true
        Storage.clearTemporaryCurrency()

        isTemporaryCurrencySheetPresented = false
    }

    private func selectTemporaryCurrencyRange(_ selectedCurrency: CurrencyOption, startDate: Date, endDate: Date) {
        let normalizedStartDate = Calendar.current.startOfDay(for: startDate)
        let normalizedEndDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        temporaryCurrencyStartDate = normalizedStartDate
        temporaryCurrencyExpirationDate = normalizedEndDate
        isTemporaryCurrencyForCurrentExpenseOnly = false
        Storage.saveTemporaryCurrency(selectedCurrency, startDate: normalizedStartDate, expirationDate: normalizedEndDate)
        validateTemporaryCurrencySelection(primaryCurrency: currency)

        isTemporaryCurrencySheetPresented = false
    }

    private func validateTemporaryCurrencySelection(primaryCurrency: CurrencyOption) {
        if isTemporaryCurrencyForCurrentExpenseOnly {
            return
        }

        guard let storedCurrency = Storage.loadStoredTemporaryCurrency() else {
            mainSelectedCurrency = primaryCurrency
            return
        }

        if let startDate = temporaryCurrencyStartDate, startDate > Date() {
            mainSelectedCurrency = primaryCurrency
            return
        }

        guard let expirationDate = temporaryCurrencyExpirationDate else {
            mainSelectedCurrency = storedCurrency
            return
        }

        if expirationDate <= Date() {
            mainSelectedCurrency = primaryCurrency
            temporaryCurrencyStartDate = nil
            temporaryCurrencyExpirationDate = nil
            Storage.clearTemporaryCurrency()
        } else {
            mainSelectedCurrency = storedCurrency
        }
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

        if isTemporaryCurrencyForCurrentExpenseOnly {
            mainSelectedCurrency = currency
            isTemporaryCurrencyForCurrentExpenseOnly = false
        }
    }

    private func selectNextCategory() {
        guard !categories.isEmpty else {
            return
        }

        beginCategoryNavigationLock()
        categoryTransitionDirection = -1
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            currentCategoryIndex = (currentCategoryIndex + 1) % categories.count
            amountText = ""
        }
    }

    private func selectPreviousCategory() {
        guard !categories.isEmpty else {
            return
        }

        beginCategoryNavigationLock()
        categoryTransitionDirection = 1
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            currentCategoryIndex = (currentCategoryIndex + categories.count - 1) % categories.count
            amountText = ""
        }
    }

    private func beginCategoryNavigationLock() {
        categoryNavigationLockID += 1
        let lockID = categoryNavigationLockID
        isNavigatingCategory = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(categoryNavigationLockDuration * 1_000_000_000))

            if categoryNavigationLockID == lockID {
                isNavigatingCategory = false
            }
        }
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

    private func categoryNavigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .frame(width: 42, height: 76)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }

    private func monthlyTotal(for category: ExpenseCategory) -> Decimal {
        netExpenseTotal(for: monthlyExpenses(for: category))
    }

    private func monthlyExpenses(for category: ExpenseCategory) -> [Expense] {
        let calendar = Calendar.current
        let now = Date()

        return expenses
            .filter { expense in
                expense.categoryId == category.id
                    && calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
            }
            .sorted { $0.date > $1.date }
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
            categoryNameError = appLanguage.text(he: "קטגוריה זו כבר קיימת", en: "This category already exists")
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

    private func saveAddedExpense(
        name: String,
        amount: Decimal,
        isRecurring: Bool,
        date: Date,
        categoryId: String?
    ) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard amount > 0 else {
            return appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
        }

        guard let categoryId,
              let category = categories.first(where: { $0.id == categoryId }) else {
            return appLanguage.text(he: "צריך לבחור קטגוריה", en: "Choose a category")
        }

        expenses.append(Expense(
            categoryId: category.id,
            categoryName: category.name,
            amount: amount,
            createdAt: Date(),
            date: date,
            name: trimmedName.isEmpty ? nil : trimmedName,
            isRecurring: isRecurring
        ))
        Storage.saveExpenses(expenses)

        if isRecurring {
            recurringExpenses.append(RecurringExpense(
                name: trimmedName.isEmpty ? category.name : trimmedName,
                amount: amount,
                categoryId: category.id,
                categoryName: category.name,
                createdAt: date
            ))
            Storage.saveRecurringExpenses(recurringExpenses)
        }

        isAddExpensePresented = false

        return nil
    }

    private func saveMainSaving(_ saving: Saving) {
        var storedSavings = Storage.loadSavings()
        storedSavings.append(saving)
        storedSavings.sort { $0.date > $1.date }
        Storage.saveSavings(storedSavings)
        isMainAddSavingPresented = false
    }

    private func saveMainRecurringSaving(_ recurringSaving: RecurringSaving) {
        var storedRecurringSavings = Storage.loadRecurringSavings()
        storedRecurringSavings.append(recurringSaving)
        storedRecurringSavings.sort { $0.startDate > $1.startDate }
        Storage.saveRecurringSavings(storedRecurringSavings)
        isMainRecurringSavingPresented = false
    }

    private func saveMainDebt(_ debt: Debt) {
        var storedDebts = Storage.loadDebts()
        storedDebts.append(debt)
        storedDebts.sort { $0.date > $1.date }
        Storage.saveDebts(storedDebts)
        isMainAddDebtPresented = false
    }

    private func handleMainAddTypeSelection(_ type: AddOccurrenceType) {
        isMainAddTypeSelectorPresented = false

        guard let mainSelectedAddAction else {
            return
        }

        switch (mainSelectedAddAction, type) {
        case (.expense, .oneTime):
            mainAddExpenseIsRecurring = false
            presentAfterBubbleDismiss {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAddExpensePresented = true
                }
            }
        case (.expense, .recurring):
            mainAddExpenseIsRecurring = true
            presentAfterBubbleDismiss {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAddExpensePresented = true
                }
            }
        case (.saving, .oneTime):
            presentAfterBubbleDismiss {
                isMainAddSavingPresented = true
            }
        case (.saving, .recurring):
            presentAfterBubbleDismiss {
                isMainRecurringSavingPresented = true
            }
        case (.debt, .oneTime):
            presentAfterBubbleDismiss {
                isMainAddDebtDirectionPresented = true
            }
        case (.debt, .recurring):
            presentAfterBubbleDismiss {
                mainAlertMessage = appLanguage.text(
                    he: "עדיין לא זמין. אפשר להוסיף חוב חד פעמי כרגע.",
                    en: "Recurring debt is not available yet. You can add a one-time debt for now."
                )
            }
        }
    }

    private func presentAfterBubbleDismiss(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            action()
        }
    }

    private func saveBackfillExpenses(
        mode: BackfillExpenseMode,
        amount: Decimal,
        selectedCurrency: CurrencyOption,
        month: Date,
        monthCount: Int,
        existingCategoryId: String?,
        newCategoryName: String?,
        expenseName: String
    ) -> String? {
        let trimmedExpenseName = expenseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard amount > 0 else {
            return appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
        }

        guard let category = resolveCategory(existingCategoryId: existingCategoryId, newCategoryName: newCategoryName) else {
            return appLanguage.text(he: "צריך לבחור או ליצור קטגוריה", en: "Choose or create a category")
        }

        let calendar = Calendar.current
        let safeMonthCount = max(monthCount, 1)
        let cleanExpenseName = trimmedExpenseName.isEmpty ? nil : trimmedExpenseName
        let expenseDates: [Date]

        switch mode {
        case .oneTime:
            expenseDates = [month]
        case .recurring:
            expenseDates = (0..<safeMonthCount).compactMap { offset in
                calendar.date(byAdding: .month, value: -offset, to: month)
            }
        }

        if expenseDates.contains(where: {
            ExpenseCalculations.requiresHistoricalExchangeRate(
                expenseDate: $0,
                sourceCurrencyCode: selectedCurrency.code,
                primaryCurrencyCode: currency.code
            )
        }) {
            return appLanguage.text(
                he: "לא ניתן להוסיף הוצאה בדיעבד במטבע זר בלי שער היסטורי לתאריך ההוצאה",
                en: "Past foreign-currency expenses require a historical exchange rate for the expense date"
            )
        }

        guard let conversion = CurrencyExchangeService.convert(amount: amount, from: selectedCurrency, to: currency) else {
            return currencyConversionUnavailableMessage
        }

        switch mode {
        case .oneTime:
            let exchangeRateDate = selectedCurrency == currency ? month : conversion.exchangeRateDate
            expenses.append(Expense(
                categoryId: category.id,
                categoryName: category.name,
                amount: conversion.convertedAmount,
                createdAt: Date(),
                date: month,
                name: cleanExpenseName,
                source: .backfill,
                originalAmount: amount,
                originalCurrencyCode: selectedCurrency.code,
                exchangeRate: conversion.exchangeRate,
                exchangeRateDate: exchangeRateDate,
                convertedAmount: conversion.convertedAmount,
                convertedCurrencyCode: currency.code
            ))
        case .recurring:
            for expenseDate in expenseDates {
                let exchangeRateDate = selectedCurrency == currency ? expenseDate : conversion.exchangeRateDate
                expenses.append(Expense(
                    categoryId: category.id,
                    categoryName: category.name,
                    amount: conversion.convertedAmount,
                    createdAt: Date(),
                    date: expenseDate,
                    name: cleanExpenseName,
                    source: .backfill,
                    originalAmount: amount,
                    originalCurrencyCode: selectedCurrency.code,
                    exchangeRate: conversion.exchangeRate,
                    exchangeRateDate: exchangeRateDate,
                    convertedAmount: conversion.convertedAmount,
                    convertedCurrencyCode: currency.code
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

    private func handleMenuSelection(_ option: MenuOption) {
        selectedMenuOption = option
        closeSideMenu()

        if option == .manageCategories {
            isManageCategoriesPresented = true
        } else if option == .settings {
            isSettingsPresented = true
        } else if option == .manageRecurringExpenses {
            isManageRecurringExpensesPresented = true
        } else if option == .manageSavings {
            isSavingsManagementPresented = true
        } else if option == .manageDebts {
            isDebtsManagementPresented = true
        } else if option == .pastExpenses {
            isPastExpensesPresented = true
        } else if option == .salaryHistory {
            isSalaryHistoryPresented = true
        } else if option == .analytics {
            isAnalyticsPresented = true
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

    private func persistAppSettings() {
        Storage.saveCurrency(currency)
        Storage.saveAppLanguage(appLanguage)
        Storage.saveDateDisplayFormat(dateDisplayFormat)
        Storage.saveSalaryReceiptDay(salaryReceiptDay)
        Storage.saveCheckingBalance(checkingBalance)
    }

    private func refreshLanguageUI() {
        Storage.saveAppLanguage(appLanguage)
        withAnimation(.easeInOut(duration: 0.16)) {
            isLanguageRefreshOverlayPresented = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            rootRefreshID = UUID()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeInOut(duration: 0.18)) {
                isLanguageRefreshOverlayPresented = false
            }
        }
    }

    private func refreshCurrencyUI() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            rootRefreshID = UUID()
        }
    }

    private func refreshDateFormatUI() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            rootRefreshID = UUID()
        }
    }

    private func resetAppWithSnapshot() {
        Storage.appendRestoreSnapshot(RestoreSnapshot(
            createdAt: Date(),
            expenses: expenses,
            recurringExpenses: recurringExpenses,
            savings: Storage.loadSavings(),
            savingGoals: Storage.loadSavingGoals(),
            recurringSavings: Storage.loadRecurringSavings(),
            debts: Storage.loadDebts(),
            salaryEntries: salaryEntries,
            categories: categories,
            deletedCategoryBuckets: deletedCategoryBuckets,
            userName: userName,
            currency: currency,
            appLanguage: appLanguage,
            salaryReceiptDay: salaryReceiptDay,
            checkingBalance: checkingBalance,
            savingsGoal: Storage.loadSavingsGoal()
        ))

        Storage.resetAllAppData()

        amountText = ""
        expenses = []
        recurringExpenses = []
        salaryEntries = []
        categories = ExpenseCategory.placeholderCategories
        deletedCategoryBuckets = []
        currentCategoryIndex = 0
        appTheme = .system
        userName = ""
        currency = .ils
        dateDisplayFormat = .dayMonthYear
        salaryReceiptDay = 1
        checkingBalance = nil
        isUserNamePromptPresented = false
        isSalaryPromptPresented = false
        didSkipSalaryPromptThisSession = false
        isSideMenuOpen = false
        selectedMenuOption = nil
        pendingExpense = nil
        expenseName = ""
        isNamingSheetPresented = false
        newCategoryName = ""
        newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
        newCategoryTintName = CategoryAppearanceOption.defaultTintName
        categoryNameError = nil
        isCategorySheetPresented = false
        isManageCategoriesPresented = false
        isSettingsPresented = false
        isAddExpensePresented = false
        mainAddExpenseIsRecurring = false
        isMainAddSelectorPresented = false
        mainSelectedAddAction = nil
        isMainAddTypeSelectorPresented = false
        isMainAddSavingPresented = false
        isMainRecurringSavingPresented = false
        isMainAddDebtDirectionPresented = false
        isMainAddDebtPresented = false
        mainAddDebtDirection = .owedToMe
        mainAlertMessage = nil
        isBackfillExpensePresented = false
        isManageRecurringExpensesPresented = false
        isPastExpensesPresented = false
        isSalaryHistoryPresented = false
        isAnalyticsPresented = false
        categoryForMonthlyDetails = nil
        isSavingsManagementPresented = false
        isDebtsManagementPresented = false
        categoryTransitionDirection = -1
        isNavigatingCategory = false
        categoryNavigationLockID = 0
        appSettings.language = .en
        isInitialSetupPresented = true
        rootRefreshID = UUID()
    }

    private func restoreSnapshot(_ snapshot: RestoreSnapshot) {
        expenses = snapshot.expenses
        recurringExpenses = snapshot.recurringExpenses
        salaryEntries = snapshot.salaryEntries
        categories = snapshot.categories.isEmpty ? ExpenseCategory.placeholderCategories : snapshot.categories
        deletedCategoryBuckets = snapshot.deletedCategoryBuckets
        userName = snapshot.userName
        currency = snapshot.currency
        appSettings.language = snapshot.appLanguage
        salaryReceiptDay = snapshot.salaryReceiptDay
        checkingBalance = snapshot.checkingBalance
        currentCategoryIndex = min(currentCategoryIndex, max(categories.count - 1, 0))

        Storage.saveExpenses(expenses)
        Storage.saveRecurringExpenses(recurringExpenses)
        Storage.saveSavings(snapshot.savings)
        Storage.saveSavingGoals(snapshot.savingGoals)
        Storage.saveRecurringSavings(snapshot.recurringSavings)
        Storage.saveDebts(snapshot.debts)
        Storage.saveSalaryEntries(salaryEntries)
        Storage.saveCategories(categories)
        Storage.saveDeletedCategoryBuckets(deletedCategoryBuckets)
        Storage.saveUserName(userName)
        Storage.saveCurrency(currency)
        Storage.saveAppLanguage(appLanguage)
        Storage.saveSalaryReceiptDay(salaryReceiptDay)
        Storage.saveCheckingBalance(checkingBalance)
        Storage.saveSavingsGoal(snapshot.savingsGoal)
        Storage.saveInitialSetupCompleted(true)
    }

    private func completeInitialSetup(name: String, language: AppLanguage) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidSetupUserName(trimmedName) else {
            return
        }

        userName = trimmedName
        appSettings.language = language
        Storage.saveUserName(trimmedName)
        Storage.saveAppLanguage(language)
        Storage.saveInitialSetupCompleted(true)
        isInitialSetupPresented = false
        rootRefreshID = UUID()
        presentSalaryPromptIfNeeded()
    }

    private func createDebugTestData() {
        #if DEBUG
        Storage.createDebugQATestData()
        loadStoredData()
        rootRefreshID = UUID()
        #endif
    }

    private func clearDebugTestData() {
        #if DEBUG
        Storage.clearDebugQATestData()
        loadStoredData()
        rootRefreshID = UUID()
        #endif
    }

    private func presentSalaryPromptIfNeeded() {
        guard !didSkipSalaryPromptThisSession,
              shouldAskForCurrentMonthSalary else {
            return
        }

        isSalaryPromptPresented = true
    }

    private var shouldAskForCurrentMonthSalary: Bool {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)

        guard let year = components.year,
              let month = components.month,
              let promptDate = calendar.salaryPromptDate(year: year, month: month, day: salaryReceiptDay),
              now >= promptDate else {
            return false
        }

        return !salaryEntries.contains { $0.year == year && $0.month == month }
    }

    private func saveCurrentMonthSalary(_ amount: Decimal) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())

        guard let year = components.year,
              let month = components.month else {
            return
        }

        salaryEntries.removeAll { $0.year == year && $0.month == month }
        salaryEntries.append(SalaryEntry(year: year, month: month, amount: amount, createdAt: Date()))
        salaryEntries.sort { $0.monthDate > $1.monthDate }
        Storage.saveSalaryEntries(salaryEntries)
        isSalaryPromptPresented = false
    }

    private func loadStoredData() {
        expenses = Storage.loadExpenses()
        recurringExpenses = Storage.loadRecurringExpenses()
        salaryEntries = Storage.loadSalaryEntries()
        categories = Storage.loadCategories(defaults: ExpenseCategory.placeholderCategories)
        deletedCategoryBuckets = Storage.loadDeletedCategoryBuckets()
        appTheme = Storage.loadAppTheme()
        userName = Storage.loadUserName() ?? ""
        currency = Storage.loadCurrency()
        mainSelectedCurrency = Storage.loadTemporaryCurrency(primaryCurrency: currency)
        temporaryCurrencyStartDate = Storage.loadTemporaryCurrencyStartDate()
        temporaryCurrencyExpirationDate = Storage.loadTemporaryCurrencyExpirationDate()
        dateDisplayFormat = Storage.loadDateDisplayFormat()
        appSettings.language = Storage.loadAppLanguage()
        salaryReceiptDay = Storage.loadSalaryReceiptDay()
        checkingBalance = Storage.loadCheckingBalance()
        isInitialSetupPresented = !Storage.isInitialSetupCompleted() || !isValidSetupUserName(userName)
        isUserNamePromptPresented = false
    }
}

private struct SideMenuView: View {
    @Binding var appTheme: AppTheme
    let appLanguage: AppLanguage
    let onThemeChanged: (AppTheme) -> Void
    let onSelect: (MenuOption) -> Void

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
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
                .accessibilityLabel(appTheme.themeToggleAccessibilityLabel(for: appLanguage))
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

                        Text(option.title(for: appLanguage))
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
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private enum MenuOption: String, CaseIterable, Identifiable {
    case settings
    case analytics
    case manageCategories
    case manageRecurringExpenses
    case manageSavings
    case manageDebts
    case salaryHistory
    case pastExpenses

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage = .he) -> String {
        switch self {
        case .settings:
            return language.text(he: "הגדרות", en: "Settings")
        case .analytics:
            return language.text(he: "ניתוח נתונים", en: "Analytics")
        case .manageCategories:
            return language.text(he: "נהל קטגוריות", en: "Manage Categories")
        case .manageRecurringExpenses:
            return language.text(he: "פעולות חוזרות", en: "Recurring Items")
        case .manageSavings:
            return language.text(he: "נהל חסכונות", en: "Savings")
        case .manageDebts:
            return language.text(he: "נהל חובות", en: "Debts")
        case .salaryHistory:
            return language.text(he: "צפייה בתלושים", en: "Salary Slips")
        case .pastExpenses:
            return language.text(he: "צפה בנתוני עבר", en: "Past Data")
        }
    }

    var systemImageName: String {
        switch self {
        case .settings:
            "gearshape"
        case .analytics:
            "chart.bar.xaxis"
        case .manageCategories:
            "square.grid.2x2"
        case .manageRecurringExpenses:
            "arrow.triangle.2.circlepath"
        case .manageSavings:
            "banknote.fill"
        case .manageDebts:
            "person.crop.circle.badge.exclamationmark"
        case .salaryHistory:
            "doc.text.fill"
        case .pastExpenses:
            "calendar"
        }
    }
}

private enum FinancialAddAction: String, CaseIterable, Identifiable {
    case expense
    case debt
    case saving

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .expense:
            language.text(he: "הוצאה", en: "Expense")
        case .debt:
            language.text(he: "חוב", en: "Debt")
        case .saving:
            language.text(he: "חסכון", en: "Saving")
        }
    }

    var systemImageName: String {
        switch self {
        case .expense:
            "creditcard.fill"
        case .debt:
            "person.crop.circle.badge.exclamationmark"
        case .saving:
            "banknote.fill"
        }
    }

    func typePrompt(for language: AppLanguage) -> String {
        switch self {
        case .expense:
            language.text(he: "איזו הוצאה?", en: "Which expense?")
        case .debt:
            language.text(he: "איזה חוב?", en: "Which debt?")
        case .saving:
            language.text(he: "איזה חסכון?", en: "Which saving?")
        }
    }
}

private enum AddOccurrenceType: String, CaseIterable, Identifiable {
    case oneTime
    case recurring

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .oneTime:
            language.text(he: "חד פעמי", en: "One-time")
        case .recurring:
            language.text(he: "חוזר", en: "Recurring")
        }
    }

    var systemImageName: String {
        switch self {
        case .oneTime:
            "1.circle"
        case .recurring:
            "arrow.triangle.2.circlepath"
        }
    }
}

private struct AddActionBubbleView: View {
    let title: String
    let actions: [FinancialAddAction]
    let appLanguage: AppLanguage
    let onSelect: (FinancialAddAction) -> Void

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            ForEach(actions) { action in
                Button {
                    onSelect(action)
                } label: {
                    Label(action.title(for: appLanguage), systemImage: action.systemImageName)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(width: 230)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct PastDataActionBubbleView: View {
    let appLanguage: AppLanguage
    let onEdit: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 10) {
            Text(appLanguage.text(he: "מה תרצה לעשות?", en: "What would you like to do?"))
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Button {
                onEdit()
            } label: {
                Label(appLanguage.text(he: "עריכת נתוני עבר", en: "Edit Past Data"), systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)

            Button {
                onAdd()
            } label: {
                Label(appLanguage.text(he: "הוספת נתונים לעבר", en: "Add Past Data"), systemImage: "plus.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(width: 250)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct AddOccurrenceBubbleView: View {
    let title: String
    let appLanguage: AppLanguage
    let onSelect: (AddOccurrenceType) -> Void

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            ForEach(AddOccurrenceType.allCases) { type in
                Button {
                    onSelect(type)
                } label: {
                    Label(type.title(for: appLanguage), systemImage: type.systemImageName)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(width: 230)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct ExpenseNameView: View {
    @Environment(\.appLanguage) private var appLanguage

    @Binding var expenseName: String
    let onSave: () -> Void
    let onSkip: () -> Void

    private var isNameValid: Bool {
        !expenseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 22) {
            Text(appLanguage.text(he: "שם להוצאה", en: "Expense Name"))
                .font(.title3.bold())

            TextField(appLanguage.text(he: "לדוגמה: קפה, סופר, דלק", en: "Example: coffee, groceries, fuel"), text: $expenseName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.title3)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "מ׳כפת׳ך", en: "Whatever")) {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isNameValid)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct AddCategoryView: View {
    @Environment(\.appLanguage) private var appLanguage

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
            Text(appLanguage.text(he: "שם קטגוריה", en: "Category Name"))
                .font(.title3.bold())

            TextField(appLanguage.text(he: "לדוגמה: אוכל בחוץ", en: "Example: eating out"), text: $categoryName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.title3)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
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
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isNameValid)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct UserNamePromptView: View {
    @Environment(\.appLanguage) private var appLanguage

    let initialName: String
    let title: String
    let saveTitle: String
    let onSave: (String) -> Void

    @State private var name: String

    init(initialName: String, title: String, saveTitle: String, onSave: @escaping (String) -> Void) {
        self.initialName = initialName
        self.title = title
        self.saveTitle = saveTitle
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            TextField(appLanguage.text(he: "שם משתמש", en: "User name"), text: $name)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Button(saveTitle) {
                onSave(trimmedName)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedName.isEmpty)
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct FirstLaunchSetupView: View {
    let initialLanguage: AppLanguage
    let onComplete: (String, AppLanguage) -> Void

    @State private var name = ""
    @State private var selectedLanguage: AppLanguage

    init(initialLanguage: AppLanguage, onComplete: @escaping (String, AppLanguage) -> Void) {
        self.initialLanguage = initialLanguage
        self.onComplete = onComplete
        _selectedLanguage = State(initialValue: initialLanguage)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleText: String {
        selectedLanguage.text(he: "איך קוראים לך?", en: "What is your name?")
    }

    private var isNameValid: Bool {
        isValidSetupUserName(name)
    }

    private var shouldShowNameValidation: Bool {
        !trimmedName.isEmpty && !isNameValid
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: selectedLanguage.horizontalAlignment, spacing: 18) {
                Spacer(minLength: 24)

                Text(titleText)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .center)

                TextField(selectedLanguage.text(he: "שם", en: "Name"), text: $name)
                    .textInputAutocapitalization(.words)
                    .localizedTextInput(selectedLanguage)
                    .font(.headline)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                if shouldShowNameValidation {
                    Text(selectedLanguage.text(he: "יש להזין שם כדי להמשיך", en: "Please enter a name to continue"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: selectedLanguage.frameAlignment)
                }

                VStack(alignment: selectedLanguage.horizontalAlignment, spacing: 10) {
                    Text(selectedLanguage.text(he: "בחר שפה", en: "Choose Language"))
                        .font(.headline)

                    Picker(selectedLanguage.text(he: "בחר שפה", en: "Choose Language"), selection: $selectedLanguage) {
                        Text("עברית").tag(AppLanguage.he)
                        Text("English").tag(AppLanguage.en)
                    }
                    .pickerStyle(.segmented)
                }

                Button(selectedLanguage.text(he: "המשך", en: "Continue")) {
                    onComplete(trimmedName, selectedLanguage)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isNameValid)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

                Spacer()
            }
            .padding(24)
            .navigationTitle(selectedLanguage.text(he: "התחלה", en: "Setup"))
        }
        .environment(\.appLanguage, selectedLanguage)
        .environment(\.layoutDirection, selectedLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: selectedLanguage.localeIdentifier))
    }
}

private struct SettingsView: View {
    let userName: String
    @Binding var currency: CurrencyOption
    @Binding var appLanguage: AppLanguage
    @Binding var dateDisplayFormat: DateDisplayFormat
    @Binding var salaryReceiptDay: Int
    @Binding var checkingBalance: Decimal?
    let onSaveUserName: (String) -> Void
    let onPersistSettings: () -> Void
    let onResetApp: () -> Void
    let onRestoreSnapshot: (RestoreSnapshot) -> Void
    let onCreateTestData: () -> Void
    let onClearTestData: () -> Void
    let onClose: () -> Void

    @State private var isUserNameEditorPresented = false
    @State private var isResetConfirmationPresented = false
    @State private var isRestorePresented = false
    @State private var isCheckingBalanceEditorPresented = false
    @State private var isLanguageRefreshOverlayPresented = false
    @State private var isResetSuccessPresented = false
    #if DEBUG
    @State private var debugDataMessage: String?
    #endif

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    Section(appLanguage.text(he: "משתמש", en: "User")) {
                        Button {
                            isUserNameEditorPresented = true
                        } label: {
                            HStack {
                                Text(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? appLanguage.text(he: "לא הוגדר", en: "Not set") : userName)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(appLanguage.text(he: "שם משתמש", en: "User name"))
                                    .font(.headline)
                            }
                        }
                    }

                    Section(appLanguage.text(he: "העדפות", en: "Preferences")) {
                        Picker(appLanguage.text(he: "מטבע ראשי", en: "Primary Currency"), selection: $currency) {
                            ForEach(CurrencyOption.allCases) { currency in
                                Text(currency.title(for: appLanguage)).tag(currency)
                            }
                        }
                        .onChange(of: currency) {
                            onPersistSettings()
                        }

                        Picker(appLanguage.text(he: "שפה", en: "Language"), selection: $appLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title(for: appLanguage)).tag(language)
                            }
                        }
                        .onChange(of: appLanguage) {
                            onPersistSettings()
                            showLanguageRefreshOverlay()
                        }

                        Picker(appLanguage.text(he: "פורמט תאריך", en: "Date Format"), selection: $dateDisplayFormat) {
                            ForEach(DateDisplayFormat.allCases) { format in
                                Text(format.title(for: appLanguage)).tag(format)
                            }
                        }
                        .onChange(of: dateDisplayFormat) {
                            onPersistSettings()
                        }
                    }

                    Section(appLanguage.text(he: "תלוש ועו״ש", en: "Salary and checking")) {
                        Picker(appLanguage.text(he: "תאריך קבלת תלוש", en: "Salary receipt day"), selection: $salaryReceiptDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text(day.salaryReceiptDayTitle(for: appLanguage, dateDisplayFormat: dateDisplayFormat)).tag(day)
                            }
                        }
                        .onChange(of: salaryReceiptDay) {
                            onPersistSettings()
                        }

                        Button {
                            isCheckingBalanceEditorPresented = true
                        } label: {
                            HStack {
                                Text(checkingBalance?.formattedShekelAmount ?? appLanguage.text(he: "לא הוגדר", en: "Not set"))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(appLanguage.text(he: "יתרה נוכחית בעו״ש", en: "Current checking balance"))
                                    .font(.headline)
                            }
                        }
                    }

                    Section(appLanguage.text(he: "איפוס ושחזור", en: "Reset and restore")) {
                        Button(appLanguage.text(he: "שחזור נתונים", en: "Restore Data")) {
                            isRestorePresented = true
                        }

                        Button(appLanguage.text(he: "איפוס אפליקציה", en: "Reset App"), role: .destructive) {
                            isResetConfirmationPresented = true
                        }
                    }

                    #if DEBUG
                    Section(appLanguage.text(he: "בדיקות", en: "Testing")) {
                        Button(appLanguage.text(he: "צור נתוני בדיקה", en: "Create Test Data")) {
                            onCreateTestData()
                            debugDataMessage = appLanguage.text(he: "נתוני הבדיקה נוצרו", en: "Test data created")
                        }

                        Button(appLanguage.text(he: "נקה נתוני בדיקה", en: "Clear Test Data"), role: .destructive) {
                            onClearTestData()
                            debugDataMessage = appLanguage.text(he: "נתוני הבדיקה נמחקו", en: "Test data cleared")
                        }
                    }
                    #endif
                }
                .navigationTitle(appLanguage.text(he: "הגדרות", en: "Settings"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(appLanguage.text(he: "סגור", en: "Close")) {
                            onClose()
                        }
                    }
                }
            }
            .id(appLanguage)

            if isLanguageRefreshOverlayPresented {
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()

                    Text(appLanguage.loadingText)
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .confirmationDialog(
            appLanguage.text(he: "האם אתה בטוח שברצונך לאפס את האפליקציה?", en: "Are you sure you want to reset the app?"),
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(appLanguage.text(he: "אפס אפליקציה", en: "Reset App"), role: .destructive) {
                onResetApp()
                isResetSuccessPresented = true
            }

            Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(appLanguage.text(
                he: "איפוס האפליקציה ימחק את כל הנתונים ויחזיר את האפליקציה להתחלה.",
                en: "Resetting the app will delete all data and return the app to the initial setup."
            ))
        }
        .alert(
            appLanguage.text(he: "האפליקציה אופסה בהצלחה", en: "App reset successfully"),
            isPresented: $isResetSuccessPresented
        ) {
            Button(appLanguage.text(he: "אישור", en: "OK"), role: .cancel) {}
        }
        #if DEBUG
        .alert(
            debugDataMessage ?? "",
            isPresented: Binding(
                get: { debugDataMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        debugDataMessage = nil
                    }
                }
            )
        ) {
            Button(appLanguage.text(he: "אישור", en: "OK"), role: .cancel) {}
        }
        #endif
        .fullScreenCover(isPresented: $isRestorePresented) {
            RestoreSnapshotsView(
                snapshots: Storage.loadRestoreSnapshots(),
                onRestore: { snapshot in
                    onRestoreSnapshot(snapshot)
                    isRestorePresented = false
                },
                onClose: {
                    isRestorePresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
        }
        .sheet(isPresented: $isUserNameEditorPresented) {
            UserNamePromptView(
                initialName: userName,
                title: appLanguage.text(he: "שם משתמש", en: "User name"),
                saveTitle: appLanguage.text(he: "שמור", en: "Save"),
                onSave: { name in
                    onSaveUserName(name)
                    isUserNameEditorPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(240)])
        }
        .sheet(isPresented: $isCheckingBalanceEditorPresented) {
            CheckingBalanceEditorView(
                balance: checkingBalance,
                onSave: { balance in
                    checkingBalance = balance
                    onPersistSettings()
                    isCheckingBalanceEditorPresented = false
                },
                onCancel: {
                    isCheckingBalanceEditorPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(260)])
        }
    }

    private func showLanguageRefreshOverlay() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isLanguageRefreshOverlayPresented = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeInOut(duration: 0.18)) {
                isLanguageRefreshOverlayPresented = false
            }
        }
    }
}

private struct RestoreSnapshotsView: View {
    @Environment(\.appLanguage) private var appLanguage

    let snapshots: [RestoreSnapshot]
    let onRestore: (RestoreSnapshot) -> Void
    let onClose: () -> Void

    @State private var snapshotPendingRestore: RestoreSnapshot?

    var body: some View {
        NavigationStack {
            List {
                if snapshots.isEmpty {
                    Text(appLanguage.text(he: "אין נתונים לשחזור", en: "No restore data"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshots) { snapshot in
                        Button(snapshot.displayTitle(for: appLanguage)) {
                            snapshotPendingRestore = snapshot
                        }
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "שחזור נתונים", en: "Restore Data"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .confirmationDialog(
            appLanguage.text(he: "האם לשחזר את הנתונים מהתאריך הזה?", en: "Restore the data from this date?"),
            isPresented: restoreDialogBinding,
            titleVisibility: .visible
        ) {
            Button(appLanguage.text(he: "שחזר", en: "Restore")) {
                if let snapshotPendingRestore {
                    onRestore(snapshotPendingRestore)
                }
            }

            Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {
                snapshotPendingRestore = nil
            }
        }
    }

    private var restoreDialogBinding: Binding<Bool> {
        Binding(
            get: { snapshotPendingRestore != nil },
            set: { isPresented in
                if !isPresented {
                    snapshotPendingRestore = nil
                }
            }
        )
    }
}

private struct CheckingBalanceEditorView: View {
    @Environment(\.appLanguage) private var appLanguage

    let balance: Decimal?
    let onSave: (Decimal?) -> Void
    let onCancel: () -> Void

    @State private var balanceText: String
    @State private var errorMessage: String?

    init(balance: Decimal?, onSave: @escaping (Decimal?) -> Void, onCancel: @escaping () -> Void) {
        self.balance = balance
        self.onSave = onSave
        self.onCancel = onCancel
        _balanceText = State(initialValue: balance?.plainString ?? "")
    }

    private var parsedBalance: Decimal? {
        let trimmedValue = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        return Decimal(string: trimmedValue, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        balanceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (parsedBalance ?? -1) >= 0
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(appLanguage.text(he: "יתרה נוכחית בעו״ש", en: "Current checking balance"))
                .font(.title3.bold())

            AmountInputField(amountText: $balanceText)
                .onChange(of: balanceText) {
                    errorMessage = nil
                }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    let trimmedValue = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedValue.isEmpty else {
                        onSave(nil)
                        return
                    }

                    guard let parsedBalance, parsedBalance >= 0 else {
                        errorMessage = appLanguage.text(he: "היתרה חייבת להיות 0 או יותר", en: "Balance must be 0 or more")
                        return
                    }

                    onSave(parsedBalance)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct SalaryPromptView: View {
    @Environment(\.appLanguage) private var appLanguage

    let currencySymbol: String
    let onSave: (Decimal) -> Void
    let onSkip: () -> Void

    @State private var amountText = ""
    @State private var errorMessage: String?

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        (parsedAmount ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(appLanguage.text(he: "כמה כסף נכנס החודש?", en: "How much money came in this month?"))
                .font(.title3.bold())

            AmountInputField(amountText: $amountText)
                .onChange(of: amountText) {
                    errorMessage = nil
                }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "דלג", en: "Skip")) {
                    onSkip()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let parsedAmount, parsedAmount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    onSave(parsedAmount)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct SalaryHistoryView: View {
    @Binding var salaryEntries: [SalaryEntry]
    let expenses: [Expense]
    let savings: [Saving]
    let appLanguage: AppLanguage
    let onClose: () -> Void
    let onPersist: () -> Void

    @State private var isAddingSalary = false
    @State private var salaryBeingEdited: SalaryEntry?
    @State private var salaryPendingDelete: SalaryEntry?

    private var sortedEntries: [SalaryEntry] {
        salaryEntries.sorted { $0.monthDate > $1.monthDate }
    }

    private var averageSalaryText: String {
        guard !salaryEntries.isEmpty else {
            return appLanguage.text(he: "משכורת ממוצעת: לא קיים מידע", en: "Average salary: no data")
        }

        let total = salaryEntries.reduce(Decimal(0)) { total, entry in
            total + entry.amount
        }
        let average = total / Decimal(salaryEntries.count)
        return "\(appLanguage.text(he: "משכורת ממוצעת", en: "Average salary")): \(average.formattedShekelAmount)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(averageSalaryText)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                }

                Section(appLanguage.text(he: "חודשים", en: "Months")) {
                    if sortedEntries.isEmpty {
                        Text(appLanguage.text(he: "אין תלושים עדיין", en: "No salary slips yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedEntries) { entry in
                            SalaryMonthRow(
                                entry: entry,
                                spent: monthlyExpenses(for: entry),
                                saved: monthlySavingsNet(for: entry),
                                appLanguage: appLanguage,
                                onEdit: {
                                    salaryBeingEdited = entry
                                },
                                onDelete: {
                                    salaryPendingDelete = entry
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "תלושים", en: "Salary Slips"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingSalary = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(appLanguage.text(he: "הוסף תלוש", en: "Add salary slip"))
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .sheet(isPresented: $isAddingSalary) {
            SalaryEntryEditorView(
                entry: nil,
                selectedMonth: Date(),
                allowsMonthSelection: true,
                onSave: addSalaryEntry,
                onCancel: { isAddingSalary = false }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(340)])
        }
        .sheet(item: $salaryBeingEdited) { entry in
            SalaryEntryEditorView(
                entry: entry,
                selectedMonth: entry.monthDate,
                allowsMonthSelection: true,
                onSave: { updatedEntry in
                    updateSalaryEntry(updatedEntry)
                    salaryBeingEdited = nil
                },
                onCancel: { salaryBeingEdited = nil }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(340)])
        }
        .alert(
            appLanguage.text(he: "מחיקת הכנסה", en: "Delete Income"),
            isPresented: salaryDeleteAlertBinding
        ) {
            Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {
                salaryPendingDelete = nil
            }

            Button(appLanguage.text(he: "מחק", en: "Delete"), role: .destructive) {
                if let salaryPendingDelete {
                    deleteSalaryEntry(salaryPendingDelete)
                }
                salaryPendingDelete = nil
            }
        } message: {
            Text(appLanguage.text(
                he: "האם אתה בטוח שברצונך למחוק את ההכנסה?",
                en: "Are you sure you want to delete this income entry?"
            ))
        }
    }

    private var salaryDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { salaryPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    salaryPendingDelete = nil
                }
            }
        )
    }

    private func monthlyExpenses(for entry: SalaryEntry) -> Decimal {
        expenses
            .filter { expense in
                let components = Calendar.current.dateComponents([.year, .month], from: expense.date)
                return components.year == entry.year && components.month == entry.month
            }
            .reduce(Decimal(0)) { total, expense in
                total + expense.netAmount
            }
    }

    private func monthlySavingsNet(for entry: SalaryEntry) -> Decimal {
        savings
            .filter { saving in
                let components = Calendar.current.dateComponents([.year, .month], from: saving.date)
                return components.year == entry.year && components.month == entry.month
            }
            .reduce(Decimal(0)) { total, saving in
                switch saving.kind {
                case .deposit:
                    return total + saving.amount
                case .withdrawal:
                    return total - saving.amount
                }
            }
    }

    private func addSalaryEntry(_ entry: SalaryEntry) {
        salaryEntries.removeAll { $0.year == entry.year && $0.month == entry.month }
        salaryEntries.append(entry)
        salaryEntries.sort { $0.monthDate > $1.monthDate }
        onPersist()
        isAddingSalary = false
    }

    private func updateSalaryEntry(_ entry: SalaryEntry) {
        salaryEntries.removeAll { existing in
            existing.id != entry.id && existing.year == entry.year && existing.month == entry.month
        }

        guard let index = salaryEntries.firstIndex(where: { $0.id == entry.id }) else {
            salaryEntries.append(entry)
            onPersist()
            return
        }

        salaryEntries[index] = entry
        salaryEntries.sort { $0.monthDate > $1.monthDate }
        onPersist()
    }

    private func deleteSalaryEntry(_ entry: SalaryEntry) {
        salaryEntries.removeAll { $0.id == entry.id }
        onPersist()
    }
}

private struct SalaryMonthRow: View {
    let entry: SalaryEntry
    let spent: Decimal
    let saved: Decimal
    let appLanguage: AppLanguage
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    private var unreported: Decimal {
        entry.amount - spent - saved
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: appLanguage.horizontalAlignment, spacing: 5) {
                Text(entry.monthDate.monthYearText(for: appLanguage))
                    .font(.headline)

                Text("\(appLanguage.text(he: "נכנס בתלוש", en: "Salary income")): \(entry.amount.formattedShekelAmount)")
                    .font(.subheadline)

                Text("\(appLanguage.text(he: "נחסך", en: "Saved")): \(saved.formattedShekelAmount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(appLanguage.text(he: "הוצא", en: "Spent")): \(spent.formattedShekelAmount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(appLanguage.text(he: "לא דווח / בעו״ש", en: "Unreported / checking")): \(unreported.formattedShekelAmount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 14) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(he: "ערוך תלוש", en: "Edit salary slip"))

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(he: "מחק תלוש", en: "Delete salary slip"))
            }
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .padding(.vertical, 4)
    }
}

private struct SavingsManagementView: View {
    @Environment(\.appLanguage) private var appLanguage

    let userName: String
    let onClose: () -> Void

    @State private var savings: [Saving] = []
    @State private var savingGoals: [SavingGoal] = []
    @State private var recurringSavings: [RecurringSaving] = []
    @State private var isAddSavingPresented = false
    @State private var isAddSavingGoalPresented = false
    @State private var isAddRecurringSavingPresented = false
    @State private var savingFormKind: SavingKind = .deposit
    @State private var savingsGoal: Decimal?
    @State private var isSavingsGoalEditorPresented = false
    @State private var selectedBreakdownGoal: SavingGoal?
    @State private var selectedHistoryMonth = Date()

    private var savingsBalance: Decimal {
        Saving.balance(for: savings)
    }

    private var availableWithdrawalSourceOptions: [SavingSourceOption] {
        SavingSourceOption.options(from: savings, goalId: nil, language: appLanguage)
    }

    private var hasWithdrawalSources: Bool {
        !availableWithdrawalSourceOptions.isEmpty
    }

    private var activeSavingGoals: [SavingGoal] {
        savingGoals.filter(\.isActive)
    }

    private var savingsForSelectedHistoryMonth: [Saving] {
        savings
            .filter { Calendar.current.isDate($0.date, equalTo: selectedHistoryMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private var totalSavingGoalTargets: Decimal {
        activeSavingGoals.reduce(Decimal(0)) { $0 + $1.targetAmount }
    }

    private var totalSavedAcrossGoals: Decimal {
        activeSavingGoals.reduce(Decimal(0)) { total, goal in
            total + Saving.balance(for: savings, goalId: goal.id)
        }
    }

    private var savingGoalsProgressText: String? {
        guard totalSavingGoalTargets > 0 else {
            return nil
        }

        let percentage = totalSavedAcrossGoals / totalSavingGoalTargets * 100
        return appLanguage.text(
            he: "חסכת \(totalSavedAcrossGoals.formattedShekelAmount) מתוך \(totalSavingGoalTargets.formattedShekelAmount)",
            en: "Saved \(totalSavedAcrossGoals.formattedShekelAmount) out of \(totalSavingGoalTargets.formattedShekelAmount)"
        ) + "\n" + appLanguage.text(
            he: "\(percentage.formattedPercentText) מתוך סך היעדים",
            en: "\(percentage.formattedPercentText) of total goals"
        )
    }

    private var headerText: String {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return appLanguage.text(
                he: "היי, יש לך כרגע \(savingsBalance.formattedShekelAmount) בחסכון.",
                en: "Hi, you currently have \(savingsBalance.formattedShekelAmount) in savings."
            )
        }

        return appLanguage.text(
            he: "היי \(trimmedName), יש לך כרגע \(savingsBalance.formattedShekelAmount) בחסכון.",
            en: "Hi \(trimmedName), you currently have \(savingsBalance.formattedShekelAmount) in savings."
        )
    }

    private var savingsGoalText: String {
        guard let savingsGoal else {
            return appLanguage.text(he: "לא הוגדר יעד חסכון", en: "No savings goal set")
        }

        return appLanguage.text(
            he: "יעד חסכון: \(savingsGoal.formattedShekelAmount)",
            en: "Savings goal: \(savingsGoal.formattedShekelAmount)"
        )
    }

    private var savingsGoalProgressText: String? {
        guard let savingsGoal, savingsGoal > 0 else {
            return nil
        }

        let percentage = savingsBalance / savingsGoal * 100
        return appLanguage.text(
            he: "חסכת \(savingsBalance.formattedShekelAmount) מתוך \(savingsGoal.formattedShekelAmount) (\(percentage.formattedPercentText))",
            en: "Saved \(savingsBalance.formattedShekelAmount) of \(savingsGoal.formattedShekelAmount) (\(percentage.formattedPercentText))"
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(headerText)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        .padding(.vertical, 6)

                    if let savingGoalsProgressText {
                        Text(savingGoalsProgressText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    } else {
                        Text(appLanguage.text(he: "אין יעדי חסכון עדיין", en: "No saving goals yet"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    }
                }

                Section {
                    Button {
                        savingFormKind = .withdrawal
                        isAddSavingPresented = true
                    } label: {
                        Label(appLanguage.text(he: "משיכה מחיסכון", en: "Withdraw from Savings"), systemImage: "minus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!hasWithdrawalSources)

                    if !hasWithdrawalSources {
                        Text(appLanguage.text(he: "אין חסכונות זמינים למשיכה", en: "No savings available to withdraw"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    }
                }

                Section(appLanguage.text(he: "יעדי חסכון", en: "Saving Goals")) {
                    Button {
                        isAddSavingGoalPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "target")
                            Text(appLanguage.text(he: "הוסף יעד חסכון", en: "Add Saving Goal"))
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)

                    if savingGoals.isEmpty {
                        Text(appLanguage.text(he: "אין יעדי חסכון עדיין", en: "No saving goals yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savingGoals) { goal in
                            SavingGoalRow(
                                goal: goal,
                                savedAmount: Saving.balance(for: savings, goalId: goal.id),
                                onShowBreakdown: {
                                    selectedBreakdownGoal = goal
                                }
                            )
                        }
                    }
                }

                Section(appLanguage.text(he: "חסכונות קבועים", en: "Recurring Savings")) {
                    if recurringSavings.isEmpty {
                        Text(appLanguage.text(he: "אין חסכונות קבועים עדיין", en: "No recurring savings yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recurringSavings) { recurringSaving in
                            RecurringSavingRow(
                                recurringSaving: recurringSaving,
                                goal: savingGoals.first { $0.id == recurringSaving.goalId }
                            )
                        }
                    }
                }

                Section(appLanguage.text(he: "היסטוריית חסכונות", en: "Savings History")) {
                    MonthNavigationView(
                        selectedMonth: $selectedHistoryMonth,
                        maximumMonth: Date()
                    )

                    if savingsForSelectedHistoryMonth.isEmpty {
                        Text(appLanguage.text(he: "אין פעולות חיסכון בחודש זה", en: "No savings activity this month"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savingsForSelectedHistoryMonth) { saving in
                            SavingRow(
                                saving: saving,
                                goal: savingGoals.first { $0.id == saving.goalId }
                            )
                        }
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "חסכונות", en: "Savings"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        savingFormKind = .deposit
                        isAddSavingPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(appLanguage.text(he: "הוסף חסכון", en: "Add saving"))
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            savings = Storage.loadSavings()
            savingGoals = Storage.loadSavingGoals()
            recurringSavings = Storage.loadRecurringSavings()
            savingsGoal = Storage.loadSavingsGoal()
        }
        .sheet(isPresented: $isAddSavingPresented) {
            AddSavingView(
                kind: savingFormKind,
                availableBalance: savingsBalance,
                goals: savingGoals,
                savings: savings,
                allowsRecurring: true,
                onSave: addSaving,
                onSaveRecurring: addRecurringSaving,
                onCancel: {
                    isAddSavingPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(430)])
        }
        .sheet(isPresented: $isAddSavingGoalPresented) {
            SavingGoalEditorView(
                onSave: addSavingGoal,
                onCancel: {
                    isAddSavingGoalPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(430)])
        }
        .sheet(isPresented: $isAddRecurringSavingPresented) {
            RecurringSavingEditorView(
                goals: savingGoals,
                onSave: addRecurringSaving,
                onCancel: {
                    isAddRecurringSavingPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(380)])
        }
        .sheet(isPresented: $isSavingsGoalEditorPresented) {
            SavingsGoalEditorView(
                savingsGoal: savingsGoal,
                onSave: saveSavingsGoal,
                onCancel: {
                    isSavingsGoalEditorPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(260)])
        }
        .sheet(item: $selectedBreakdownGoal) { goal in
            SavingGoalBreakdownView(
                goal: goal,
                savings: savings,
                onClose: {
                    selectedBreakdownGoal = nil
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(420)])
        }
    }

    private func addSaving(_ saving: Saving) {
        savings.append(saving)
        savings.sort { $0.date > $1.date }
        Storage.saveSavings(savings)
        isAddSavingPresented = false
    }

    private func addSavingGoal(_ goal: SavingGoal) {
        savingGoals.append(goal)
        savingGoals.sort { $0.createdAt > $1.createdAt }
        Storage.saveSavingGoals(savingGoals)
        isAddSavingGoalPresented = false
    }

    private func addRecurringSaving(_ recurringSaving: RecurringSaving) {
        recurringSavings.append(recurringSaving)
        recurringSavings.sort { $0.startDate > $1.startDate }
        Storage.saveRecurringSavings(recurringSavings)
        isAddRecurringSavingPresented = false
        isAddSavingPresented = false
    }

    private func saveSavingsGoal(_ goal: Decimal?) {
        savingsGoal = goal
        Storage.saveSavingsGoal(goal)
        isSavingsGoalEditorPresented = false
    }
}

private struct SavingsGoalEditorView: View {
    @Environment(\.appLanguage) private var appLanguage

    let savingsGoal: Decimal?
    let onSave: (Decimal?) -> Void
    let onCancel: () -> Void

    @State private var goalText: String
    @State private var errorMessage: String?

    init(savingsGoal: Decimal?, onSave: @escaping (Decimal?) -> Void, onCancel: @escaping () -> Void) {
        self.savingsGoal = savingsGoal
        self.onSave = onSave
        self.onCancel = onCancel
        _goalText = State(initialValue: savingsGoal?.plainString ?? "")
    }

    private var parsedGoal: Decimal? {
        let trimmedValue = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        return Decimal(string: trimmedValue, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        let trimmedValue = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty || (parsedGoal ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(appLanguage.text(he: "יעד חסכון", en: "Savings Goal"))
                .font(.title3.bold())

            AmountInputField(amountText: $goalText)
                .onChange(of: goalText) {
                    errorMessage = nil
                }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    let trimmedValue = goalText.trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !trimmedValue.isEmpty else {
                        onSave(nil)
                        return
                    }

                    guard let parsedGoal, parsedGoal > 0 else {
                        errorMessage = appLanguage.text(he: "יעד חייב להיות חיובי", en: "Goal must be positive")
                        return
                    }

                    onSave(parsedGoal)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct SavingGoalRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let goal: SavingGoal
    let savedAmount: Decimal
    let onShowBreakdown: () -> Void

    private var progressText: String {
        guard goal.targetAmount > 0 else {
            return "0%"
        }

        return (savedAmount / goal.targetAmount * 100).formattedPercentText
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
            HStack {
                Text(goal.name)
                    .font(.headline)

                Spacer()

                Text(progressText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    onShowBreakdown()
                } label: {
                    Image(systemName: "eye")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(he: "הצג פירוט יעד חיסכון", en: "Show Saving Goal Breakdown"))
            }

            ProgressView(value: min(NSDecimalNumber(decimal: savedAmount / max(goal.targetAmount, 1)).doubleValue, 1))

            Text("\(savedAmount.formattedShekelAmount) / \(goal.targetAmount.formattedShekelAmount)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Text(goal.locationDisplayText(for: appLanguage))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        }
        .padding(.vertical, 4)
    }
}

private struct SavingSourceOption: Identifiable {
    let id: String
    let title: String
    let amount: Decimal
    let location: SavingLocation
    let customLocation: String
    let goalId: UUID?

    static func options(from savings: [Saving], goalId: UUID?, language: AppLanguage) -> [SavingSourceOption] {
        var totals: [String: (title: String, amount: Decimal, location: SavingLocation, customLocation: String, goalId: UUID?)] = [:]

        for saving in savings where goalId == nil || saving.goalId == goalId {
            let identity = sourceIdentity(for: saving, language: language)
            let signedAmount = saving.kind == .withdrawal ? -saving.amount : saving.amount
            let current = totals[identity.id]?.amount ?? 0
            totals[identity.id] = (
                title: identity.title,
                amount: current + signedAmount,
                location: identity.location,
                customLocation: identity.customLocation,
                goalId: identity.goalId
            )
        }

        return totals.values
            .filter { $0.amount > 0 }
            .map {
                SavingSourceOption(
                    id: sourceKey(location: $0.location, customLocation: $0.customLocation, goalId: $0.goalId),
                    title: $0.title,
                    amount: $0.amount,
                    location: $0.location,
                    customLocation: $0.customLocation,
                    goalId: $0.goalId
                )
            }
            .sorted {
                if $0.amount == $1.amount {
                    return $0.title < $1.title
                }

                return $0.amount > $1.amount
            }
    }

    private static func sourceIdentity(for saving: Saving, language: AppLanguage) -> (id: String, title: String, location: SavingLocation, customLocation: String, goalId: UUID?) {
        let trimmedCustomLocation = saving.customLocation.trimmingCharacters(in: .whitespacesAndNewlines)

        if saving.location == .other {
            guard !trimmedCustomLocation.isEmpty else {
                return (
                    id: sourceKey(location: saving.location, customLocation: "", goalId: saving.goalId),
                    title: language.text(he: "לא צוין מקור", en: "Unspecified Source"),
                    location: saving.location,
                    customLocation: "",
                    goalId: saving.goalId
                )
            }

            return (
                id: sourceKey(location: saving.location, customLocation: trimmedCustomLocation, goalId: saving.goalId),
                title: trimmedCustomLocation,
                location: saving.location,
                customLocation: trimmedCustomLocation,
                goalId: saving.goalId
            )
        }

        return (
            id: sourceKey(location: saving.location, customLocation: "", goalId: saving.goalId),
            title: saving.location.title(for: language),
            location: saving.location,
            customLocation: "",
            goalId: saving.goalId
        )
    }

    private static func sourceKey(location: SavingLocation, customLocation: String, goalId: UUID?) -> String {
        let trimmedCustomLocation = customLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let goalComponent = goalId?.uuidString ?? "general"

        if location == .other {
            return trimmedCustomLocation.isEmpty
                ? "source:\(goalComponent):unspecified"
                : "source:\(goalComponent):custom:\(trimmedCustomLocation)"
        }

        return "source:\(goalComponent):location:\(location.rawValue)"
    }
}

private struct SavingGoalBreakdownView: View {
    @Environment(\.appLanguage) private var appLanguage

    let goal: SavingGoal
    let savings: [Saving]
    let onClose: () -> Void

    private var goalSavings: [Saving] {
        savings.filter { $0.goalId == goal.id }
    }

    private var savedTotal: Decimal {
        sourceBreakdown.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var remainingAmount: Decimal {
        max(goal.targetAmount - savedTotal, 0)
    }

    private var progressPercent: Decimal {
        guard goal.targetAmount > 0 else {
            return 0
        }

        return savedTotal / goal.targetAmount * 100
    }

    private var sourceBreakdown: [SavingSourceOption] {
        SavingSourceOption.options(from: savings, goalId: goal.id, language: appLanguage)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
                        Text(goal.name)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    }
                    .padding(.vertical, 4)
                }

                Section(appLanguage.text(he: "סיכום", en: "Summary")) {
                    SavingGoalBreakdownSummaryRow(
                        title: appLanguage.text(he: "סך הכל נחסך", en: "Total saved"),
                        value: savedTotal.formattedShekelAmount,
                        appLanguage: appLanguage
                    )
                    SavingGoalBreakdownSummaryRow(
                        title: appLanguage.text(he: "סכום יעד", en: "Goal target"),
                        value: goal.targetAmount.formattedShekelAmount,
                        appLanguage: appLanguage
                    )
                    SavingGoalBreakdownSummaryRow(
                        title: appLanguage.text(he: "נותר ליעד", en: "Remaining to goal"),
                        value: remainingAmount.formattedShekelAmount,
                        appLanguage: appLanguage
                    )
                    SavingGoalBreakdownSummaryRow(
                        title: appLanguage.text(he: "התקדמות", en: "Progress"),
                        value: progressPercent.formattedPercentText,
                        appLanguage: appLanguage
                    )
                }

                Section(appLanguage.text(he: "פירוט חסכונות", en: "Savings Breakdown")) {
                    if sourceBreakdown.isEmpty {
                        Text(appLanguage.text(
                            he: "עדיין אין חסכונות משויכים ליעד הזה",
                            en: "No savings are linked to this goal yet"
                        ))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    } else {
                        ForEach(sourceBreakdown) { source in
                            SavingGoalBreakdownSummaryRow(
                                title: source.title,
                                value: source.amount.formattedShekelAmount,
                                appLanguage: appLanguage
                            )
                        }
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "פירוט חסכונות", en: "Savings Breakdown"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct SavingGoalBreakdownSummaryRow: View {
    let title: String
    let value: String
    let appLanguage: AppLanguage

    var body: some View {
        HStack {
            if appLanguage == .he {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(title)
                    .foregroundStyle(.secondary)
            } else {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

private struct RecurringSavingRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let recurringSaving: RecurringSaving
    let goal: SavingGoal?

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 5) {
            Text("\(recurringSaving.amount.formattedShekelAmount) · \(appLanguage.text(he: "כל חודש", en: "Every month"))")
                .font(.headline)

            Text(goal?.name ?? appLanguage.text(he: "חסכון כללי", en: "General saving"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(recurringSaving.startDate.shortDateText(for: appLanguage))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
    }
}

private struct SavingGoalEditorView: View {
    @Environment(\.appLanguage) private var appLanguage

    let onSave: (SavingGoal) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var targetText = ""
    @State private var location: SavingLocation = .bank
    @State private var customLocation = ""
    @State private var errorMessage: String?

    private var parsedTarget: Decimal? {
        Decimal(string: targetText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (parsedTarget ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            Text(appLanguage.text(he: "יעד חסכון", en: "Saving Goal"))
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            TextField(appLanguage.text(he: "שם היעד", en: "Goal Name"), text: $name)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                Text(appLanguage.text(he: "סכום יעד", en: "Target Amount"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                AmountInputField(amountText: $targetText)
            }

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                Text(appLanguage.text(he: "איפה הכסף נמצא", en: "Where the money is held"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                Picker(appLanguage.text(he: "איפה הכסף נמצא", en: "Where the money is held"), selection: $location) {
                    ForEach(SavingLocation.allCases) { location in
                        Text(location.title(for: appLanguage)).tag(location)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if location == .other {
                TextField(appLanguage.text(he: "איפה הכסף נמצא", en: "Where the money is held"), text: $customLocation)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                    .font(.headline)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let target = parsedTarget, target > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום יעד תקין", en: "Enter a valid target amount")
                        return
                    }

                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else {
                        errorMessage = appLanguage.text(he: "צריך שם יעד", en: "Enter a goal name")
                        return
                    }

                    onSave(SavingGoal(
                        name: trimmedName,
                        targetAmount: target,
                        location: location,
                        customLocation: customLocation.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct RecurringSavingEditorView: View {
    @Environment(\.appLanguage) private var appLanguage

    let goals: [SavingGoal]
    let initialDate: Date
    let onSave: (RecurringSaving) -> Void
    let onCancel: () -> Void

    @State private var amountText = ""
    @State private var selectedGoalId: UUID?
    @State private var startDate: Date
    @State private var errorMessage: String?

    init(
        goals: [SavingGoal],
        initialDate: Date = Date(),
        onSave: @escaping (RecurringSaving) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.goals = goals
        self.initialDate = initialDate
        self.onSave = onSave
        self.onCancel = onCancel
        _startDate = State(initialValue: initialDate)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        (parsedAmount ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(appLanguage.text(he: "חסכון קבוע", en: "Recurring Saving"))
                .font(.title3.bold())

            AmountInputField(amountText: $amountText)

            Text(appLanguage.text(he: "כל חודש", en: "Every month"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if !goals.isEmpty {
                Picker(appLanguage.text(he: "יעד חסכון", en: "Saving Goal"), selection: selectedGoalBinding) {
                    Text(appLanguage.text(he: "חסכון כללי", en: "General saving")).tag(Optional<UUID>.none)

                    ForEach(goals) { goal in
                        Text(goal.name).tag(Optional(goal.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            DatePicker(appLanguage.text(he: "תאריך התחלה", en: "Start Date"), selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let amount = parsedAmount, amount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    onSave(RecurringSaving(
                        amount: amount,
                        goalId: selectedGoalId,
                        startDate: startDate
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            selectedGoalId = goals.first?.id
        }
    }

    private var selectedGoalBinding: Binding<UUID?> {
        Binding(
            get: { selectedGoalId },
            set: { selectedGoalId = $0 }
        )
    }
}

private struct SavingRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let saving: Saving
    var goal: SavingGoal?

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 5) {
            HStack {
                Text(saving.amount.formattedShekelAmount)
                    .font(.headline)
                    .foregroundStyle(saving.kind == .withdrawal ? .red : .primary)

                Spacer()

                Text(saving.locationDisplayText(for: appLanguage))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(saving.kind.title(for: appLanguage))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(saving.kind == .withdrawal ? .red : .secondary)

            Text(saving.date.shortDateText(for: appLanguage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let goal {
                Text(goal.name)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if !saving.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(saving.note)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .padding(.vertical, 4)
    }
}

private struct AddSavingView: View {
    @Environment(\.appLanguage) private var appLanguage

    let kind: SavingKind
    let availableBalance: Decimal
    var goals: [SavingGoal] = []
    var savings: [Saving] = []
    var initialDate = Date()
    var allowsRecurring = false
    let onSave: (Saving) -> Void
    var onSaveRecurring: ((RecurringSaving) -> Void)?
    let onCancel: () -> Void

    @State private var amountText = ""
    @State private var location: SavingLocation = .bank
    @State private var customLocation = ""
    @State private var date: Date
    @State private var note = ""
    @State private var selectedGoalId: UUID?
    @State private var selectedWithdrawalSourceKey: String?
    @State private var isRecurring = false
    @State private var errorMessage: String?

    init(
        kind: SavingKind,
        availableBalance: Decimal,
        goals: [SavingGoal] = [],
        savings: [Saving] = [],
        initialDate: Date = Date(),
        allowsRecurring: Bool = false,
        onSave: @escaping (Saving) -> Void,
        onSaveRecurring: ((RecurringSaving) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.kind = kind
        self.availableBalance = availableBalance
        self.goals = goals
        self.savings = savings
        self.initialDate = initialDate
        self.allowsRecurring = allowsRecurring
        self.onSave = onSave
        self.onSaveRecurring = onSaveRecurring
        self.onCancel = onCancel
        _date = State(initialValue: initialDate)
        _selectedGoalId = State(initialValue: kind == .withdrawal ? nil : goals.first?.id)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        guard let parsedAmount, parsedAmount > 0 else {
            return false
        }

        return kind == .deposit
            || (hasWithdrawalSources && selectedWithdrawalSourceKey != nil && selectedAvailableBalance > 0 && parsedAmount <= selectedAvailableBalance)
    }

    private var validationMessage: String? {
        guard kind == .withdrawal,
              let parsedAmount,
              parsedAmount > selectedAvailableBalance else {
            return nil
        }

        return appLanguage.text(
            he: "לא ניתן למשוך יותר מהסכום הזמין",
            en: "Cannot withdraw more than the available amount"
        )
    }

    private var availableLocationOptions: [SavingLocation] {
        guard kind == .withdrawal else {
            return SavingLocation.allCases
        }

        return SavingLocation.withdrawalOptions.filter { Saving.hasPositiveBalance(for: savings, location: $0) }
    }

    private var availableWithdrawalSourceOptions: [SavingSourceOption] {
        SavingSourceOption.options(
            from: savings,
            goalId: selectedGoalId,
            language: appLanguage
        )
    }

    private var availableGoals: [SavingGoal] {
        guard kind == .withdrawal else {
            return goals
        }

        return goals.filter { Saving.balance(for: savings, goalId: $0.id) > 0 }
    }

    private var hasWithdrawalSources: Bool {
        kind != .withdrawal || !availableWithdrawalSourceOptions.isEmpty
    }

    private var selectedAvailableBalance: Decimal {
        guard kind == .withdrawal else {
            return availableBalance
        }

        guard let selectedWithdrawalSourceKey,
              let option = availableWithdrawalSourceOptions.first(where: { $0.id == selectedWithdrawalSourceKey }) else {
            return 0
        }

        return option.amount
    }

    private var selectedWithdrawalSource: SavingSourceOption? {
        guard let selectedWithdrawalSourceKey else {
            return nil
        }

        return availableWithdrawalSourceOptions.first { $0.id == selectedWithdrawalSourceKey }
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(kind.formTitle(for: appLanguage))
                .font(.title3.bold())
                .foregroundStyle(kind == .withdrawal ? .red : .primary)

            if kind == .withdrawal && hasWithdrawalSources {
                Text(appLanguage.text(
                    he: "זמין למשיכה: \(selectedAvailableBalance.formattedShekelAmount)",
                    en: "Available to withdraw: \(selectedAvailableBalance.formattedShekelAmount)"
                ))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                Text(kind == .withdrawal
                    ? appLanguage.text(he: "סכום למשיכה", en: "Amount to withdraw")
                    : appLanguage.text(he: "כמה חסכון?", en: "Saving amount"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                AmountInputField(amountText: $amountText)
                    .onChange(of: amountText) {
                        errorMessage = validationMessage
                    }
            }

            if !hasWithdrawalSources {
                Text(appLanguage.text(he: "אין חסכונות זמינים למשיכה", en: "No savings available to withdraw"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            } else if kind == .withdrawal {
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                    Text(appLanguage.text(he: "מאיפה למשוך?", en: "Withdraw from"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                    Picker(appLanguage.text(he: "מאיפה למשוך?", en: "Withdraw from"), selection: selectedWithdrawalSourceBinding) {
                        ForEach(availableWithdrawalSourceOptions) { source in
                            Text(source.title).tag(Optional(source.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            } else {
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                    Text(appLanguage.text(he: "איפה החסכון?", en: "Where is the saving held?"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                    Picker(appLanguage.text(he: "איפה החסכון?", en: "Where is the saving held?"), selection: $location) {
                        ForEach(availableLocationOptions) { location in
                            Text(location.title(for: appLanguage)).tag(location)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if kind != .withdrawal && location == .other {
                TextField(appLanguage.text(he: "איפה החסכון?", en: "Where is the saving held?"), text: $customLocation)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                    .font(.headline)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if !goals.isEmpty && hasWithdrawalSources {
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                    Text(kind == .withdrawal
                        ? appLanguage.text(he: "יעד חסכון", en: "Saving Goal")
                        : appLanguage.text(he: "האם החסכון משויך ליעד?", en: "Is this saving linked to a goal?"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                    Picker(kind == .withdrawal
                        ? appLanguage.text(he: "יעד חסכון", en: "Saving Goal")
                        : appLanguage.text(he: "האם החסכון משויך ליעד?", en: "Is this saving linked to a goal?"), selection: selectedGoalBinding) {
                        if kind != .withdrawal || !availableGoals.isEmpty {
                            Text(kind == .withdrawal
                                ? appLanguage.text(he: "כללי", en: "General")
                                : appLanguage.text(he: "לא, חסכון כללי", en: "No, general saving")).tag(Optional<UUID>.none)
                        }

                        ForEach(availableGoals) { goal in
                            Text(goal.name).tag(Optional(goal.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if allowsRecurring && kind != .withdrawal {
                Picker(appLanguage.text(he: "סוג חסכון", en: "Saving type"), selection: $isRecurring) {
                    Text(appLanguage.text(he: "חד פעמי", en: "One-time")).tag(false)
                    Text(appLanguage.text(he: "חסכון קבוע", en: "Recurring Saving")).tag(true)
                }
                .pickerStyle(.segmented)
            }

            DatePicker(
                isRecurring
                    ? appLanguage.text(he: "תאריך התחלה", en: "Start Date")
                    : appLanguage.text(he: "תאריך ושעה", en: "Date and Time"),
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            TextField(appLanguage.text(he: "שם / הערה", en: "Name / note"), text: $note)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(errorMessage ?? validationMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(kind == .withdrawal
                    ? appLanguage.text(he: "משוך", en: "Withdraw")
                    : appLanguage.text(he: "הוסף", en: "Add")) {
                    guard let amount = parsedAmount, amount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    guard kind == .deposit || (selectedWithdrawalSource != nil && selectedAvailableBalance > 0) else {
                        errorMessage = appLanguage.text(he: "אין חסכונות זמינים למשיכה", en: "No savings available to withdraw")
                        return
                    }

                    guard kind == .deposit || amount <= selectedAvailableBalance else {
                        errorMessage = validationMessage
                        return
                    }

                    if isRecurring {
                        guard let onSaveRecurring else {
                            errorMessage = appLanguage.text(he: "לא ניתן לשמור חסכון קבוע כאן", en: "Recurring saving cannot be saved here")
                            return
                        }

                        onSaveRecurring(RecurringSaving(
                            amount: amount,
                            goalId: selectedGoalId,
                            startDate: date
                        ))
                        return
                    }

                    let sourceLocation = selectedWithdrawalSource?.location ?? location
                    let sourceCustomLocation = selectedWithdrawalSource?.customLocation ?? customLocation.trimmingCharacters(in: .whitespacesAndNewlines)
                    let savingGoalId = kind == .withdrawal ? selectedWithdrawalSource?.goalId : selectedGoalId

                    onSave(Saving(
                        amount: amount,
                        kind: kind,
                        location: sourceLocation,
                        customLocation: sourceCustomLocation,
                        date: date,
                        note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                        goalId: savingGoalId,
                        createdAt: Date()
                    ))
                }
                .buttonStyle(.borderedProminent)
                .tint(kind == .withdrawal ? .red : nil)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            normalizeWithdrawalSourceSelection()
        }
        .onChange(of: kind) {
            if kind == .withdrawal {
                isRecurring = false
            }
            normalizeWithdrawalSourceSelection()
        }
        .onChange(of: location) {
            errorMessage = validationMessage
        }
        .onChange(of: selectedGoalId) {
            selectedWithdrawalSourceKey = nil
            normalizeWithdrawalSourceSelection()
            errorMessage = validationMessage
        }
    }

    private var selectedGoalBinding: Binding<UUID?> {
        Binding(
            get: { selectedGoalId },
            set: { selectedGoalId = $0 }
        )
    }

    private var selectedWithdrawalSourceBinding: Binding<String?> {
        Binding(
            get: { selectedWithdrawalSourceKey },
            set: { selectedWithdrawalSourceKey = $0 }
        )
    }

    private func normalizeWithdrawalSourceSelection() {
        guard kind == .withdrawal else {
            return
        }

        if let selectedGoalId, Saving.balance(for: savings, goalId: selectedGoalId) <= 0 {
            self.selectedGoalId = nil
        }

        if let selectedWithdrawalSourceKey,
           availableWithdrawalSourceOptions.contains(where: { $0.id == selectedWithdrawalSourceKey }) {
            return
        }

        selectedWithdrawalSourceKey = availableWithdrawalSourceOptions.first?.id

        if selectedWithdrawalSourceKey == nil,
           let firstGoal = availableGoals.first {
            selectedGoalId = firstGoal.id
            selectedWithdrawalSourceKey = availableWithdrawalSourceOptions.first?.id
        }
    }
}

private struct DebtsManagementView: View {
    @Environment(\.appLanguage) private var appLanguage

    let onClose: () -> Void

    @State private var debts: [Debt] = []
    @State private var isAddDebtPresented = false
    @State private var isDebtDirectionChooserPresented = false
    @State private var selectedDirection: DebtDirection = .owedToMe

    private var visibleDebts: [Debt] {
        debts.filter { $0.direction == selectedDirection }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(appLanguage.text(he: "סוג חוב", en: "Debt type"), selection: $selectedDirection) {
                        Text(DebtDirection.owedToMe.title(for: appLanguage)).tag(DebtDirection.owedToMe)
                        Text(DebtDirection.iOwe.title(for: appLanguage)).tag(DebtDirection.iOwe)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if visibleDebts.isEmpty {
                        Text(appLanguage.text(he: "אין חובות עדיין", en: "No debts yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleDebts) { debt in
                            DebtRow(
                                debt: debt,
                                onUpdateRepaidAmount: { repaidAmount in
                                    updateRepaidAmount(for: debt, repaidAmount: repaidAmount)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "חובות", en: "Debts"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isDebtDirectionChooserPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(appLanguage.text(he: "הוסף חוב", en: "Add debt"))
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            debts = Storage.loadDebts()
        }
        .sheet(isPresented: $isDebtDirectionChooserPresented) {
            DebtDirectionChooserView(
                onSelect: { direction in
                    selectedDirection = direction
                    isDebtDirectionChooserPresented = false
                    isAddDebtPresented = true
                },
                onCancel: {
                    isDebtDirectionChooserPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $isAddDebtPresented) {
            AddDebtView(
                direction: selectedDirection,
                onSave: addDebt,
                onCancel: {
                    isAddDebtPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(560)])
        }
    }

    private func addDebt(_ debt: Debt) {
        debts.append(debt)
        debts.sort { $0.date > $1.date }
        Storage.saveDebts(debts)
        isAddDebtPresented = false
    }

    private func updateRepaidAmount(for debt: Debt, repaidAmount: Decimal) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else {
            return
        }

        debts[index] = debt.updatedRepaidAmount(repaidAmount)
        Storage.saveDebts(debts)
    }
}

private struct DebtDirectionChooserView: View {
    @Environment(\.appLanguage) private var appLanguage

    let onSelect: (DebtDirection) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(appLanguage.text(he: "איזה חוב להוסיף?", en: "Which debt should be added?"))
                .font(.title3.bold())

            VStack(spacing: 10) {
                Button {
                    onSelect(.iOwe)
                } label: {
                    Label(DebtDirection.iOwe.title(for: appLanguage), systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    onSelect(.owedToMe)
                } label: {
                    Label(DebtDirection.owedToMe.title(for: appLanguage), systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }

            Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                onCancel()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct DebtRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let debt: Debt
    let onUpdateRepaidAmount: (Decimal) -> Void

    @State private var isRepaymentSheetPresented = false

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
            Text(debt.naturalSentence(for: appLanguage))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(appLanguage.textAlignment)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .strikethrough(debt.isFullyRepaid)

            Text(debt.repaidLine(for: appLanguage))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(appLanguage.textAlignment)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .strikethrough(debt.isFullyRepaid)

            ProgressView(value: debt.repaymentProgress)
                .tint(debt.isFullyRepaid ? .green : .accentColor)

            Text(debt.percentageLine(for: appLanguage))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(appLanguage.textAlignment)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .strikethrough(debt.isFullyRepaid)

            Text(appLanguage.text(
                he: "נותר: \(debt.remainingAmount.formattedShekelAmount)",
                en: "Remaining: \(debt.remainingAmount.formattedShekelAmount)"
            ))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(appLanguage.textAlignment)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .strikethrough(debt.isFullyRepaid)

            Text("\(debt.date.shortDateText(for: appLanguage)) · \(debt.statusText(for: appLanguage))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(appLanguage.textAlignment)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .strikethrough(debt.isFullyRepaid)

            Button(debt.repaidAmount > 0
                ? appLanguage.text(he: "עדכן החזר", en: "Update repayment")
                : debt.repaymentButtonTitle(for: appLanguage)) {
                isRepaymentSheetPresented = true
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .padding(.vertical, 4)
        .foregroundStyle(debt.isFullyRepaid ? .green : .primary)
        .opacity(debt.isFullyRepaid ? 0.75 : 1)
        .sheet(isPresented: $isRepaymentSheetPresented) {
            DebtRepaymentView(
                debt: debt,
                onSave: { repaidAmount in
                    onUpdateRepaidAmount(repaidAmount)
                    isRepaymentSheetPresented = false
                },
                onCancel: {
                    isRepaymentSheetPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(310)])
        }
    }
}

private struct AddDebtView: View {
    @Environment(\.appLanguage) private var appLanguage

    let direction: DebtDirection
    var initialDate = Date()
    let onSave: (Debt) -> Void
    let onCancel: () -> Void

    @State private var personName = ""
    @State private var amountText = ""
    @State private var reason = ""
    @State private var date: Date
    @State private var errorMessage: String?

    init(
        direction: DebtDirection,
        initialDate: Date = Date(),
        onSave: @escaping (Debt) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.direction = direction
        self.initialDate = initialDate
        self.onSave = onSave
        self.onCancel = onCancel
        _date = State(initialValue: initialDate)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var personLabel: String {
        direction == .owedToMe
            ? appLanguage.text(he: "מי חייב לך?", en: "Who owes you?")
            : appLanguage.text(he: "למי אתה חייב?", en: "Who do you owe?")
    }

    private var canSave: Bool {
        !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(direction == .owedToMe
                ? appLanguage.text(he: "הוסף חוב שחייבים לך", en: "Add Debt Owed to You")
                : appLanguage.text(he: "הוסף חוב שאתה חייב", en: "Add Debt You Owe"))
                .font(.title3.bold())

            TextField(personLabel, text: $personName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: personName) {
                    errorMessage = nil
                }

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                Text(appLanguage.text(he: "כמה?", en: "How much?"))
                    .font(.subheadline.weight(.semibold))

                AmountInputField(amountText: $amountText)
                    .onChange(of: amountText) {
                        errorMessage = nil
                    }
            }

            TextField(appLanguage.text(he: "על מה?", en: "What for?"), text: $reason)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: reason) {
                    errorMessage = nil
                }

            DatePicker(appLanguage.text(he: "תאריך ושעה", en: "Date and Time"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "הוסף", en: "Add")) {
                    guard let amount = parsedAmount, amount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    let trimmedPerson = personName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !trimmedPerson.isEmpty else {
                        errorMessage = appLanguage.text(he: "צריך למלא למי החוב", en: "Enter who the debt is for")
                        return
                    }

                    onSave(Debt(
                        direction: direction,
                        personName: trimmedPerson,
                        originalAmount: amount,
                        repaidAmount: 0,
                        reason: trimmedReason,
                        date: date,
                        returnedAt: nil,
                        createdAt: Date()
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct DebtRepaymentView: View {
    @Environment(\.appLanguage) private var appLanguage

    let debt: Debt
    let onSave: (Decimal) -> Void
    let onCancel: () -> Void

    @State private var amountText: String
    @State private var errorMessage: String?
    @State private var isConfirmationPresented = false

    init(debt: Debt, onSave: @escaping (Decimal) -> Void, onCancel: @escaping () -> Void) {
        self.debt = debt
        self.onSave = onSave
        self.onCancel = onCancel
        _amountText = State(initialValue: debt.repaidAmount > 0 ? debt.repaidAmount.plainString : "")
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var maxAmount: Decimal {
        debt.originalAmount
    }

    private var canSave: Bool {
        guard let parsedAmount else {
            return false
        }

        return parsedAmount >= 0 && parsedAmount <= maxAmount
    }

    private var confirmationText: String {
        let amount = (parsedAmount ?? 0).formattedShekelAmount
        return debt.direction == .owedToMe
            ? appLanguage.text(he: "האם התקבל החזר של \(amount)?", en: "Was \(amount) received?")
            : appLanguage.text(he: "האם שילמת החזר של \(amount)?", en: "Did you repay \(amount)?")
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(debt.repaidAmount > 0
                ? appLanguage.text(he: "עדכן החזר", en: "Update repayment")
                : debt.repaymentButtonTitle(for: appLanguage))
                .font(.title3.bold())

            Text(appLanguage.text(he: "אפשר להזין החזר מלא או חלקי", en: "You can enter a full or partial repayment"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            AmountInputField(amountText: $amountText)
                .onChange(of: amountText) {
                    errorMessage = nil
                }

            Text(appLanguage.text(
                he: "סכום החוב המקורי: \(debt.originalAmount.formattedShekelAmount)",
                en: "Original debt amount: \(debt.originalAmount.formattedShekelAmount)"
            ))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            Button(debt.direction == .owedToMe
                ? appLanguage.text(he: "הוחזר במלואו", en: "Fully Repaid")
                : appLanguage.text(he: "שולם במלואו", en: "Fully Paid")) {
                amountText = maxAmount.plainString
                errorMessage = nil
                isConfirmationPresented = true
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let parsedAmount, parsedAmount >= 0 else {
                        errorMessage = appLanguage.text(he: "הסכום חייב להיות גדול מ־0", en: "Amount must be greater than 0")
                        return
                    }

                    guard parsedAmount <= maxAmount else {
                        errorMessage = appLanguage.text(
                            he: "סכום ההחזר לא יכול להיות גדול מסכום החוב",
                            en: "Repayment amount cannot exceed the debt amount"
                        )
                        return
                    }

                    isConfirmationPresented = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .confirmationDialog(confirmationText, isPresented: $isConfirmationPresented, titleVisibility: .visible) {
            Button(appLanguage.text(he: "אישור", en: "Confirm")) {
                onSave(parsedAmount ?? 0)
            }

            Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {}
        }
    }
}

private struct AmountInputField: View {
    @Environment(\.appLanguage) private var appLanguage
    @FocusState private var isFocused: Bool

    @Binding var amountText: String
    var selectedCurrency: Binding<CurrencyOption>?
    var onCurrencyButtonTapped: (() -> Void)?
    var placeholder: String?
    var height: CGFloat = 52

    init(
        amountText: Binding<String>,
        selectedCurrency: Binding<CurrencyOption>? = nil,
        onCurrencyButtonTapped: (() -> Void)? = nil,
        placeholder: String? = nil,
        height: CGFloat = 52
    ) {
        _amountText = amountText
        self.selectedCurrency = selectedCurrency
        self.onCurrencyButtonTapped = onCurrencyButtonTapped
        self.placeholder = placeholder
        self.height = height
    }

    private var shouldShowPlaceholder: Bool {
        amountText.isEmpty && !isFocused
    }

    private var usesCurrencySelector: Bool {
        selectedCurrency != nil
    }

    var body: some View {
        ZStack {
            if shouldShowPlaceholder && !usesCurrencySelector {
                Text(placeholder ?? appLanguage.text(he: "סכום", en: "Amount"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            HStack(spacing: 6) {
                if appLanguage == .he {
                    amountTextField
                    currencyAccessory
                } else {
                    currencyAccessory
                    amountTextField
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .opacity(shouldShowPlaceholder && !usesCurrencySelector ? 0 : 1)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            isFocused = true
        }
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .task {
            if selectedCurrency != nil {
                await CurrencyExchangeService.refreshIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var currencyAccessory: some View {
        if let selectedCurrency {
            Button {
                onCurrencyButtonTapped?()
            } label: {
                Text(selectedCurrency.wrappedValue.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLanguage.text(he: "בחר מטבע", en: "Choose currency"))
        } else {
            Text(Storage.loadCurrency().symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(shouldShowPlaceholder ? 0 : 1)
        }
    }

    private var amountTextField: some View {
        TextField(textFieldPlaceholder, text: $amountText)
            .keyboardType(.decimalPad)
            .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .leftToRight)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.primary)
            .tint(.accentColor)
            .focused($isFocused)
            .frame(minWidth: 34, idealWidth: textFieldWidth, maxWidth: textFieldWidth)
            .onChange(of: amountText) { _, newValue in
                let sanitized = sanitizeAmountInput(newValue)

                if sanitized != newValue {
                    amountText = sanitized
                }
            }
    }

    private var textFieldPlaceholder: String {
        usesCurrencySelector ? (placeholder ?? appLanguage.text(he: "סכום", en: "Amount")) : ""
    }

    private var textFieldWidth: CGFloat {
        if usesCurrencySelector && amountText.isEmpty {
            return 112
        }

        let characterCount = max(amountText.count, 1)
        return min(142, max(34, CGFloat(characterCount) * 12 + 24))
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

private enum TemporaryCurrencyUsageMode: String, CaseIterable, Identifiable {
    case currentExpense
    case dateRange

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .currentExpense:
            language.text(he: "להוצאה זו בלבד", en: "This expense only")
        case .dateRange:
            language.text(he: "טווח תאריכים", en: "Date range")
        }
    }
}

private struct TemporaryCurrencySheet: View {
    @Environment(\.appLanguage) private var appLanguage

    let selectedCurrency: CurrencyOption
    let primaryCurrency: CurrencyOption
    let onSelectCurrentExpense: (CurrencyOption) -> Void
    let onSelectDateRange: (CurrencyOption, Date, Date) -> Void
    let onClose: () -> Void

    @State private var draftCurrency: CurrencyOption?
    @State private var isCurrencyPickerExpanded = false
    @State private var usageMode: TemporaryCurrencyUsageMode = .currentExpense
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    init(
        selectedCurrency: CurrencyOption,
        primaryCurrency: CurrencyOption,
        onSelectCurrentExpense: @escaping (CurrencyOption) -> Void,
        onSelectDateRange: @escaping (CurrencyOption, Date, Date) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.selectedCurrency = selectedCurrency
        self.primaryCurrency = primaryCurrency
        self.onSelectCurrentExpense = onSelectCurrentExpense
        self.onSelectDateRange = onSelectDateRange
        self.onClose = onClose
        _draftCurrency = State(initialValue: selectedCurrency == primaryCurrency ? nil : selectedCurrency)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 18) {
                    Text(appLanguage.text(he: "מטבע זמני", en: "Temporary Currency"))
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .center)

                    currencySelectionView

                    if isCurrencyPickerExpanded {
                        currencyPickerView
                    }

                    exchangeRateView

                    VStack(alignment: appLanguage.horizontalAlignment, spacing: 12) {
                        Text(appLanguage.text(he: "משך שימוש", en: "Usage Mode"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                        Picker(appLanguage.text(he: "משך שימוש", en: "Usage Mode"), selection: $usageMode) {
                            ForEach(TemporaryCurrencyUsageMode.allCases) { mode in
                                Text(mode.title(for: appLanguage)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if usageMode == .dateRange {
                            VStack(alignment: appLanguage.horizontalAlignment, spacing: 10) {
                                DatePicker(appLanguage.text(he: "מתאריך", en: "Start Date"), selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)

                                DatePicker(appLanguage.text(he: "עד תאריך", en: "End Date"), selection: $endDate, in: startDate..., displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                            .padding(12)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button {
                            guard let draftCurrency else {
                                isCurrencyPickerExpanded = true
                                return
                            }

                            if usageMode == .currentExpense {
                                onSelectCurrentExpense(draftCurrency)
                            } else {
                                onSelectDateRange(draftCurrency, startDate, endDate)
                            }
                        } label: {
                            Text(primaryActionTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(draftCurrency == nil)
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(appLanguage.text(
                        he: "המטבע הראשי נשאר \(primaryCurrency.code). המטבע הזמני חל רק על הוצאות ממסך הבית.",
                        en: "Your primary currency remains \(primaryCurrency.code). The temporary currency applies only to Home-screen expenses."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .navigationTitle(appLanguage.text(he: "בחר מטבע", en: "Choose Currency"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
    }

    private var availableTemporaryCurrencies: [CurrencyOption] {
        CurrencyOption.allCases.filter { $0 != primaryCurrency }
    }

    private var primaryActionTitle: String {
        switch usageMode {
        case .currentExpense:
            appLanguage.text(he: "השתמש להוצאה זו", en: "Use for This Expense")
        case .dateRange:
            appLanguage.text(he: "הפעל לטווח", en: "Apply Range")
        }
    }

    private var currencySelectionView: some View {
        HStack(spacing: 10) {
            if appLanguage == .he {
                temporaryCurrencyField
                Image(systemName: "arrow.left")
                    .foregroundStyle(.secondary)
                currencySummaryBox(
                    title: appLanguage.text(he: "מטבע ראשי", en: "Primary Currency"),
                    currency: primaryCurrency
                )
            } else {
                currencySummaryBox(
                    title: appLanguage.text(he: "מטבע ראשי", en: "Primary Currency"),
                    currency: primaryCurrency
                )
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                temporaryCurrencyField
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var temporaryCurrencyField: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isCurrencyPickerExpanded.toggle()
            }
        } label: {
            VStack(spacing: 6) {
                Text(appLanguage.text(he: "מטבע זמני", en: "Temporary Currency"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if let draftCurrency {
                        Text(draftCurrency.symbol)
                            .font(.headline.weight(.bold))
                        Text(draftCurrency.code)
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text(appLanguage.text(he: "בחר מטבע", en: "Select Currency"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func currencySummaryBox(title: String, currency: CurrencyOption) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(currency.symbol)
                    .font(.headline.weight(.bold))
                Text(currency.code)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var currencyPickerView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(availableTemporaryCurrencies) { currency in
                    Button {
                        draftCurrency = currency
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isCurrencyPickerExpanded = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(currency.symbol)
                                .font(.headline.weight(.bold))
                                .frame(width: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(currency.code)
                                    .font(.subheadline.weight(.bold))
                                Text(currency.title(for: appLanguage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if draftCurrency == currency {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if currency.id != availableTemporaryCurrencies.last?.id {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
        }
        .frame(maxHeight: 210)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.layoutDirection, .leftToRight)
    }

    private var exchangeRateView: some View {
        VStack(spacing: 6) {
            Text(appLanguage.text(he: "שער המרה", en: "Exchange Rate"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let draftCurrency {
                Text("\(primaryCurrency.code) → \(draftCurrency.code)")
                    .font(.subheadline.weight(.bold))

                if let conversion = CurrencyExchangeService.convert(amount: 1, from: draftCurrency, to: primaryCurrency) {
                    Text("1 \(draftCurrency.code) = \(conversion.convertedAmount.plainString) \(primaryCurrency.code)")
                        .font(.headline)
                } else {
                    Text(appLanguage.text(he: "שער לא זמין", en: "Exchange rate unavailable"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(appLanguage.text(he: "לא נבחר מטבע זמני", en: "No temporary currency selected"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .environment(\.layoutDirection, .leftToRight)
    }
}

private struct ManageRecurringExpensesView: View {
    @Environment(\.appLanguage) private var appLanguage

    @Binding var categories: [ExpenseCategory]
    @Binding var recurringExpenses: [RecurringExpense]
    let onPersist: () -> Void
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var selectedCategoryGroup: RecurringExpenseCategoryGroup?
    @State private var expenseBeingEdited: RecurringExpense?
    @State private var isAddRecurringPresented = false
    @State private var recurringSavings: [RecurringSaving] = []
    @State private var savingGoals: [SavingGoal] = []

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
                    TextField(appLanguage.text(he: "חיפוש לפי שם פעולה חוזרת", en: "Search recurring item name"), text: $searchText)
                        .keyboardType(.default)
                        .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                }

                if !searchResults.isEmpty {
                    Section(appLanguage.text(he: "תוצאות חיפוש", en: "Search Results")) {
                        ForEach(searchResults) { expense in
                            VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
                                highlightedExpenseName(expense.name)
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    CategoryIconView(
                                        systemImageName: groupCategory(for: expense)?.systemImageName ?? CategoryAppearanceOption.defaultSystemImageName,
                                        tint: (groupCategory(for: expense)?.tintName ?? CategoryAppearanceOption.defaultTintName).categoryTint,
                                        size: 16
                                    )

                                    Text("\(expense.displayCategoryName(for: appLanguage)) - \(expense.name) - \(expense.amount.formattedShekelAmount)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        }
                    }
                }

                Section(appLanguage.text(he: "הוצאות חוזרות", en: "Recurring Expenses")) {
                    if categoryGroups.isEmpty {
                        Text(appLanguage.text(he: "אין הוצאות חוזרות עדיין", en: "No recurring expenses yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(categoryGroups) { group in
                            RecurringCategoryGroupRow(group: group) {
                                selectedCategoryGroup = group
                            }
                        }
                    }
                }

                Section(appLanguage.text(he: "חסכונות חוזרים", en: "Recurring Savings")) {
                    if recurringSavings.isEmpty {
                        Text(appLanguage.text(he: "אין חסכונות קבועים עדיין", en: "No recurring savings yet"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recurringSavings) { recurringSaving in
                            RecurringSavingRow(
                                recurringSaving: recurringSaving,
                                goal: savingGoals.first { $0.id == recurringSaving.goalId }
                            )
                        }
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "פעולות חוזרות", en: "Recurring Items"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddRecurringPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(appLanguage.text(he: "הוסף הוצאה חוזרת", en: "Add Recurring Expense"))
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            recurringSavings = Storage.loadRecurringSavings()
            savingGoals = Storage.loadSavingGoals()
        }
        .sheet(isPresented: $isAddRecurringPresented) {
            RecurringExpenseModalView(
                categories: categories,
                onSave: saveNewRecurringExpense,
                onCancel: {
                    isAddRecurringPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(680)])
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
            .localizedPresentationEnvironment(appLanguage)
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
            .localizedPresentationEnvironment(appLanguage)
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
            return appLanguage.text(he: "צריך שם וסכום תקין", en: "Enter a valid name and amount")
        }

        guard let category = resolveRecurringCategory(
            existingCategoryId: existingCategoryId,
            newCategoryName: newCategoryName,
            newCategorySystemImageName: newCategorySystemImageName,
            newCategoryTintName: newCategoryTintName
        ) else {
            return appLanguage.text(he: "צריך לבחור או ליצור קטגוריה", en: "Choose or create a category")
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
            return appLanguage.text(he: "צריך שם הוצאה", en: "Enter an expense name")
        }

        guard amount > 0 else {
            return appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
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
    @Environment(\.appLanguage) private var appLanguage

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

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 5) {
                Text(group.displayName(for: appLanguage))
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
            .accessibilityLabel(appLanguage.text(he: "פירוט הוצאות חוזרות", en: "Recurring expense details"))
        }
        .padding(.vertical, 6)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
    }
}

private struct RecurringExpenseGroupDetailView: View {
    @Environment(\.appLanguage) private var appLanguage

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
                            VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
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

                        Text(group.displayName(for: appLanguage))
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "הוצאות חוזרות", en: "Recurring Expenses"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct CategoryMonthlyDetailsView: View {
    @Environment(\.appLanguage) private var appLanguage

    let category: ExpenseCategory
    @Binding var expenses: [Expense]
    let recurringExpenses: [RecurringExpense]
    let onClose: () -> Void
    let onPersist: () -> Void

    @State private var selectedMonth = Date()
    @State private var expenseBeingEdited: Expense?

    init(
        category: ExpenseCategory,
        expenses: Binding<[Expense]>,
        recurringExpenses: [RecurringExpense],
        onClose: @escaping () -> Void,
        onPersist: @escaping () -> Void
    ) {
        self.category = category
        _expenses = expenses
        self.recurringExpenses = recurringExpenses
        self.onClose = onClose
        self.onPersist = onPersist
    }

    private var filteredExpenses: [Expense] {
        expenses
            .filter { $0.categoryId == category.id }
            .filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private var monthTotal: Decimal {
        netExpenseTotal(for: filteredExpenses)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthNavigationView(selectedMonth: $selectedMonth)

                    MonthlyTargetSummaryView(
                        categoryName: category.displayName(for: appLanguage),
                        monthlyTarget: category.monthlyTarget,
                        spent: monthTotal,
                        selectedMonth: selectedMonth
                    )
                }

                Section(appLanguage.text(he: "הוצאות החודש", en: "This Month's Expenses")) {
                    if filteredExpenses.isEmpty {
                        Text(appLanguage.text(he: "אין הוצאות בחודש הזה", en: "No expenses this month"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredExpenses) { expense in
                            ExpenseEditableRow(
                                expense: expense,
                                onEdit: {
                                    expenseBeingEdited = expense
                                },
                                onDelete: {
                                    deleteExpense(expense)
                                }
                            )
                        }
                    }
                }

                if !recurringExpenses.isEmpty {
                    Section(appLanguage.text(he: "הוצאות חוזרות", en: "Recurring Expenses")) {
                        ForEach(recurringExpenses) { expense in
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.blue)
                                    .frame(width: 26)

                                VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
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
            .navigationTitle(category.displayName(for: appLanguage))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .sheet(item: $expenseBeingEdited) { expense in
            EditExpenseView(
                expense: expense,
                categories: [category],
                lockedMonth: selectedMonth,
                onSave: { updatedExpense in
                    updateExpense(updatedExpense)
                    expenseBeingEdited = nil
                },
                onCancel: {
                    expenseBeingEdited = nil
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(680)])
        }
    }

    private func updateExpense(_ updatedExpense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) else {
            return
        }

        expenses[index] = updatedExpense
        onPersist()
    }

    private func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        onPersist()
    }
}

private enum AnalyticsTab: String, CaseIterable, Identifiable {
    case overview
    case expenses
    case income
    case savings
    case debts

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .overview:
            language.text(he: "כללי", en: "Overview")
        case .expenses:
            language.text(he: "הוצאות", en: "Expenses")
        case .income:
            language.text(he: "הכנסות", en: "Income")
        case .savings:
            language.text(he: "חסכונות", en: "Savings")
        case .debts:
            language.text(he: "חובות", en: "Debts")
        }
    }
}

private enum AnalyticsCategoryChartKind: String, CaseIterable, Identifiable {
    case pie
    case bar

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .pie:
            language.text(he: "עוגה", en: "Pie")
        case .bar:
            language.text(he: "עמודות", en: "Bar")
        }
    }
}

private enum AnalyticsTrendRange: String, CaseIterable, Identifiable {
    case threeMonths
    case sixMonths
    case twelveMonths

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .threeMonths:
            language.text(he: "3 חודשים", en: "3M")
        case .sixMonths:
            language.text(he: "6 חודשים", en: "6M")
        case .twelveMonths:
            language.text(he: "12 חודשים", en: "12M")
        }
    }

    var monthCount: Int {
        switch self {
        case .threeMonths:
            3
        case .sixMonths:
            6
        case .twelveMonths:
            12
        }
    }
}

private struct AnalyticsCategoryBreakdown: Identifiable {
    let id: String
    let name: String
    let amount: Decimal
    let percentage: Decimal
    let color: Color
    let monthlyTarget: Decimal?
    let monthlyAverage: Decimal?

    var overBudgetAmount: Decimal {
        guard let monthlyTarget, monthlyTarget > 0, amount > monthlyTarget else {
            return 0
        }

        return amount - monthlyTarget
    }

    var targetCoveredAmount: Decimal {
        guard let monthlyTarget, monthlyTarget > 0 else {
            return amount
        }

        return min(amount, monthlyTarget)
    }

    var remainingTargetAmount: Decimal {
        guard let monthlyTarget, monthlyTarget > 0, amount < monthlyTarget else {
            return 0
        }

        return monthlyTarget - amount
    }

    var hasMonthlyTarget: Bool {
        guard let monthlyTarget else {
            return false
        }

        return monthlyTarget > 0
    }

    var targetStatus: CategoryMonthlyTargetStatus? {
        guard let monthlyTarget, monthlyTarget > 0 else {
            return nil
        }

        return CategoryMonthlyTargetStatus(targetAmount: monthlyTarget, spentAmount: amount)
    }

    var isOverBudget: Bool {
        overBudgetAmount > 0
    }
}

private struct MonthlyAnalyticsSnapshot: Identifiable, Codable {
    let id: String
    let month: Date
    let income: Decimal
    let expenses: Decimal
    let netSavings: Decimal
    let netBalance: Decimal
    let owedToMe: Decimal
    let iOwe: Decimal
    let repaidDebts: Decimal
    let expenseCount: Int
    let categoryTotals: [String: Decimal]
    let categoryNames: [String: String]
    let sourceSignature: String
    let updatedAt: Date

    var openDebt: Decimal {
        owedToMe + iOwe
    }
}

private struct AnalyticsMonthlyAverages {
    let expenses: Decimal
    let income: Decimal
    let netSavings: Decimal
    let openDebt: Decimal
    let cashFlow: Decimal

    init(metrics: [AnalyticsMonthMetrics]) {
        guard !metrics.isEmpty else {
            expenses = 0
            income = 0
            netSavings = 0
            openDebt = 0
            cashFlow = 0
            return
        }

        let monthCount = Decimal(metrics.count)
        expenses = metrics.reduce(Decimal(0)) { $0 + $1.expenses } / monthCount
        income = metrics.reduce(Decimal(0)) { $0 + $1.income } / monthCount
        netSavings = metrics.reduce(Decimal(0)) { $0 + $1.netSavings } / monthCount
        openDebt = metrics.reduce(Decimal(0)) { $0 + $1.openDebt } / monthCount
        cashFlow = metrics.reduce(Decimal(0)) { $0 + $1.netBalance } / monthCount
    }
}

private struct AnalyticsMonthMetrics: Identifiable {
    let month: Date
    let income: Decimal
    let expenses: Decimal
    let netSavings: Decimal
    let netBalance: Decimal
    let owedToMe: Decimal
    let iOwe: Decimal
    let repaidDebts: Decimal
    let expenseCount: Int
    let savingsBalance: Decimal
    let savingsGoal: Decimal?
    let expenseGoal: Decimal?
    let categoryBreakdown: [AnalyticsCategoryBreakdown]
    let topExpenseCategoryName: String?
    let topExpenseCategoryAmount: Decimal

    var id: Date {
        month
    }

    var openDebt: Decimal {
        owedToMe + iOwe
    }
}

private struct AnalyticsView: View {
    @Environment(\.appLanguage) private var appLanguage

    let categories: [ExpenseCategory]
    let expenses: [Expense]
    let salaryEntries: [SalaryEntry]
    let savings: [Saving]
    let debts: [Debt]
    let onClose: () -> Void

    @State private var selectedMonth = Date()
    @State private var selectedTab: AnalyticsTab = .overview
    @State private var categoryChartKind: AnalyticsCategoryChartKind = .pie
    @State private var trendRange: AnalyticsTrendRange = .sixMonths

    private var selectedMetrics: AnalyticsMonthMetrics {
        metrics(for: selectedMonth)
    }

    private var trendMetrics: [AnalyticsMonthMetrics] {
        let month = startOfMonth(selectedMonth)
        return (0..<trendRange.monthCount)
            .reversed()
            .compactMap { Calendar.current.date(byAdding: .month, value: -$0, to: month) }
            .map { metrics(for: $0) }
    }

    private var trendAverages: AnalyticsMonthlyAverages {
        AnalyticsMonthlyAverages(metrics: trendMetrics)
    }

    private var trendCategoryAverages: [String: Decimal] {
        categoryAverages(from: trendMetrics)
    }

    private var recentSixMonthMetrics: [AnalyticsMonthMetrics] {
        let month = startOfMonth(selectedMonth)
        return (0..<6)
            .reversed()
            .compactMap { Calendar.current.date(byAdding: .month, value: -$0, to: month) }
            .map { metrics(for: $0) }
    }

    private var recentSixMonthAverages: AnalyticsMonthlyAverages {
        AnalyticsMonthlyAverages(metrics: recentSixMonthMetrics)
    }

    private var recentSixMonthCategoryAverages: [String: Decimal] {
        categoryAverages(from: recentSixMonthMetrics)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 18) {
                    MonthNavigationView(selectedMonth: $selectedMonth)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Picker(appLanguage.text(he: "סוג ניתוח", en: "Analysis type"), selection: $selectedTab) {
                        ForEach(AnalyticsTab.allCases) { tab in
                            Text(tab.title(for: appLanguage)).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    tabContent
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .navigationTitle(appLanguage.text(he: "ניתוח נתונים", en: "Analytics"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .expenses:
            expensesContent
        case .income:
            incomeContent
        case .savings:
            savingsContent
        case .debts:
            debtsContent
        }
    }

    private var overviewContent: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 18) {
            analyticsCards(for: selectedMetrics, averages: trendAverages)

            AnalyticsGoalProgressView(
                title: appLanguage.text(he: "חיסכון חודשי", en: "Monthly Savings"),
                current: selectedMetrics.netSavings,
                goal: selectedMetrics.savingsGoal,
                emptyText: appLanguage.text(he: "ללא יעד", en: "No Target"),
                progressText: { current, goal, percent in
                    appLanguage.text(
                        he: "נחסך \(current.formattedShekelAmount) מתוך \(goal.formattedShekelAmount) (\(percent.formattedPercentText))",
                        en: "Saved \(current.formattedShekelAmount) out of \(goal.formattedShekelAmount) (\(percent.formattedPercentText))"
                    )
                },
                warningText: nil,
                tint: .blue,
                appLanguage: appLanguage
            )

            AnalyticsGoalProgressView(
                title: appLanguage.text(he: "יעד הוצאות חודשי", en: "Monthly Expense Goal"),
                current: selectedMetrics.expenses,
                goal: selectedMetrics.expenseGoal,
                emptyText: appLanguage.text(he: "ללא יעד", en: "No Target"),
                progressText: { current, goal, percent in
                    appLanguage.text(
                        he: "הוצאת \(current.formattedShekelAmount) מתוך \(goal.formattedShekelAmount) (\(percent.formattedPercentText))",
                        en: "Spent \(current.formattedShekelAmount) out of \(goal.formattedShekelAmount) (\(percent.formattedPercentText))"
                    )
                },
                warningText: selectedMetrics.expenseGoal != nil && selectedMetrics.expenses > (selectedMetrics.expenseGoal ?? 0)
                    ? appLanguage.text(he: "חריגה מהיעד", en: "Over monthly goal")
                    : nil,
                tint: selectedMetrics.expenseGoal != nil && selectedMetrics.expenses > (selectedMetrics.expenseGoal ?? 0) ? .orange : .green,
                appLanguage: appLanguage
            )

            AnalyticsCategoryGraphView(
                breakdown: categoryBreakdown(selectedMetrics.categoryBreakdown, applying: trendCategoryAverages),
                chartKind: $categoryChartKind,
                appLanguage: appLanguage
            )

            AnalyticsCategoryRankingView(
                breakdown: categoryBreakdown(selectedMetrics.categoryBreakdown, applying: trendCategoryAverages),
                appLanguage: appLanguage
            )

            AnalyticsComparisonChart(
                metrics: selectedMetrics,
                appLanguage: appLanguage
            )

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 12) {
                Picker(appLanguage.text(he: "טווח", en: "Range"), selection: $trendRange) {
                    ForEach(AnalyticsTrendRange.allCases) { range in
                        Text(range.title(for: appLanguage)).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                AnalyticsTrendChart(metrics: trendMetrics, appLanguage: appLanguage)
            }
        }
    }

    private var expensesContent: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            AnalyticsSummaryCard(
                title: appLanguage.text(he: "הוצאות החודש", en: "Monthly expenses"),
                value: selectedMetrics.expenses.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "\(selectedMetrics.expenseCount) פעולות · ממוצע חודשי: \(recentSixMonthAverages.expenses.formattedShekelAmount)",
                    en: "\(selectedMetrics.expenseCount) entries · Monthly average: \(recentSixMonthAverages.expenses.formattedShekelAmount)"
                ),
                systemImageName: "cart.fill",
                tint: .red,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "קטגוריה מובילה", en: "Top category"),
                value: selectedMetrics.topExpenseCategoryName ?? appLanguage.text(he: "אין נתונים", en: "No data"),
                subtitle: selectedMetrics.topExpenseCategoryName == nil ? nil : selectedMetrics.topExpenseCategoryAmount.formattedShekelAmount,
                systemImageName: "square.grid.2x2.fill",
                tint: .orange,
                appLanguage: appLanguage
            )

            AnalyticsGoalProgressView(
                title: appLanguage.text(he: "יעד הוצאות חודשי", en: "Monthly Expense Goal"),
                current: selectedMetrics.expenses,
                goal: selectedMetrics.expenseGoal,
                emptyText: appLanguage.text(he: "ללא יעד", en: "No Target"),
                progressText: { current, goal, percent in
                    appLanguage.text(
                        he: "הוצאת \(current.formattedShekelAmount) מתוך \(goal.formattedShekelAmount) (\(percent.formattedPercentText))",
                        en: "Spent \(current.formattedShekelAmount) out of \(goal.formattedShekelAmount) (\(percent.formattedPercentText))"
                    )
                },
                warningText: selectedMetrics.expenseGoal != nil && selectedMetrics.expenses > (selectedMetrics.expenseGoal ?? 0)
                    ? appLanguage.text(he: "חריגה מהיעד", en: "Over monthly goal")
                    : nil,
                tint: selectedMetrics.expenseGoal != nil && selectedMetrics.expenses > (selectedMetrics.expenseGoal ?? 0) ? .orange : .green,
                appLanguage: appLanguage
            )

            AnalyticsCategoryGraphView(
                breakdown: categoryBreakdown(selectedMetrics.categoryBreakdown, applying: recentSixMonthCategoryAverages),
                chartKind: $categoryChartKind,
                appLanguage: appLanguage
            )

            AnalyticsCategoryRankingView(
                breakdown: categoryBreakdown(selectedMetrics.categoryBreakdown, applying: recentSixMonthCategoryAverages),
                appLanguage: appLanguage
            )
        }
    }

    private var incomeContent: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            AnalyticsSummaryCard(
                title: appLanguage.text(he: "הכנסות החודש", en: "Monthly Income"),
                value: selectedMetrics.income.formattedShekelAmount,
                subtitle: monthlyAverageText(for: recentSixMonthAverages.income),
                systemImageName: "arrow.down.circle.fill",
                tint: .green,
                appLanguage: appLanguage
            )

            AnalyticsTrendChart(metrics: recentSixMonthMetrics, appLanguage: appLanguage)
        }
    }

    private var savingsContent: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            AnalyticsSummaryCard(
                title: appLanguage.text(he: "סך החיסכון", en: "Total Savings"),
                value: selectedMetrics.savingsBalance.formattedShekelAmount,
                subtitle: monthlyAverageText(for: recentSixMonthAverages.netSavings),
                systemImageName: "banknote.fill",
                tint: .blue,
                appLanguage: appLanguage
            )

            AnalyticsGoalProgressView(
                title: appLanguage.text(he: "חיסכון חודשי", en: "Monthly Savings"),
                current: selectedMetrics.netSavings,
                goal: selectedMetrics.savingsGoal,
                emptyText: appLanguage.text(he: "ללא יעד", en: "No Target"),
                progressText: { current, goal, percent in
                    appLanguage.text(
                        he: "נחסך \(current.formattedShekelAmount) מתוך \(goal.formattedShekelAmount) (\(percent.formattedPercentText))",
                        en: "Saved \(current.formattedShekelAmount) out of \(goal.formattedShekelAmount) (\(percent.formattedPercentText))"
                    )
                },
                warningText: nil,
                tint: .blue,
                appLanguage: appLanguage
            )
        }
    }

    private var debtsContent: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            AnalyticsSummaryCard(
                title: appLanguage.text(he: "חייבים לי", en: "Owed to me"),
                value: selectedMetrics.owedToMe.formattedShekelAmount,
                subtitle: monthlyAverageText(for: recentSixMonthAverages.openDebt),
                systemImageName: "person.crop.circle.badge.plus",
                tint: .purple,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "אני חייב", en: "I owe"),
                value: selectedMetrics.iOwe.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "ממוצע חובות פתוחים חודשי: \(recentSixMonthAverages.openDebt.formattedShekelAmount)",
                    en: "Average monthly open debt: \(recentSixMonthAverages.openDebt.formattedShekelAmount)"
                ),
                systemImageName: "person.crop.circle.badge.exclamationmark",
                tint: .pink,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "הוחזר החודש", en: "Repaid this month"),
                value: selectedMetrics.repaidDebts.formattedShekelAmount,
                subtitle: nil,
                systemImageName: "checkmark.circle.fill",
                tint: .green,
                appLanguage: appLanguage
            )
        }
    }

    private func analyticsCards(for metrics: AnalyticsMonthMetrics, averages: AnalyticsMonthlyAverages) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            AnalyticsSummaryCard(
                title: appLanguage.text(he: "סך הוצאות", en: "Total Expenses"),
                value: metrics.expenses.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "ממוצע הוצאות חודשי: \(averages.expenses.formattedShekelAmount)",
                    en: "Average monthly expenses: \(averages.expenses.formattedShekelAmount)"
                ),
                systemImageName: "cart.fill",
                tint: .red,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "הכנסות החודש", en: "Monthly Income"),
                value: metrics.income.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "ממוצע הכנסות חודשי: \(averages.income.formattedShekelAmount)",
                    en: "Average monthly income: \(averages.income.formattedShekelAmount)"
                ),
                systemImageName: "arrow.down.circle.fill",
                tint: .green,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "סך החיסכון", en: "Total Savings"),
                value: metrics.savingsBalance.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "ממוצע חיסכון חודשי: \(averages.netSavings.formattedShekelAmount)",
                    en: "Average monthly savings: \(averages.netSavings.formattedShekelAmount)"
                ),
                systemImageName: "banknote.fill",
                tint: .blue,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "תזרים חודשי", en: "Monthly Cash Flow"),
                value: metrics.netBalance.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "ממוצע תזרים חודשי: \(averages.cashFlow.formattedShekelAmount)",
                    en: "Average monthly cash flow: \(averages.cashFlow.formattedShekelAmount)"
                ),
                systemImageName: metrics.netBalance >= 0 ? "plus.circle.fill" : "minus.circle.fill",
                tint: metrics.netBalance >= 0 ? .green : .orange,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "חייבים לי החודש", en: "Owed to Me This Month"),
                value: metrics.owedToMe.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "ממוצע חובות פתוחים חודשי: \(averages.openDebt.formattedShekelAmount)",
                    en: "Average monthly open debt: \(averages.openDebt.formattedShekelAmount)"
                ),
                systemImageName: "person.crop.circle.badge.plus",
                tint: .purple,
                appLanguage: appLanguage
            )

            AnalyticsSummaryCard(
                title: appLanguage.text(he: "אני חייב החודש", en: "I Owe This Month"),
                value: metrics.iOwe.formattedShekelAmount,
                subtitle: appLanguage.text(
                    he: "ממוצע חובות פתוחים חודשי: \(averages.openDebt.formattedShekelAmount)",
                    en: "Average monthly open debt: \(averages.openDebt.formattedShekelAmount)"
                ),
                systemImageName: "person.crop.circle.badge.exclamationmark",
                tint: .pink,
                appLanguage: appLanguage
            )
        }
    }

    private func monthlyAverageText(for average: Decimal) -> String {
        return appLanguage.text(
            he: "ממוצע חודשי: \(average.formattedShekelAmount)",
            en: "Monthly average: \(average.formattedShekelAmount)"
        )
    }

    private func categoryAverages(from metrics: [AnalyticsMonthMetrics]) -> [String: Decimal] {
        guard !metrics.isEmpty else {
            return [:]
        }

        var totals: [String: Decimal] = [:]
        for metric in metrics {
            for category in metric.categoryBreakdown {
                totals[category.id, default: 0] += category.amount
            }
        }

        let monthCount = Decimal(metrics.count)
        return totals.mapValues { $0 / monthCount }
    }

    private func categoryBreakdown(
        _ breakdown: [AnalyticsCategoryBreakdown],
        applying averages: [String: Decimal]
    ) -> [AnalyticsCategoryBreakdown] {
        breakdown.map { item in
            AnalyticsCategoryBreakdown(
                id: item.id,
                name: item.name,
                amount: item.amount,
                percentage: item.percentage,
                color: item.color,
                monthlyTarget: item.monthlyTarget,
                monthlyAverage: averages[item.id]
            )
        }
    }

    private func metrics(for month: Date) -> AnalyticsMonthMetrics {
        let monthStart = startOfMonth(month)
        let snapshot = resolvedSnapshot(for: monthStart)
        let categoryBreakdown = categoryBreakdown(from: snapshot.categoryTotals, categoryNames: snapshot.categoryNames)
        let topCategory = categoryBreakdown.first
        let expenseGoal = categories.reduce(Decimal(0)) { $0 + ($1.monthlyTarget ?? 0) }

        return AnalyticsMonthMetrics(
            month: monthStart,
            income: snapshot.income,
            expenses: snapshot.expenses,
            netSavings: snapshot.netSavings,
            netBalance: snapshot.netBalance,
            owedToMe: snapshot.owedToMe,
            iOwe: snapshot.iOwe,
            repaidDebts: snapshot.repaidDebts,
            expenseCount: snapshot.expenseCount,
            savingsBalance: Saving.balance(for: savings),
            savingsGoal: Storage.loadSavingsGoal(),
            expenseGoal: expenseGoal > 0 ? expenseGoal : nil,
            categoryBreakdown: categoryBreakdown,
            topExpenseCategoryName: topCategory?.name,
            topExpenseCategoryAmount: topCategory?.amount ?? 0
        )
    }

    private func resolvedSnapshot(for monthStart: Date) -> MonthlyAnalyticsSnapshot {
        let computedSnapshot = computedSnapshot(for: monthStart)
        let storedSnapshot = Storage.loadMonthlyAnalyticsSnapshots()[computedSnapshot.id]
        let isCurrentMonth = Calendar.current.isDate(monthStart, equalTo: Date(), toGranularity: .month)

        if !isCurrentMonth,
           let storedSnapshot,
           storedSnapshot.sourceSignature == computedSnapshot.sourceSignature {
            return storedSnapshot
        }

        Storage.saveMonthlyAnalyticsSnapshot(computedSnapshot)
        return computedSnapshot
    }

    private func computedSnapshot(for monthStart: Date) -> MonthlyAnalyticsSnapshot {
        let monthExpenses = expenses.filter { Calendar.current.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
        let monthSavings = savings.filter { Calendar.current.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
        let monthDebts = debts.filter { Calendar.current.isDate($0.date, equalTo: monthStart, toGranularity: .month) }

        let income = salaryEntries
            .filter { Calendar.current.isDate($0.monthDate, equalTo: monthStart, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + $1.amount }

        let expenseTotal = netExpenseTotal(for: monthExpenses)
        let categoryTotals = categoryTotals(for: monthExpenses)
        let categoryNames = categoryNames(for: monthExpenses)
        let netSavings = monthSavings.reduce(Decimal(0)) { total, saving in
            switch saving.kind {
            case .deposit:
                return total + saving.amount
            case .withdrawal:
                return total - saving.amount
            }
        }
        let netBalance = income - expenseTotal - netSavings

        let owedToMe = monthDebts
            .filter { $0.direction == .owedToMe && !$0.isFullyRepaid }
            .reduce(Decimal(0)) { $0 + $1.remainingAmount }
        let iOwe = monthDebts
            .filter { $0.direction == .iOwe && !$0.isFullyRepaid }
            .reduce(Decimal(0)) { $0 + $1.remainingAmount }
        let repaidDebts = monthDebts.reduce(Decimal(0)) { $0 + $1.repaidAmount }

        return MonthlyAnalyticsSnapshot(
            id: monthKey(for: monthStart),
            month: monthStart,
            income: income,
            expenses: expenseTotal,
            netSavings: netSavings,
            netBalance: netBalance,
            owedToMe: owedToMe,
            iOwe: iOwe,
            repaidDebts: repaidDebts,
            expenseCount: monthExpenses.count,
            categoryTotals: categoryTotals,
            categoryNames: categoryNames,
            sourceSignature: sourceSignature(
                monthExpenses: monthExpenses,
                monthSavings: monthSavings,
                monthDebts: monthDebts,
                monthSalaryEntries: salaryEntries.filter { Calendar.current.isDate($0.monthDate, equalTo: monthStart, toGranularity: .month) }
            ),
            updatedAt: Date()
        )
    }

    private func netExpenseTotal(for expenses: [Expense]) -> Decimal {
        let groupedExpenses = Dictionary(grouping: expenses) { expense in
            expense.categoryId
        }

        return groupedExpenses.reduce(Decimal(0)) { total, groupedExpense in
            let rawCategoryTotal = groupedExpense.value.reduce(Decimal(0)) { partialTotal, expense in
                partialTotal + expense.netAmount
            }
            return total + max(rawCategoryTotal, 0)
        }
    }

    private func categoryBreakdown(for expenses: [Expense], total: Decimal) -> [AnalyticsCategoryBreakdown] {
        categoryBreakdown(from: categoryTotals(for: expenses))
    }

    private func categoryTotals(for expenses: [Expense]) -> [String: Decimal] {
        let groupedExpenses = Dictionary(grouping: expenses) { expense in
            expense.categoryId
        }

        return groupedExpenses.reduce(into: [String: Decimal]()) { totals, groupedExpense in
            let rawAmount = groupedExpense.value.reduce(Decimal(0)) { partialTotal, expense in
                partialTotal + expense.netAmount
            }
            let amount = rawAmount < 0 ? Decimal(0) : rawAmount

            guard amount > 0 else {
                return
            }

            totals[groupedExpense.key] = amount
        }
    }

    private func categoryNames(for expenses: [Expense]) -> [String: String] {
        Dictionary(grouping: expenses, by: \.categoryId).reduce(into: [String: String]()) { names, groupedExpense in
            guard let categoryName = groupedExpense.value.first?.displayCategoryName(for: appLanguage),
                  !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            names[groupedExpense.key] = categoryName
        }
    }

    private func categoryBreakdown(from categoryTotals: [String: Decimal], categoryNames: [String: String] = [:]) -> [AnalyticsCategoryBreakdown] {
        let total = categoryTotals.values.reduce(Decimal(0), +)
        guard total > 0 else {
            return []
        }

        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .brown, .cyan]
        var rows: [(id: String, name: String, amount: Decimal)] = []

        for (categoryId, amount) in categoryTotals where amount > 0 {
            rows.append((id: categoryId, name: categoryName(for: categoryId, fallbackName: categoryNames[categoryId]), amount: amount))
        }

        rows.sort { first, second in
            first.amount > second.amount
        }

        var breakdown: [AnalyticsCategoryBreakdown] = []
        for (index, row) in rows.enumerated() {
            let monthlyTarget = categories.first(where: { $0.id == row.id })?.monthlyTarget
            breakdown.append(
                AnalyticsCategoryBreakdown(
                    id: row.id,
                    name: row.name,
                    amount: row.amount,
                    percentage: row.amount / total * 100,
                    color: colors[index % colors.count],
                    monthlyTarget: monthlyTarget,
                    monthlyAverage: nil
                )
            )
        }

        return breakdown
    }

    private func categoryName(for categoryId: String, fallbackExpenses: [Expense]) -> String {
        categoryName(for: categoryId, fallbackName: fallbackExpenses.first?.displayCategoryName(for: appLanguage))
    }

    private func categoryName(for categoryId: String, fallbackName: String? = nil) -> String {
        if let category = categories.first(where: { $0.id == categoryId }) {
            return category.displayName(for: appLanguage)
        }

        if let fallbackName,
           !fallbackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallbackName
        }

        return appLanguage.text(he: "ללא קטגוריה", en: "Uncategorized")
    }

    private func startOfMonth(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private func monthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }

    private func sourceSignature(
        monthExpenses: [Expense],
        monthSavings: [Saving],
        monthDebts: [Debt],
        monthSalaryEntries: [SalaryEntry]
    ) -> String {
        let expenseSignature = monthExpenses
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                [
                    $0.id.uuidString,
                    $0.categoryId,
                    $0.categoryName,
                    $0.amount.plainString,
                    $0.refundedAmount.plainString,
                    String(Int($0.date.timeIntervalSince1970))
                ].joined(separator: ":")
            }
            .joined(separator: ",")

        let savingSignature = monthSavings
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                [
                    $0.id.uuidString,
                    $0.amount.plainString,
                    $0.kind.rawValue,
                    String(Int($0.date.timeIntervalSince1970))
                ].joined(separator: ":")
            }
            .joined(separator: ",")

        let debtSignature = monthDebts
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map {
                [
                    $0.id.uuidString,
                    $0.direction.rawValue,
                    $0.originalAmount.plainString,
                    $0.repaidAmount.plainString,
                    String(Int($0.date.timeIntervalSince1970))
                ].joined(separator: ":")
            }
            .joined(separator: ",")

        let salarySignature = monthSalaryEntries
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString):\($0.amount.plainString):\($0.year):\($0.month)" }
            .joined(separator: ",")

        return [expenseSignature, savingSignature, debtSignature, salarySignature].joined(separator: "|")
    }
}

private struct AnalyticsSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let systemImageName: String
    let tint: Color
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImageName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .top)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AnalyticsGoalProgressView: View {
    let title: String
    let current: Decimal
    let goal: Decimal?
    let emptyText: String
    let progressText: (Decimal, Decimal, Decimal) -> String
    let warningText: String?
    let tint: Color
    let appLanguage: AppLanguage

    private var progress: Double {
        guard let goal, goal > 0 else {
            return 0
        }

        let ratio = NSDecimalNumber(decimal: current / goal).doubleValue
        return min(max(ratio, 0), 1.25)
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            if let goal, goal > 0 {
                let percent = current / goal * 100

                ProgressView(value: min(progress, 1))
                    .tint(warningText == nil ? tint : .orange)

                Text(progressText(current, goal, percent))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                if let warningText {
                    Text(warningText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                }
            } else {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AnalyticsCategoryGraphView: View {
    let breakdown: [AnalyticsCategoryBreakdown]
    @Binding var chartKind: AnalyticsCategoryChartKind
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            Text(appLanguage.text(he: "הוצאות לפי קטגוריה", en: "Expenses by Category"))
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Picker(appLanguage.text(he: "סוג גרף", en: "Chart type"), selection: $chartKind) {
                ForEach(AnalyticsCategoryChartKind.allCases) { kind in
                    Text(kind.title(for: appLanguage)).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if breakdown.isEmpty {
                AnalyticsEmptyStateView(
                    text: appLanguage.text(he: "אין נתונים להצגה", en: "No data to display"),
                    appLanguage: appLanguage
                )
            } else if chartKind == .pie {
                AnalyticsPieChartView(breakdown: breakdown, appLanguage: appLanguage)
            } else {
                AnalyticsCategoryBarChartView(breakdown: breakdown, appLanguage: appLanguage)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AnalyticsPieChartView: View {
    let breakdown: [AnalyticsCategoryBreakdown]
    let appLanguage: AppLanguage

    private var total: Decimal {
        breakdown.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(pieSlices) { slice in
                    AnalyticsPieSlice(startAngle: slice.startAngle, endAngle: slice.endAngle)
                        .fill(slice.color)
                }

                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 86, height: 86)

                VStack(spacing: 2) {
                    Text(total.formattedShekelAmount)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(appLanguage.text(he: "סה״כ", en: "Total"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 78)
            }
            .frame(width: 190, height: 190)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(breakdown.prefix(8)) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)

                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var pieSlices: [AnalyticsPieSliceData] {
        guard total > 0 else {
            return []
        }

        var start = -90.0
        return breakdown.map { item in
            let portion = NSDecimalNumber(decimal: item.amount / total).doubleValue
            let end = start + (portion * 360)
            let slice = AnalyticsPieSliceData(
                id: item.id,
                startAngle: .degrees(start),
                endAngle: .degrees(end),
                color: item.color
            )
            start = end
            return slice
        }
    }
}

private struct AnalyticsPieSliceData: Identifiable {
    let id: String
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
}

private struct AnalyticsPieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct AnalyticsCategoryBarChartView: View {
    let breakdown: [AnalyticsCategoryBreakdown]
    let appLanguage: AppLanguage

    private let overBudgetColor = Color(red: 1, green: 0.05, blue: 0.05)

    private var maxAmount: Decimal {
        breakdown.map(\.amount).max() ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(breakdown.prefix(8)) { item in
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                    HStack {
                        if appLanguage == .he {
                            Text("\(item.amount.formattedShekelAmount) · \(item.percentage.formattedPercentText)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        } else {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Spacer()

                            Text("\(item.amount.formattedShekelAmount) · \(item.percentage.formattedPercentText)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let targetStatus = item.targetStatus {
                        VStack(alignment: appLanguage.horizontalAlignment, spacing: 2) {
                            Text(categoryTargetRatioText(targetStatus, language: appLanguage))
                                .foregroundStyle(.secondary)

                            Text(categoryTargetStatusLineText(targetStatus, language: appLanguage))
                                .foregroundStyle(targetStatus.isOverBudget ? overBudgetColor : (targetStatus.remainingAmount > 0 ? Color.green : .secondary))
                        }
                        .font(.caption2.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: appLanguage.frameAlignment) {
                            let totalWidth = item.hasMonthlyTarget
                                ? targetProgressTotalWidth(for: item, maxWidth: proxy.size.width)
                                : barWidth(for: item.amount, maxWidth: proxy.size.width)

                            if item.isOverBudget {
                                let overrunWidth = targetProgressWidth(for: item.overBudgetAmount, item: item, maxWidth: proxy.size.width)
                                let targetWidth = targetProgressWidth(for: item.targetCoveredAmount, item: item, maxWidth: proxy.size.width)

                                HStack(spacing: 0) {
                                    if appLanguage == .he {
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(overBudgetColor)
                                            .frame(width: overrunWidth)

                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(item.color.gradient)
                                            .frame(width: targetWidth)
                                    } else {
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(item.color.gradient)
                                            .frame(width: targetWidth)

                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(overBudgetColor)
                                            .frame(width: overrunWidth)
                                    }
                                }
                                .frame(width: totalWidth, alignment: appLanguage.frameAlignment)
                                .clipShape(Capsule())
                            } else {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(item.color.gradient)
                                    .frame(width: totalWidth)
                            }
                        }
                    }
                    .frame(height: 9)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private func barWidth(for amount: Decimal, maxWidth: CGFloat) -> CGFloat {
        guard maxAmount > 0 else {
            return 0
        }

        let amountNumber = NSDecimalNumber(decimal: amount).doubleValue
        let maxNumber = NSDecimalNumber(decimal: maxAmount).doubleValue
        return max(8, CGFloat(amountNumber / maxNumber) * maxWidth)
    }

    private func targetProgressTotalWidth(for item: AnalyticsCategoryBreakdown, maxWidth: CGFloat) -> CGFloat {
        guard item.amount > 0 else {
            return 0
        }

        if item.isOverBudget {
            return maxWidth
        }

        guard let monthlyTarget = item.monthlyTarget, monthlyTarget > 0 else {
            return barWidth(for: item.amount, maxWidth: maxWidth)
        }

        let amountNumber = NSDecimalNumber(decimal: item.amount).doubleValue
        let targetNumber = NSDecimalNumber(decimal: monthlyTarget).doubleValue
        return max(8, CGFloat(amountNumber / targetNumber) * maxWidth)
    }

    private func targetProgressWidth(for amount: Decimal, item: AnalyticsCategoryBreakdown, maxWidth: CGFloat) -> CGFloat {
        guard let monthlyTarget = item.monthlyTarget, monthlyTarget > 0, amount > 0 else {
            return 0
        }

        let scale = max(monthlyTarget, item.amount)
        let amountNumber = NSDecimalNumber(decimal: amount).doubleValue
        let scaleNumber = NSDecimalNumber(decimal: scale).doubleValue
        return min(maxWidth, max(3, CGFloat(amountNumber / scaleNumber) * maxWidth))
    }
}

private struct AnalyticsCategoryRankingView: View {
    let breakdown: [AnalyticsCategoryBreakdown]
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 12) {
            Text(appLanguage.text(he: "דירוג קטגוריות", en: "Category Ranking"))
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            if breakdown.isEmpty {
                AnalyticsEmptyStateView(
                    text: appLanguage.text(he: "אין נתונים להצגה", en: "No data to display"),
                    appLanguage: appLanguage
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(breakdown.enumerated()), id: \.element.id) { index, item in
                        AnalyticsCategoryRankingRow(index: index + 1, item: item, appLanguage: appLanguage)
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AnalyticsCategoryRankingRow: View {
    let index: Int
    let item: AnalyticsCategoryBreakdown
    let appLanguage: AppLanguage

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                if appLanguage == .he {
                    Text("\(item.amount.formattedShekelAmount) · \(item.percentage.formattedPercentText)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                } else {
                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.secondary.opacity(0.12), in: Circle())

                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    Text("\(item.amount.formattedShekelAmount) · \(item.percentage.formattedPercentText)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            if let monthlyAverage = item.monthlyAverage {
                Text(appLanguage.text(
                    he: "ממוצע חודשי: \(monthlyAverage.formattedShekelAmount)",
                    en: "Monthly average: \(monthlyAverage.formattedShekelAmount)"
                ))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            if let targetStatus = item.targetStatus {
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 2) {
                    Text(categoryTargetRatioText(targetStatus, language: appLanguage))
                        .foregroundStyle(.secondary)

                    Text(categoryTargetStatusLineText(targetStatus, language: appLanguage))
                        .foregroundStyle(targetStatus.isOverBudget ? Color.red : (targetStatus.remainingAmount > 0 ? Color.green : .secondary))
                }
                .font(.caption2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            }

            GeometryReader { proxy in
                ZStack(alignment: appLanguage.frameAlignment) {
                    let totalWidth = item.hasMonthlyTarget
                        ? targetProgressTotalWidth(maxWidth: proxy.size.width)
                        : max(8, proxy.size.width * percentageWidth)

                    if item.isOverBudget {
                        let overrunWidth = targetProgressWidth(for: item.overBudgetAmount, maxWidth: proxy.size.width)
                        let targetWidth = targetProgressWidth(for: item.targetCoveredAmount, maxWidth: proxy.size.width)

                        HStack(spacing: 0) {
                            if appLanguage == .he {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color(red: 1, green: 0.05, blue: 0.05))
                                    .frame(width: overrunWidth)

                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(item.color.opacity(0.75))
                                    .frame(width: targetWidth)
                            } else {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(item.color.opacity(0.75))
                                    .frame(width: targetWidth)

                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color(red: 1, green: 0.05, blue: 0.05))
                                    .frame(width: overrunWidth)
                            }
                        }
                        .frame(width: totalWidth, alignment: appLanguage.frameAlignment)
                        .clipShape(Capsule())
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.color.opacity(0.75))
                            .frame(width: totalWidth)
                    }
                }
            }
            .frame(height: 6)
            .background(Color.secondary.opacity(0.10), in: Capsule())
        }
    }

    private var percentageWidth: CGFloat {
        let value = NSDecimalNumber(decimal: item.percentage / 100).doubleValue
        return CGFloat(min(max(value, 0), 1))
    }

    private func targetProgressTotalWidth(maxWidth: CGFloat) -> CGFloat {
        guard item.amount > 0 else {
            return 0
        }

        if item.isOverBudget {
            return maxWidth
        }

        guard let monthlyTarget = item.monthlyTarget, monthlyTarget > 0 else {
            return max(8, maxWidth * percentageWidth)
        }

        let amountNumber = NSDecimalNumber(decimal: item.amount).doubleValue
        let targetNumber = NSDecimalNumber(decimal: monthlyTarget).doubleValue
        return max(8, CGFloat(amountNumber / targetNumber) * maxWidth)
    }

    private func targetProgressWidth(for amount: Decimal, maxWidth: CGFloat) -> CGFloat {
        guard let monthlyTarget = item.monthlyTarget, monthlyTarget > 0, amount > 0 else {
            return 0
        }

        let scale = max(monthlyTarget, item.amount)
        let amountNumber = NSDecimalNumber(decimal: amount).doubleValue
        let scaleNumber = NSDecimalNumber(decimal: scale).doubleValue
        return min(maxWidth, max(3, CGFloat(amountNumber / scaleNumber) * maxWidth))
    }
}

private struct AnalyticsComparisonChart: View {
    let metrics: AnalyticsMonthMetrics
    let appLanguage: AppLanguage

    private var items: [AnalyticsComparisonItem] {
        [
            AnalyticsComparisonItem(title: appLanguage.text(he: "הכנסות", en: "Income"), amount: metrics.income, color: .green),
            AnalyticsComparisonItem(title: appLanguage.text(he: "הוצאות", en: "Expenses"), amount: metrics.expenses, color: .red),
            AnalyticsComparisonItem(title: appLanguage.text(he: "חיסכון", en: "Savings"), amount: metrics.netSavings, color: .blue),
            AnalyticsComparisonItem(title: appLanguage.text(he: "תזרים", en: "Cash Flow"), amount: metrics.netBalance, color: metrics.netBalance >= 0 ? .green : .orange)
        ]
    }

    private var maxAmount: Decimal {
        items.map { $0.amount < 0 ? -$0.amount : $0.amount }.max() ?? 0
    }

    private var hasData: Bool {
        maxAmount > 0
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            if hasData {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(items) { item in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(item.color.gradient)
                                .frame(width: 34, height: barHeight(for: item.amount))
                                .opacity(item.amount == 0 ? 0.25 : 1)

                            Text(item.amount.formattedShekelAmount)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)

                            Text(item.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 170, alignment: .bottom)
                .environment(\.layoutDirection, .leftToRight)
            } else {
                AnalyticsEmptyStateView(
                    text: appLanguage.text(he: "אין נתונים להצגה", en: "No data to display"),
                    appLanguage: appLanguage
                )
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func barHeight(for value: Decimal) -> CGFloat {
        let absolute = value < 0 ? -value : value
        guard maxAmount > 0, absolute > 0 else {
            return 8
        }

        let valueNumber = NSDecimalNumber(decimal: absolute).doubleValue
        let maxNumber = NSDecimalNumber(decimal: maxAmount).doubleValue
        return max(8, min(116, CGFloat(valueNumber / maxNumber) * 116))
    }
}

private struct AnalyticsComparisonItem: Identifiable {
    let id = UUID()
    let title: String
    let amount: Decimal
    let color: Color
}

private struct AnalyticsEmptyStateView: View {
    let text: String
    let appLanguage: AppLanguage

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            .padding(.vertical, 18)
    }
}

private struct AnalyticsTrendChart: View {
    let metrics: [AnalyticsMonthMetrics]
    let appLanguage: AppLanguage

    private var chartOuterSpacing: CGFloat {
        metrics.count > 8 ? 3 : 10
    }

    private var chartGroupSpacing: CGFloat {
        metrics.count > 8 ? 2 : 4
    }

    private var chartBarWidth: CGFloat {
        metrics.count > 8 ? 5 : 10
    }

    private var maxChartValue: Decimal {
        let values = metrics.flatMap { metric in
            [metric.income, metric.expenses, magnitude(metric.netSavings)]
        }
        return values.max() ?? 0
    }

    private var hasData: Bool {
        maxChartValue > 0
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 14) {
            if hasData {
                if metrics.count > 12 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        trendBars
                            .frame(minWidth: CGFloat(metrics.count) * 32)
                    }
                } else {
                    trendBars
                }

                HStack(spacing: 12) {
                    chartLegend(appLanguage.text(he: "הכנסות", en: "Income"), .green)
                    chartLegend(appLanguage.text(he: "הוצאות", en: "Expenses"), .red)
                    chartLegend(appLanguage.text(he: "חסכון נטו", en: "Net savings"), .blue)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                AnalyticsEmptyStateView(
                    text: appLanguage.text(he: "אין נתונים להצגה", en: "No data to display"),
                    appLanguage: appLanguage
                )
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var trendBars: some View {
        HStack(alignment: .bottom, spacing: chartOuterSpacing) {
            ForEach(metrics) { metric in
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: chartGroupSpacing) {
                        chartBar(value: metric.income, color: .green)
                        chartBar(value: metric.expenses, color: .red)
                        chartBar(value: magnitude(metric.netSavings), color: metric.netSavings < 0 ? .orange : .blue)
                    }
                    .frame(height: 132, alignment: .bottom)

                    Text(metric.month.monthYearText(for: appLanguage))
                        .font(.system(size: metrics.count > 8 ? 8 : 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(maxWidth: .infinity, minHeight: 154)
            }
        }
        .frame(maxWidth: metrics.count > 12 ? nil : .infinity)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func chartBar(value: Decimal, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(color.gradient)
            .frame(width: chartBarWidth, height: barHeight(for: value))
            .opacity(value <= 0 ? 0.25 : 1)
    }

    private func chartLegend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func barHeight(for value: Decimal) -> CGFloat {
        guard maxChartValue > 0, value > 0 else {
            return 6
        }

        let valueNumber = NSDecimalNumber(decimal: value).doubleValue
        let maxNumber = NSDecimalNumber(decimal: maxChartValue).doubleValue
        return max(6, min(124, CGFloat(valueNumber / maxNumber) * 124))
    }

    private func magnitude(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}

private struct AnalyticsSectionPlaceholder: View {
    let title: String
    let text: String
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PastDataView: View {
    @Environment(\.appLanguage) private var appLanguage

    let categories: [ExpenseCategory]
    @Binding var expenses: [Expense]
    @Binding var salaryEntries: [SalaryEntry]
    let onClose: () -> Void
    let onPersist: () -> Void

    @State private var selectedMonth = Date()
    @State private var selectedCategoryId: String?
    @State private var savings: [Saving] = []
    @State private var savingGoals: [SavingGoal] = []
    @State private var debts: [Debt] = []
    @State private var isPastDataActionSelectorPresented = false
    @State private var isPastDataAddSelectorPresented = false
    @State private var pastSelectedAddAction: FinancialAddAction?
    @State private var isPastDataAddTypeSelectorPresented = false
    @State private var isEditingMonthData = false
    @State private var isAddingExpense = false
    @State private var isAddingRecurringExpense = false
    @State private var isAddingDebtDirectionPresented = false
    @State private var isAddingDebt = false
    @State private var pastDebtDirection: DebtDirection = .owedToMe
    @State private var pastDataAlertMessage: String?
    @State private var expenseBeingEdited: Expense?
    @State private var isAddingIncome = false
    @State private var salaryBeingEdited: SalaryEntry?
    @State private var salaryPendingDelete: SalaryEntry?
    @State private var isAddingSaving = false
    @State private var isAddingRecurringSaving = false
    @State private var savingBeingEdited: Saving?

    private var visibleCategories: [ExpenseCategory] {
        let activeCategoryIds = Set(expensesForSelectedMonth.map(\.categoryId))
        return categories.filter { activeCategoryIds.contains($0.id) }
    }

    private var expensesForSelectedMonth: [Expense] {
        expenses
            .filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .filter { expense in
                guard let selectedCategoryId else {
                    return true
                }

                return expense.categoryId == selectedCategoryId
            }
            .sorted { $0.date > $1.date }
    }

    private var groupedExpenses: [ExpenseCategoryExpenseGroup] {
        Dictionary(grouping: expensesForSelectedMonth, by: \.categoryId)
            .compactMap { categoryId, groupedExpenses in
                let categoryName = categories.first(where: { $0.id == categoryId })?.name
                    ?? groupedExpenses.first?.categoryName
                    ?? appLanguage.text(he: "קטגוריה", en: "Category")

                return ExpenseCategoryExpenseGroup(
                    categoryId: categoryId,
                    categoryName: categoryName,
                    expenses: groupedExpenses
                )
            }
            .sorted { $0.categoryName < $1.categoryName }
    }

    private var total: Decimal {
        netExpenseTotal(for: expensesForSelectedMonth)
    }

    private var selectedMonthlyExpenseGoal: Decimal? {
        if let selectedCategoryId {
            return categories.first(where: { $0.id == selectedCategoryId })?.monthlyTarget
        }

        let target = categories.reduce(Decimal(0)) { total, category in
            total + (category.monthlyTarget ?? 0)
        }

        return target > 0 ? target : nil
    }

    private var selectedMonthGoalSummaryText: String {
        guard let selectedMonthlyExpenseGoal, selectedMonthlyExpenseGoal > 0 else {
            return appLanguage.text(he: "לא הוגדר יעד חודשי", en: "No monthly goal set")
        }

        let percentage = total / selectedMonthlyExpenseGoal * 100
        let status = total <= selectedMonthlyExpenseGoal
            ? appLanguage.text(he: "עמדת ביעד החודשי", en: "Monthly goal met")
            : appLanguage.text(he: "חרגת מהיעד החודשי", en: "Monthly goal exceeded")
        return appLanguage.text(
            he: "הוצאות: \(total.formattedShekelAmount) מתוך יעד \(selectedMonthlyExpenseGoal.formattedShekelAmount) (\(percentage.formattedPercentText)) · \(status)",
            en: "Expenses: \(total.formattedShekelAmount) of goal \(selectedMonthlyExpenseGoal.formattedShekelAmount) (\(percentage.formattedPercentText)) · \(status)"
        )
    }

    private var savingsForSelectedMonth: [Saving] {
        savings
            .filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private var debtsForSelectedMonth: [Debt] {
        debts
            .filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private var debtsOwedToMeForSelectedMonth: [Debt] {
        debtsForSelectedMonth.filter { $0.direction == .owedToMe }
    }

    private var debtsIOweForSelectedMonth: [Debt] {
        debtsForSelectedMonth.filter { $0.direction == .iOwe }
    }

    private var salaryEntriesForSelectedMonth: [SalaryEntry] {
        salaryEntries
            .filter { Calendar.current.isDate($0.monthDate, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.monthDate > $1.monthDate }
    }

    private var totalIncomeForSelectedMonth: Decimal {
        salaryEntriesForSelectedMonth.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var totalSavingsForSelectedMonth: Decimal {
        savingsForSelectedMonth.reduce(Decimal(0)) { total, saving in
            switch saving.kind {
            case .deposit:
                total + saving.amount
            case .withdrawal:
                total - saving.amount
            }
        }
    }

    private var totalOwedToMeForSelectedMonth: Decimal {
        debtsOwedToMeForSelectedMonth.reduce(Decimal(0)) { $0 + $1.remainingAmount }
    }

    private var totalIOweForSelectedMonth: Decimal {
        debtsIOweForSelectedMonth.reduce(Decimal(0)) { $0 + $1.remainingAmount }
    }

    private var selectedMonthHasNoData: Bool {
        expensesForSelectedMonth.isEmpty
            && salaryEntriesForSelectedMonth.isEmpty
            && savingsForSelectedMonth.isEmpty
            && debtsForSelectedMonth.isEmpty
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        MonthNavigationView(selectedMonth: $selectedMonth)
                            .padding(.top, 4)

                        Picker(appLanguage.text(he: "קטגוריה", en: "Category"), selection: selectedCategoryBinding) {
                            Text(appLanguage.text(he: "כל הקטגוריות", en: "All Categories")).tag(Optional<String>.none)

                            ForEach(visibleCategories) { category in
                                Text(category.displayName(for: appLanguage)).tag(Optional(category.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Text(selectedMonthGoalSummaryText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                            .padding(.horizontal, 4)

                        if selectedMonthHasNoData {
                            Text(appLanguage.text(he: "אין נתונים לחודש הזה", en: "No data for this month"))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 18)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        PastDataSectionCard {
                        PastDataSectionHeader(
                            title: appLanguage.text(he: "הוצאות", en: "Expenses"),
                            summary: appLanguage.text(
                                he: "סה״כ הוצאות \(total.formattedShekelAmount)",
                                en: "Total expenses \(total.formattedShekelAmount)"
                            )
                        )

                        if isEditingMonthData {
                            Button {
                                isAddingExpense = true
                            } label: {
                                Label(appLanguage.text(he: "הוסף הוצאה לחודש", en: "Add expense to month"), systemImage: "plus.circle")
                            }
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        }

                        if groupedExpenses.isEmpty {
                            PastDataEmptyState(text: appLanguage.text(he: "אין הוצאות בחודש הזה", en: "No expenses this month"))
                        } else {
                            ForEach(groupedExpenses) { group in
                                VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
                                    Text("\(group.displayName(for: appLanguage)) · \(group.total.formattedShekelAmount)")
                                        .font(.headline.weight(.semibold))
                                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                                    ForEach(group.expenses) { expense in
                                        if isEditingMonthData {
                                            ExpenseEditableRow(
                                                expense: expense,
                                                onEdit: {
                                                    expenseBeingEdited = expense
                                                },
                                                onDelete: {
                                                    deleteExpense(expense)
                                                }
                                            )
                                        } else {
                                            ExpensePastDataRow(expense: expense)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                                .padding(.vertical, 8)

                                if group.id != groupedExpenses.last?.id {
                                    Divider()
                                }
                            }
                        }
                        }

                        PastDataSectionCard {
                        PastDataSectionHeader(
                            title: appLanguage.text(he: "הכנסות", en: "Income"),
                            summary: appLanguage.text(
                                he: "סה״כ הכנסות \(totalIncomeForSelectedMonth.formattedShekelAmount)",
                                en: "Total income \(totalIncomeForSelectedMonth.formattedShekelAmount)"
                            )
                        )

                        if isEditingMonthData {
                            Button {
                                isAddingIncome = true
                            } label: {
                                Label(appLanguage.text(he: "הוסף הכנסה לחודש", en: "Add income to month"), systemImage: "plus.circle")
                            }
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        }

                        if salaryEntriesForSelectedMonth.isEmpty {
                            PastDataEmptyState(text: appLanguage.text(he: "אין הכנסות בחודש הזה", en: "No income this month"))
                        } else {
                            ForEach(salaryEntriesForSelectedMonth) { entry in
                                SalaryPastDataRow(
                                    entry: entry,
                                    isEditing: isEditingMonthData,
                                    onEdit: { salaryBeingEdited = entry },
                                    onDelete: { salaryPendingDelete = entry }
                                )
                            }
                        }
                        }

                        PastDataSectionCard {
                        PastDataSectionHeader(
                            title: appLanguage.text(he: "חסכונות", en: "Savings"),
                            summary: appLanguage.text(
                                he: "חסכון נטו \(totalSavingsForSelectedMonth.formattedShekelAmount)",
                                en: "Net savings \(totalSavingsForSelectedMonth.formattedShekelAmount)"
                            )
                        )

                        if isEditingMonthData {
                            Button {
                                isAddingSaving = true
                            } label: {
                                Label(appLanguage.text(he: "הוסף חסכון לחודש", en: "Add saving to month"), systemImage: "plus.circle")
                            }
                            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                        }

                        if savingsForSelectedMonth.isEmpty {
                            PastDataEmptyState(text: appLanguage.text(he: "אין פעולות חסכון בחודש הזה", en: "No savings activity this month"))
                        } else {
                            ForEach(savingsForSelectedMonth) { saving in
                                SavingPastDataRow(
                                    saving: saving,
                                    goal: savingGoals.first { $0.id == saving.goalId },
                                    isEditing: isEditingMonthData,
                                    onEdit: { savingBeingEdited = saving },
                                    onDelete: { deleteSaving(saving) }
                                )
                            }
                        }
                        }

                        PastDataSectionCard {
                        PastDataSectionHeader(
                            title: appLanguage.text(he: "חובות", en: "Debts"),
                            summary: appLanguage.text(
                                he: "חייבים לי \(totalOwedToMeForSelectedMonth.formattedShekelAmount) · אני חייב \(totalIOweForSelectedMonth.formattedShekelAmount)",
                                en: "Owed to me \(totalOwedToMeForSelectedMonth.formattedShekelAmount) · I owe \(totalIOweForSelectedMonth.formattedShekelAmount)"
                            )
                        )

                        if debtsForSelectedMonth.isEmpty {
                            PastDataEmptyState(text: appLanguage.text(he: "אין חובות בחודש הזה", en: "No debts this month"))
                        } else {
                            ForEach(debtsForSelectedMonth) { debt in
                                DebtPastDataRow(debt: debt)
                            }
                        }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .background(Color.clear)
                .navigationTitle(appLanguage.text(he: "נתוני עבר", en: "Past Data"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(appLanguage.text(he: "סגור", en: "Close")) {
                            onClose()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if isEditingMonthData {
                                isEditingMonthData = false
                            } else {
                                isPastDataActionSelectorPresented = true
                        }
                    } label: {
                        Image(systemName: isEditingMonthData ? "checkmark" : "pencil")
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .zIndex(20)
                    .accessibilityLabel(isEditingMonthData
                        ? appLanguage.text(he: "סיום עריכה", en: "Done editing")
                        : appLanguage.text(he: "ערוך נתוני חודש", en: "Edit month data"))
                        .popover(isPresented: $isPastDataActionSelectorPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                            PastDataActionBubbleView(
                                appLanguage: appLanguage,
                                onEdit: {
                                    isPastDataActionSelectorPresented = false
                                    isEditingMonthData = true
                                },
                                onAdd: {
                                    isPastDataActionSelectorPresented = false
                                    isPastDataAddSelectorPresented = true
                                }
                            )
                            .presentationCompactAdaptation(.popover)
                        }
                        .popover(isPresented: $isPastDataAddSelectorPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                            AddActionBubbleView(
                                title: appLanguage.text(he: "מה תרצה להוסיף?", en: "What would you like to add?"),
                                actions: FinancialAddAction.allCases,
                                appLanguage: appLanguage,
                                onSelect: { action in
                                    pastSelectedAddAction = action
                                    isPastDataAddSelectorPresented = false
                                    isPastDataAddTypeSelectorPresented = true
                                }
                            )
                            .presentationCompactAdaptation(.popover)
                        }
                        .popover(isPresented: $isPastDataAddTypeSelectorPresented, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                            AddOccurrenceBubbleView(
                                title: pastSelectedAddAction?.typePrompt(for: appLanguage)
                                    ?? appLanguage.text(he: "סוג פעולה", en: "Action Type"),
                                appLanguage: appLanguage,
                                onSelect: handlePastDataAddTypeSelection
                            )
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            }

            if isAddingExpense {
                centeredModalOverlay {
                    HistoricalExpenseEditorView(
                        categories: categories,
                        selectedMonth: selectedMonth,
                        allowsDateTimeSelection: true,
                        onSave: addHistoricalExpense,
                        onCancel: { isAddingExpense = false }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isAddingRecurringExpense {
                centeredModalOverlay {
                    AddExpenseModalView(
                        categories: categories,
                        initialIsRecurring: true,
                        initialDate: Calendar.current.normalizedMonthDate(for: selectedMonth),
                        onSave: addExpenseFromModal,
                        onCancel: {
                            isAddingRecurringExpense = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isAddingSaving {
                centeredModalOverlay {
                    SavingEditorView(
                        saving: nil,
                        selectedMonth: selectedMonth,
                        allowsDateTimeSelection: true,
                        goals: savingGoals,
                        savings: savings,
                        onSave: addSaving,
                        onCancel: { isAddingSaving = false }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isAddingRecurringSaving {
                centeredModalOverlay {
                    RecurringSavingEditorView(
                        goals: savingGoals,
                        initialDate: Calendar.current.normalizedMonthDate(for: selectedMonth),
                        onSave: addRecurringSaving,
                        onCancel: {
                            isAddingRecurringSaving = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isAddingDebtDirectionPresented {
                centeredModalOverlay(maxWidth: 340) {
                    DebtDirectionChooserView(
                        onSelect: { direction in
                            pastDebtDirection = direction
                            isAddingDebtDirectionPresented = false
                            isAddingDebt = true
                        },
                        onCancel: {
                            isAddingDebtDirectionPresented = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isAddingDebt {
                centeredModalOverlay {
                    AddDebtView(
                        direction: pastDebtDirection,
                        initialDate: Calendar.current.normalizedMonthDate(for: selectedMonth),
                        onSave: addDebt,
                        onCancel: {
                            isAddingDebt = false
                        }
                    )
                    .localizedPresentationEnvironment(appLanguage)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            savings = Storage.loadSavings()
            savingGoals = Storage.loadSavingGoals()
            debts = Storage.loadDebts()
        }
        .sheet(item: $expenseBeingEdited) { expense in
            EditExpenseView(
                expense: expense,
                categories: categories,
                lockedMonth: selectedMonth,
                onSave: { updatedExpense in
                    updateExpense(updatedExpense)
                    expenseBeingEdited = nil
                },
                onCancel: { expenseBeingEdited = nil }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(680)])
        }
        .sheet(isPresented: $isAddingIncome) {
            SalaryEntryEditorView(
                entry: nil,
                selectedMonth: selectedMonth,
                onSave: addSalaryEntry,
                onCancel: { isAddingIncome = false }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(300)])
        }
        .sheet(item: $salaryBeingEdited) { entry in
            SalaryEntryEditorView(
                entry: entry,
                selectedMonth: selectedMonth,
                onSave: { updatedEntry in
                    updateSalaryEntry(updatedEntry)
                    salaryBeingEdited = nil
                },
                onCancel: { salaryBeingEdited = nil }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(300)])
        }
        .sheet(item: $savingBeingEdited) { saving in
            SavingEditorView(
                saving: saving,
                selectedMonth: selectedMonth,
                allowsDateTimeSelection: true,
                goals: savingGoals,
                savings: savings,
                onSave: { updatedSaving in
                    updateSaving(updatedSaving)
                    savingBeingEdited = nil
                },
                onCancel: { savingBeingEdited = nil }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(470)])
        }
        .alert(appLanguage.text(he: "עדיין לא זמין", en: "Not available yet"), isPresented: pastDataAlertBinding) {
            Button(appLanguage.text(he: "אישור", en: "OK"), role: .cancel) {
                pastDataAlertMessage = nil
            }
        } message: {
            Text(pastDataAlertMessage ?? "")
        }
        .alert(
            appLanguage.text(he: "מחיקת הכנסה", en: "Delete Income"),
            isPresented: salaryDeleteAlertBinding
        ) {
            Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {
                salaryPendingDelete = nil
            }

            Button(appLanguage.text(he: "מחק", en: "Delete"), role: .destructive) {
                if let salaryPendingDelete {
                    deleteSalaryEntry(salaryPendingDelete)
                }
                salaryPendingDelete = nil
            }
        } message: {
            Text(appLanguage.text(
                he: "האם אתה בטוח שברצונך למחוק את ההכנסה?",
                en: "Are you sure you want to delete this income entry?"
            ))
        }
    }

    private var selectedCategoryBinding: Binding<String?> {
        Binding(
            get: { selectedCategoryId },
            set: { selectedCategoryId = $0 }
        )
    }

    private var pastDataAlertBinding: Binding<Bool> {
        Binding(
            get: { pastDataAlertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    pastDataAlertMessage = nil
                }
            }
        )
    }

    private var salaryDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { salaryPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    salaryPendingDelete = nil
                }
            }
        )
    }

    private func centeredModalOverlay<Content: View>(
        maxWidth: CGFloat = 392,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            content()
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
        }
        .zIndex(9)
    }

    private func handlePastDataAddTypeSelection(_ type: AddOccurrenceType) {
        isPastDataAddTypeSelectorPresented = false

        guard let pastSelectedAddAction else {
            return
        }

        switch (pastSelectedAddAction, type) {
        case (.expense, .oneTime):
            presentAfterBubbleDismiss {
                isAddingExpense = true
            }
        case (.expense, .recurring):
            presentAfterBubbleDismiss {
                isAddingRecurringExpense = true
            }
        case (.saving, .oneTime):
            presentAfterBubbleDismiss {
                isAddingSaving = true
            }
        case (.saving, .recurring):
            presentAfterBubbleDismiss {
                isAddingRecurringSaving = true
            }
        case (.debt, .oneTime):
            presentAfterBubbleDismiss {
                isAddingDebtDirectionPresented = true
            }
        case (.debt, .recurring):
            presentAfterBubbleDismiss {
                pastDataAlertMessage = appLanguage.text(
                    he: "עדיין לא זמין. אפשר להוסיף חוב חד פעמי כרגע.",
                    en: "Recurring debt is not available yet. You can add a one-time debt for now."
                )
            }
        }
    }

    private func presentAfterBubbleDismiss(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            action()
        }
    }

    private func addHistoricalExpense(_ expense: Expense) {
        expenses.append(expense)
        expenses.sort { $0.date > $1.date }
        onPersist()
        isAddingExpense = false
    }

    private func addExpenseFromModal(
        name: String,
        amount: Decimal,
        isRecurring: Bool,
        date: Date,
        categoryId: String?
    ) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard amount > 0 else {
            return appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
        }

        guard let categoryId,
              let category = categories.first(where: { $0.id == categoryId }) else {
            return appLanguage.text(he: "צריך לבחור קטגוריה", en: "Choose a category")
        }

        expenses.append(Expense(
            categoryId: category.id,
            categoryName: category.name,
            amount: amount,
            createdAt: Date(),
            date: date,
            name: trimmedName.isEmpty ? nil : trimmedName,
            isRecurring: isRecurring,
            source: .backfill
        ))
        expenses.sort { $0.date > $1.date }
        onPersist()

        if isRecurring {
            var storedRecurringExpenses = Storage.loadRecurringExpenses()
            storedRecurringExpenses.append(RecurringExpense(
                name: trimmedName.isEmpty ? category.name : trimmedName,
                amount: amount,
                categoryId: category.id,
                categoryName: category.name,
                createdAt: date
            ))
            Storage.saveRecurringExpenses(storedRecurringExpenses)
        }

        isAddingRecurringExpense = false
        return nil
    }

    private func updateExpense(_ expense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else {
            return
        }

        expenses[index] = expense
        onPersist()
    }

    private func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        onPersist()
    }

    private func addDebt(_ debt: Debt) {
        debts.append(debt)
        debts.sort { $0.date > $1.date }
        Storage.saveDebts(debts)
        isAddingDebt = false
    }

    private func addSalaryEntry(_ entry: SalaryEntry) {
        salaryEntries.removeAll { $0.year == entry.year && $0.month == entry.month }
        salaryEntries.append(entry)
        salaryEntries.sort { $0.monthDate > $1.monthDate }
        onPersist()
        isAddingIncome = false
    }

    private func updateSalaryEntry(_ entry: SalaryEntry) {
        guard let index = salaryEntries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        salaryEntries[index] = entry
        onPersist()
    }

    private func deleteSalaryEntry(_ entry: SalaryEntry) {
        salaryEntries.removeAll { $0.id == entry.id }
        onPersist()
    }

    private func addSaving(_ saving: Saving) {
        savings.append(saving)
        savings.sort { $0.date > $1.date }
        Storage.saveSavings(savings)
        isAddingSaving = false
    }

    private func addRecurringSaving(_ recurringSaving: RecurringSaving) {
        var recurringSavings = Storage.loadRecurringSavings()
        recurringSavings.append(recurringSaving)
        recurringSavings.sort { $0.startDate > $1.startDate }
        Storage.saveRecurringSavings(recurringSavings)
        isAddingRecurringSaving = false
    }

    private func updateSaving(_ saving: Saving) {
        guard let index = savings.firstIndex(where: { $0.id == saving.id }) else {
            return
        }

        savings[index] = saving
        Storage.saveSavings(savings)
    }

    private func deleteSaving(_ saving: Saving) {
        savings.removeAll { $0.id == saving.id }
        Storage.saveSavings(savings)
    }
}

private struct PastDataSectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PastDataSectionHeader: View {
    @Environment(\.appLanguage) private var appLanguage

    let title: String
    let summary: String

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
            Text(title)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Text(summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Divider()
                .padding(.top, 4)
        }
        .padding(.bottom, 2)
    }
}

private struct PastDataEmptyState: View {
    @Environment(\.appLanguage) private var appLanguage

    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            .padding(.vertical, 10)
    }
}

private struct ExpensePastDataRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let expense: Expense

    private var displayName: String {
        let trimmedName = expense.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? expense.displayCategoryName(for: appLanguage) : trimmedName
    }

    private var badges: [String] {
        var values: [String] = []

        if expense.isRecurring {
            values.append(appLanguage.text(he: "חוזרת", en: "Recurring"))
        }

        if expense.source == .backfill {
            values.append(appLanguage.text(he: "בדיעבד", en: "Past entry"))
        }

        return values
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                Text(expense.netAmount.formattedShekelAmount)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }
            .environment(\.layoutDirection, appLanguage.layoutDirection)

            Text(expense.displayCategoryName(for: appLanguage))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Text(expense.date.expenseDateTimeText(for: appLanguage))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            if let refundSummary = expense.refundSummaryText(for: appLanguage) {
                Text(refundSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(expense.refundStatus == .full ? .green : .orange)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }

            if !badges.isEmpty {
                Text(badges.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(expense.source == .backfill ? Color.red : .blue)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .padding(.vertical, 4)
    }
}

private struct DebtPastDataRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let debt: Debt

    private var statusColor: Color {
        if debt.isFullyRepaid {
            return .green
        }

        return debt.repaidAmount > 0 ? .blue : .secondary
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(debt.personName)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(debt.isFullyRepaid)

                Spacer(minLength: 8)

                Text(debt.remainingAmount.formattedShekelAmount)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .strikethrough(debt.isFullyRepaid)
            }
            .environment(\.layoutDirection, appLanguage.layoutDirection)

            Text(debt.direction.title(for: appLanguage))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(debt.direction == .owedToMe ? .green : .orange)
                .strikethrough(debt.isFullyRepaid)

            Text(appLanguage.text(
                he: "מקורי: \(debt.originalAmount.formattedShekelAmount) · הוחזר: \(debt.repaidAmount.formattedShekelAmount)",
                en: "Original: \(debt.originalAmount.formattedShekelAmount) · Repaid: \(debt.repaidAmount.formattedShekelAmount)"
            ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .strikethrough(debt.isFullyRepaid)

            Text(appLanguage.text(
                he: "נותר: \(debt.remainingAmount.formattedShekelAmount) · \(debt.statusText(for: appLanguage))",
                en: "Remaining: \(debt.remainingAmount.formattedShekelAmount) · \(debt.statusText(for: appLanguage))"
            ))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(statusColor)
                .strikethrough(debt.isFullyRepaid)

            if !debt.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(debt.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .strikethrough(debt.isFullyRepaid)
            }

            Text(debt.date.expenseDateTimeText(for: appLanguage))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .strikethrough(debt.isFullyRepaid)
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .opacity(debt.isFullyRepaid ? 0.75 : 1)
        .padding(.vertical, 4)
    }
}

private struct SavingPastDataRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let saving: Saving
    var goal: SavingGoal?
    var isEditing = false
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(saving.kind.title(for: appLanguage))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(saving.kind == .withdrawal ? .red : .primary)

                    Spacer(minLength: 8)

                    Text(saving.amount.formattedShekelAmount)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(saving.kind == .withdrawal ? .red : .primary)
                }
                .environment(\.layoutDirection, appLanguage.layoutDirection)

                Text("\(saving.locationDisplayText(for: appLanguage)) · \(saving.date.expenseDateTimeText(for: appLanguage))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let goal {
                    Text(goal.name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !saving.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(saving.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isEditing {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(he: "ערוך חסכון", en: "Edit saving"))

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(he: "מחק חסכון", en: "Delete saving"))
            }
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .padding(.vertical, 4)
    }
}

private struct SalaryPastDataRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let entry: SalaryEntry
    var isEditing = false
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(appLanguage.text(he: "הכנסה", en: "Income"))
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(entry.amount.formattedShekelAmount)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .environment(\.layoutDirection, appLanguage.layoutDirection)

                Text(entry.createdAt.expenseDateTimeText(for: appLanguage))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isEditing {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(he: "ערוך הכנסה", en: "Edit income"))

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(appLanguage.text(he: "מחק הכנסה", en: "Delete income"))
            }
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .padding(.vertical, 4)
    }
}

private struct EditMonthlyTargetView: View {
    @Environment(\.appLanguage) private var appLanguage

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
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 18) {
            Text(appLanguage.text(he: "שנה יעד", en: "Change Goal"))
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Text(categoryName)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            AmountInputField(amountText: $targetText)
            .onChange(of: targetText) {
                errorMessage = nil
            }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    let trimmedValue = targetText.trimmingCharacters(in: .whitespacesAndNewlines)

                    if trimmedValue.isEmpty {
                        onSave(nil)
                        return
                    }

                    guard let target = Decimal(string: trimmedValue, locale: Locale(identifier: "en_US_POSIX")),
                          target > 0 else {
                        errorMessage = appLanguage.text(he: "יעד חייב להיות חיובי", en: "Goal must be positive")
                        return
                    }

                    onSave(target)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
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
    @Environment(\.appLanguage) private var appLanguage

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

        return Color(red: 1, green: 0.05, blue: 0.05)
    }

    private var daysLeftInMonth: Int {
        Calendar.current.daysLeftInMonth(from: selectedMonth)
    }

    var body: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 10) {
            if let target, target > 0, let targetPercentage, let remainingAmount {
                (
                    Text(appLanguage.text(he: "מתחילת החודש הוצאת על ", en: "Since the start of the month, you spent on "))
                    + Text(categoryName).foregroundColor(categoryNameColor).bold()
                    + Text(appLanguage.text(
                        he: " \(spent.formattedShekelAmount), שהם \(targetPercentage.formattedPercentText) מסך היעד החודשי שלך.",
                        en: " \(spent.formattedShekelAmount), which is \(targetPercentage.formattedPercentText) of your monthly goal."
                    ))
                )
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                if remainingAmount >= 0 {
                    Text(appLanguage.text(
                        he: "נותרו \(remainingAmount.formattedShekelAmount) להוצאה עד סוף החודש.",
                        en: "\(remainingAmount.formattedShekelAmount) remains until the end of the month."
                    ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                } else {
                    Text(appLanguage.text(
                        he: "יש חריגה של \((remainingAmount * -1).formattedShekelAmount) מהיעד החודשי.",
                        en: "You exceeded the monthly goal by \((remainingAmount * -1).formattedShekelAmount)."
                    ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 1, green: 0.05, blue: 0.05))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                }

                Text(appLanguage.text(
                    he: "נותרו \(daysLeftInMonth) ימים לסוף החודש.",
                    en: "\(daysLeftInMonth) days remain until the end of the month."
                ))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            } else {
                Text(appLanguage.text(
                    he: "סה״כ \(spent.formattedShekelAmount)",
                    en: "Total \(spent.formattedShekelAmount)"
                ))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                Text(appLanguage.text(he: "לא הוגדר יעד חודשי לקטגוריה הזו.", en: "No monthly goal set for this category."))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct MonthNavigationView: View {
    @Environment(\.appLanguage) private var appLanguage

    @Binding var selectedMonth: Date
    let maximumMonth: Date?
    @State private var isMonthPickerPresented = false

    init(selectedMonth: Binding<Date>, maximumMonth: Date? = nil) {
        _selectedMonth = selectedMonth
        self.maximumMonth = maximumMonth
    }

    var body: some View {
        HStack {
            Button {
                moveMonth(by: leftMonthOffset)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(isOffsetBlocked(leftMonthOffset))
            .accessibilityLabel(accessibilityLabel(for: leftMonthOffset))

            Spacer()

            Button {
                isMonthPickerPresented = true
            } label: {
                Text(selectedMonth.monthYearText(for: appLanguage))
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLanguage.text(he: "חודש", en: "Month"))
            .accessibilityValue(selectedMonth.monthYearText(for: appLanguage))
            .popover(isPresented: $isMonthPickerPresented) {
                DatePicker(appLanguage.text(he: "חודש", en: "Month"), selection: $selectedMonth, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .frame(minWidth: 320)
                    .onChange(of: selectedMonth) {
                        clampSelectedMonthToMaximum()
                    }
                    .environment(\.layoutDirection, appLanguage.layoutDirection)
                    .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            Button {
                moveMonth(by: rightMonthOffset)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(isOffsetBlocked(rightMonthOffset))
            .accessibilityLabel(accessibilityLabel(for: rightMonthOffset))
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var leftMonthOffset: Int {
        appLanguage == .he ? 1 : -1
    }

    private var rightMonthOffset: Int {
        appLanguage == .he ? -1 : 1
    }

    private func moveMonth(by value: Int) {
        guard !isOffsetBlocked(value) else {
            return
        }

        selectedMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) ?? selectedMonth
        clampSelectedMonthToMaximum()
    }

    private func isOffsetBlocked(_ value: Int) -> Bool {
        guard let maximumMonth,
              let candidateMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) else {
            return false
        }

        return Calendar.current.normalizedMonthDate(for: candidateMonth) > Calendar.current.normalizedMonthDate(for: maximumMonth)
    }

    private func clampSelectedMonthToMaximum() {
        guard let maximumMonth else {
            return
        }

        let maxMonth = Calendar.current.normalizedMonthDate(for: maximumMonth)
        if Calendar.current.normalizedMonthDate(for: selectedMonth) > maxMonth {
            selectedMonth = maxMonth
        }
    }

    private func accessibilityLabel(for offset: Int) -> String {
        offset > 0
            ? appLanguage.text(he: "חודש הבא", en: "Next Month")
            : appLanguage.text(he: "חודש קודם", en: "Previous Month")
    }
}

private struct ExpenseDetailRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let expense: Expense

    private var displayName: String {
        let trimmedName = expense.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? expense.displayCategoryName(for: appLanguage) : trimmedName
    }

    var body: some View {
        HStack(spacing: 12) {
            if expense.source == .backfill {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.red)
                    .frame(width: 26)
            }

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(expense.source == .backfill ? .red : .primary)

                Text("\(expense.date.expenseDateTimeText(for: appLanguage)) - \(expense.netAmount.formattedShekelAmount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(expense.source == .backfill ? .red.opacity(0.8) : .secondary)

                if let refundSummary = expense.refundSummaryText(for: appLanguage) {
                    Text(refundSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(expense.refundStatus == .full ? .green : .orange)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
        .padding(.vertical, 4)
    }
}

private struct ExpenseEditableRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let expense: Expense
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var displayName: String {
        let trimmedName = expense.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? expense.displayCategoryName(for: appLanguage) : trimmedName
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(expense.source == .backfill ? .red : .primary)

                Text("\(expense.netAmount.formattedShekelAmount) · \(expense.date.monthYearText(for: appLanguage))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(expense.source == .backfill ? .red.opacity(0.8) : .secondary)

                if let refundSummary = expense.refundSummaryText(for: appLanguage) {
                    Text(refundSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(expense.refundStatus == .full ? .green : .orange)
                }
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(appLanguage.text(he: "ערוך הוצאה", en: "Edit expense"))

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(appLanguage.text(he: "מחק הוצאה", en: "Delete expense"))
        }
        .padding(.vertical, 4)
    }
}

private enum ExpenseRefundEditMode: String, CaseIterable, Identifiable {
    case none
    case partial
    case full

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .none:
            return language.text(he: "ללא החזר", en: "No Refund")
        case .partial:
            return language.text(he: "החזר חלקי", en: "Partial Refund")
        case .full:
            return language.text(he: "החזר מלא", en: "Full Refund")
        }
    }
}

private struct EditExpenseView: View {
    @Environment(\.appLanguage) private var appLanguage

    let expense: Expense
    let categories: [ExpenseCategory]
    let lockedMonth: Date
    let onSave: (Expense) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var amountText: String
    @State private var date: Date
    @State private var refundMode: ExpenseRefundEditMode
    @State private var refundedAmountText: String
    @State private var selectedCategoryId: String?
    @State private var selectedCurrency: CurrencyOption
    @State private var isCurrencyPickerPresented = false
    @State private var errorMessage: String?

    init(
        expense: Expense,
        categories: [ExpenseCategory],
        lockedMonth: Date,
        onSave: @escaping (Expense) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.expense = expense
        self.categories = categories
        self.lockedMonth = lockedMonth
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: expense.name ?? "")
        let primaryCurrency = Storage.loadCurrency()
        let originalCurrency = CurrencyOption.option(for: expense.originalCurrencyCode) ?? primaryCurrency
        _amountText = State(initialValue: expense.originalAmount.plainString)
        _date = State(initialValue: expense.date)
        _refundMode = State(initialValue: {
            switch expense.refundStatus {
            case .none:
                return .none
            case .partial:
                return .partial
            case .full:
                return .full
            }
        }())
        _refundedAmountText = State(initialValue: expense.refundedAmount > 0 ? expense.refundedAmount.plainString : "")
        _selectedCategoryId = State(initialValue: expense.categoryId)
        _selectedCurrency = State(initialValue: originalCurrency)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var parsedRefundedAmount: Decimal? {
        Decimal(string: refundedAmountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var primaryCurrency: CurrencyOption {
        Storage.loadCurrency()
    }

    private var conversion: CurrencyConversionResult? {
        guard let parsedAmount, selectedCurrency != primaryCurrency else {
            return nil
        }

        return CurrencyExchangeService.convert(amount: parsedAmount, from: selectedCurrency, to: primaryCurrency)
    }

    private var convertedAmount: Decimal {
        guard let parsedAmount else {
            return 0
        }

        return selectedCurrency == primaryCurrency ? parsedAmount : (conversion?.convertedAmount ?? parsedAmount)
    }

    private var effectiveRefundedAmount: Decimal {
        guard convertedAmount > 0 else {
            return 0
        }

        switch refundMode {
        case .none:
            return 0
        case .partial:
            return parsedRefundedAmount ?? 0
        case .full:
            return convertedAmount
        }
    }

    private var netAmount: Decimal {
        guard convertedAmount > 0 else {
            return 0
        }

        return max(convertedAmount - effectiveRefundedAmount, 0)
    }

    private var canSave: Bool {
        guard let parsedAmount, parsedAmount > 0, selectedCategory != nil else {
            return false
        }

        switch refundMode {
        case .none, .full:
            return true
        case .partial:
            return effectiveRefundedAmount > 0 && effectiveRefundedAmount < convertedAmount
        }
    }

    private var selectedCategory: ExpenseCategory? {
        categories.first { $0.id == selectedCategoryId } ?? categories.first
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(appLanguage.text(he: "עריכת הוצאה", en: "Edit Expense"))
                .font(.title3.bold())

            Text(lockedMonth.monthYearText(for: appLanguage))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            DatePicker(appLanguage.text(he: "תאריך ושעה", en: "Date and Time"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            TextField(appLanguage.text(he: "הערה", en: "Note"), text: $name)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            AmountInputField(
                amountText: $amountText,
                selectedCurrency: $selectedCurrency,
                onCurrencyButtonTapped: { isCurrencyPickerPresented = true }
            )
            .onChange(of: selectedCurrency) {
                errorMessage = nil
            }

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
                Text(appLanguage.text(he: "החזר", en: "Refund"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                Picker(appLanguage.text(he: "החזר", en: "Refund"), selection: $refundMode) {
                    ForEach(ExpenseRefundEditMode.allCases) { mode in
                        Text(mode.title(for: appLanguage)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: refundMode) {
                    errorMessage = nil
                }

                if refundMode == .partial {
                    AmountInputField(
                        amountText: $refundedAmountText,
                        placeholder: appLanguage.text(he: "סכום שהוחזר", en: "Refunded Amount")
                    )
                    .onChange(of: refundedAmountText) {
                        errorMessage = nil
                    }
                }

                Button(appLanguage.text(he: "החזר מלא", en: "Full Refund")) {
                    if convertedAmount > 0 {
                        refundMode = .full
                        refundedAmountText = convertedAmount.plainString
                        errorMessage = nil
                    }
                }
                .buttonStyle(.bordered)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)

                Text(appLanguage.text(
                    he: "סכום נטו: \(netAmount.formattedShekelAmount)",
                    en: "Net Amount: \(netAmount.formattedShekelAmount)"
                ))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }

            if categories.count > 1 {
                Picker(appLanguage.text(he: "קטגוריה", en: "Category"), selection: selectedCategoryBinding) {
                    ForEach(categories) { category in
                        Text(category.displayName(for: appLanguage)).tag(Optional(category.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור שינויים", en: "Save Changes")) {
                    guard let amount = parsedAmount, amount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    guard let category = selectedCategory else {
                        errorMessage = appLanguage.text(he: "צריך לבחור קטגוריה", en: "Choose a category")
                        return
                    }

                    let refundedAmount: Decimal
                    switch refundMode {
                    case .none:
                        refundedAmount = 0
                    case .partial:
                        refundedAmount = parsedRefundedAmount ?? 0
                    case .full:
                        refundedAmount = amount
                    }

                    if refundMode == .partial {
                        guard refundedAmount > 0 else {
                            errorMessage = appLanguage.text(
                                he: "הסכום חייב להיות גדול מ־0",
                                en: "Amount must be greater than 0"
                            )
                            return
                        }

                        guard refundedAmount < amount else {
                            errorMessage = appLanguage.text(
                                he: "סכום ההחזר לא יכול להיות גדול מסכום ההוצאה",
                                en: "Refund amount cannot exceed the expense amount"
                            )
                            return
                        }
                    }

                    guard refundedAmount <= amount else {
                        errorMessage = appLanguage.text(
                            he: "סכום ההחזר לא יכול להיות גדול מסכום ההוצאה",
                            en: "Refund amount cannot exceed the expense amount"
                        )
                        return
                    }

                    if selectedCurrency != primaryCurrency {
                        guard !ExpenseCalculations.requiresHistoricalExchangeRate(
                            expenseDate: date,
                            sourceCurrencyCode: selectedCurrency.code,
                            primaryCurrencyCode: primaryCurrency.code
                        ) else {
                            errorMessage = appLanguage.text(
                                he: "לא ניתן לשמור הוצאה בדיעבד במטבע זר בלי שער היסטורי לתאריך ההוצאה",
                                en: "Past foreign-currency expenses require a historical exchange rate for the expense date"
                            )
                            return
                        }

                        guard let conversion else {
                            errorMessage = appLanguage.text(
                                he: "לא ניתן להמיר את המטבע שנבחר",
                                en: "Could not convert the selected currency"
                            )
                            return
                        }

                        onSave(expense.updated(
                            category: category,
                            amount: conversion.convertedAmount,
                            refundedAmount: refundedAmount,
                            date: date,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            originalAmount: amount,
                            originalCurrencyCode: selectedCurrency.code,
                            exchangeRate: conversion.exchangeRate,
                            exchangeRateDate: conversion.exchangeRateDate,
                            convertedAmount: conversion.convertedAmount,
                            convertedCurrencyCode: primaryCurrency.code
                        ))
                        return
                    }

                    onSave(expense.updated(
                        category: category,
                        amount: amount,
                        refundedAmount: refundedAmount,
                        date: date,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        originalAmount: amount,
                        originalCurrencyCode: primaryCurrency.code,
                        exchangeRate: 1,
                        exchangeRateDate: date,
                        convertedAmount: amount,
                        convertedCurrencyCode: primaryCurrency.code
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .confirmationDialog(
            appLanguage.text(he: "בחר מטבע", en: "Choose Currency"),
            isPresented: $isCurrencyPickerPresented,
            titleVisibility: .visible
        ) {
            ForEach(CurrencyOption.allCases) { currency in
                Button(currency.selectorTitle) {
                    selectedCurrency = currency
                }
            }
        }
    }

    private var selectedCategoryBinding: Binding<String?> {
        Binding(
            get: { selectedCategoryId ?? categories.first?.id },
            set: { selectedCategoryId = $0 }
        )
    }
}

private struct HistoricalExpenseEditorView: View {
    @Environment(\.appLanguage) private var appLanguage

    let categories: [ExpenseCategory]
    let selectedMonth: Date
    var allowsDateTimeSelection = false
    let onSave: (Expense) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var amountText = ""
    @State private var date: Date
    @State private var selectedCategoryId: String?
    @State private var selectedCurrency = Storage.loadCurrency()
    @State private var isCurrencyPickerPresented = false
    @State private var errorMessage: String?

    init(
        categories: [ExpenseCategory],
        selectedMonth: Date,
        allowsDateTimeSelection: Bool = false,
        onSave: @escaping (Expense) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.categories = categories
        self.selectedMonth = selectedMonth
        self.allowsDateTimeSelection = allowsDateTimeSelection
        self.onSave = onSave
        self.onCancel = onCancel
        _date = State(initialValue: Calendar.current.normalizedMonthDate(for: selectedMonth))
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var selectedCategory: ExpenseCategory? {
        categories.first { $0.id == selectedCategoryId } ?? categories.first
    }

    private var canSave: Bool {
        (parsedAmount ?? 0) > 0 && selectedCategory != nil
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(appLanguage.text(he: "הוסף הוצאה לחודש", en: "Add Expense to Month"))
                .font(.title3.bold())

            Text(selectedMonth.monthYearText(for: appLanguage))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if allowsDateTimeSelection {
                DatePicker(appLanguage.text(he: "תאריך ושעה", en: "Date and Time"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            TextField(appLanguage.text(he: "שם ההוצאה", en: "Expense name"), text: $name)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            AmountInputField(
                amountText: $amountText,
                selectedCurrency: $selectedCurrency,
                onCurrencyButtonTapped: { isCurrencyPickerPresented = true }
            )
                .onChange(of: amountText) {
                    errorMessage = nil
                }
                .onChange(of: selectedCurrency) {
                    errorMessage = nil
                }

            Picker(appLanguage.text(he: "קטגוריה", en: "Category"), selection: selectedCategoryBinding) {
                ForEach(categories) { category in
                    Text(category.displayName(for: appLanguage)).tag(Optional(category.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let amount = parsedAmount, amount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    guard let category = selectedCategory else {
                        errorMessage = appLanguage.text(he: "צריך לבחור קטגוריה", en: "Choose a category")
                        return
                    }

                    let expenseDate = allowsDateTimeSelection ? date : Calendar.current.normalizedMonthDate(for: selectedMonth)
                    let primaryCurrency = Storage.loadCurrency()

                    if selectedCurrency != primaryCurrency {
                        guard !ExpenseCalculations.requiresHistoricalExchangeRate(
                            expenseDate: expenseDate,
                            sourceCurrencyCode: selectedCurrency.code,
                            primaryCurrencyCode: primaryCurrency.code
                        ) else {
                            errorMessage = appLanguage.text(
                                he: "לא ניתן להוסיף הוצאה בדיעבד במטבע זר בלי שער היסטורי לתאריך ההוצאה",
                                en: "Past foreign-currency expenses require a historical exchange rate for the expense date"
                            )
                            return
                        }

                        guard let conversion = CurrencyExchangeService.convert(amount: amount, from: selectedCurrency, to: primaryCurrency) else {
                            errorMessage = appLanguage.text(
                                he: "לא ניתן להמיר את המטבע שנבחר",
                                en: "Could not convert the selected currency"
                            )
                            return
                        }

                        onSave(Expense(
                            categoryId: category.id,
                            categoryName: category.name,
                            amount: conversion.convertedAmount,
                            createdAt: Date(),
                            date: expenseDate,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            source: .backfill,
                            originalAmount: amount,
                            originalCurrencyCode: selectedCurrency.code,
                            exchangeRate: conversion.exchangeRate,
                            exchangeRateDate: conversion.exchangeRateDate,
                            convertedAmount: conversion.convertedAmount,
                            convertedCurrencyCode: primaryCurrency.code
                        ))
                        return
                    }

                    onSave(Expense(
                        categoryId: category.id,
                        categoryName: category.name,
                        amount: amount,
                        createdAt: Date(),
                        date: expenseDate,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        source: .backfill,
                        originalAmount: amount,
                        originalCurrencyCode: primaryCurrency.code,
                        exchangeRate: 1,
                        exchangeRateDate: expenseDate,
                        convertedAmount: amount,
                        convertedCurrencyCode: primaryCurrency.code
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .confirmationDialog(
            appLanguage.text(he: "בחר מטבע", en: "Choose Currency"),
            isPresented: $isCurrencyPickerPresented,
            titleVisibility: .visible
        ) {
            ForEach(CurrencyOption.allCases) { currency in
                Button(currency.selectorTitle) {
                    selectedCurrency = currency
                }
            }
        }
        .onAppear {
            selectedCategoryId = categories.first?.id
        }
    }

    private var selectedCategoryBinding: Binding<String?> {
        Binding(
            get: { selectedCategoryId ?? categories.first?.id },
            set: { selectedCategoryId = $0 }
        )
    }
}

private struct SalaryEntryEditorView: View {
    @Environment(\.appLanguage) private var appLanguage

    let entry: SalaryEntry?
    let selectedMonth: Date
    var allowsMonthSelection = false
    let onSave: (SalaryEntry) -> Void
    let onCancel: () -> Void

    @State private var amountText: String
    @State private var month: Date
    @State private var errorMessage: String?

    init(
        entry: SalaryEntry?,
        selectedMonth: Date,
        allowsMonthSelection: Bool = false,
        onSave: @escaping (SalaryEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.entry = entry
        self.selectedMonth = selectedMonth
        self.allowsMonthSelection = allowsMonthSelection
        self.onSave = onSave
        self.onCancel = onCancel
        _amountText = State(initialValue: entry?.amount.plainString ?? "")
        _month = State(initialValue: entry?.monthDate ?? selectedMonth)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        (parsedAmount ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(entry == nil
                ? appLanguage.text(he: "הוסף הכנסה", en: "Add Income")
                : appLanguage.text(he: "ערוך הכנסה", en: "Edit Income"))
                .font(.title3.bold())

            if allowsMonthSelection {
                MonthNavigationView(selectedMonth: $month)
            } else {
                Text(month.monthYearText(for: appLanguage))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            AmountInputField(amountText: $amountText)
                .onChange(of: amountText) {
                    errorMessage = nil
                }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let amount = parsedAmount, amount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    let components = Calendar.current.dateComponents([.year, .month], from: month)
                    guard let year = components.year, let monthNumber = components.month else {
                        errorMessage = appLanguage.text(he: "חודש לא תקין", en: "Invalid month")
                        return
                    }

                    onSave(SalaryEntry(
                        id: entry?.id ?? UUID(),
                        year: year,
                        month: monthNumber,
                        amount: amount,
                        createdAt: entry?.createdAt ?? Date()
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
    }
}

private struct SavingEditorView: View {
    @Environment(\.appLanguage) private var appLanguage

    let saving: Saving?
    let selectedMonth: Date
    var allowsDateTimeSelection = false
    var goals: [SavingGoal] = []
    var savings: [Saving] = []
    let onSave: (Saving) -> Void
    let onCancel: () -> Void

    @State private var amountText: String
    @State private var kind: SavingKind
    @State private var location: SavingLocation
    @State private var customLocation: String
    @State private var date: Date
    @State private var note: String
    @State private var selectedGoalId: UUID?
    @State private var errorMessage: String?

    init(
        saving: Saving?,
        selectedMonth: Date,
        allowsDateTimeSelection: Bool = false,
        goals: [SavingGoal] = [],
        savings: [Saving] = [],
        onSave: @escaping (Saving) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.saving = saving
        self.selectedMonth = selectedMonth
        self.allowsDateTimeSelection = allowsDateTimeSelection
        self.goals = goals
        self.savings = savings
        self.onSave = onSave
        self.onCancel = onCancel
        _amountText = State(initialValue: saving?.amount.plainString ?? "")
        _kind = State(initialValue: saving?.kind ?? .deposit)
        _location = State(initialValue: saving?.location ?? .bank)
        _customLocation = State(initialValue: saving?.customLocation ?? "")
        _date = State(initialValue: saving?.date ?? Calendar.current.normalizedMonthDate(for: selectedMonth))
        _note = State(initialValue: saving?.note ?? "")
        _selectedGoalId = State(initialValue: saving?.kind == .withdrawal ? saving?.goalId : (saving?.goalId ?? goals.first?.id))
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        guard (parsedAmount ?? 0) > 0 else {
            return false
        }

        return kind == .deposit || (hasWithdrawalSources && selectedAvailableBalance > 0 && (parsedAmount ?? 0) <= selectedAvailableBalance)
    }

    private var availableLocationOptions: [SavingLocation] {
        guard kind == .withdrawal else {
            return SavingLocation.allCases
        }

        return SavingLocation.withdrawalOptions.filter { Saving.hasPositiveBalance(for: savings, location: $0) }
    }

    private var availableGoals: [SavingGoal] {
        guard kind == .withdrawal else {
            return goals
        }

        return goals.filter { Saving.balance(for: savings, goalId: $0.id) > 0 }
    }

    private var hasWithdrawalSources: Bool {
        kind != .withdrawal || !availableLocationOptions.isEmpty || !availableGoals.isEmpty
    }

    private var selectedAvailableBalance: Decimal {
        guard kind == .withdrawal else {
            return Saving.balance(for: savings)
        }

        if let selectedGoalId {
            return Saving.balance(for: savings, goalId: selectedGoalId)
        }

        return Saving.balance(for: savings, location: location)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(saving == nil
                ? appLanguage.text(he: "הוסף חסכון", en: "Add Saving")
                : appLanguage.text(he: "ערוך חסכון", en: "Edit Saving"))
                .font(.title3.bold())

            Text(selectedMonth.monthYearText(for: appLanguage))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if allowsDateTimeSelection {
                DatePicker(appLanguage.text(he: "תאריך ושעה", en: "Date and Time"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            Picker(appLanguage.text(he: "סוג", en: "Type"), selection: $kind) {
                Text(SavingKind.deposit.title(for: appLanguage)).tag(SavingKind.deposit)
                Text(SavingKind.withdrawal.title(for: appLanguage)).tag(SavingKind.withdrawal)
            }
            .pickerStyle(.segmented)

            if kind == .withdrawal && hasWithdrawalSources {
                Text(appLanguage.text(
                    he: "זמין למשיכה: \(selectedAvailableBalance.formattedShekelAmount)",
                    en: "Available to withdraw: \(selectedAvailableBalance.formattedShekelAmount)"
                ))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }

            AmountInputField(amountText: $amountText)
                .onChange(of: amountText) {
                    errorMessage = nil
                }

            if !hasWithdrawalSources {
                Text(appLanguage.text(he: "אין חסכונות זמינים למשיכה", en: "No savings available for withdrawal"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            } else if kind != .withdrawal || !availableLocationOptions.isEmpty {
                VStack(alignment: appLanguage.horizontalAlignment, spacing: 6) {
                    Text(kind == .withdrawal
                        ? appLanguage.text(he: "מאיפה למשוך?", en: "Withdraw from")
                        : appLanguage.text(he: "איפה החסכון?", en: "Where is the saving held?"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

                    Picker(kind == .withdrawal
                        ? appLanguage.text(he: "מאיפה למשוך?", en: "Withdraw from")
                        : appLanguage.text(he: "איפה החסכון?", en: "Where is the saving held?"), selection: $location) {
                        ForEach(availableLocationOptions) { location in
                            Text(location.title(for: appLanguage)).tag(location)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if kind != .withdrawal && location == .other {
                TextField(appLanguage.text(he: "איפה החסכון?", en: "Where is the saving held?"), text: $customLocation)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                    .font(.headline)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if !goals.isEmpty && hasWithdrawalSources {
                Picker(kind == .withdrawal
                    ? appLanguage.text(he: "יעד חסכון", en: "Saving Goal")
                    : appLanguage.text(he: "האם החסכון משויך ליעד?", en: "Is this saving linked to a goal?"), selection: selectedGoalBinding) {
                    if kind != .withdrawal || !availableLocationOptions.isEmpty {
                        Text(kind == .withdrawal
                            ? appLanguage.text(he: "לפי מיקום", en: "By location")
                            : appLanguage.text(he: "לא, חסכון כללי", en: "No, general saving")).tag(Optional<UUID>.none)
                    }

                    ForEach(availableGoals) { goal in
                        Text(goal.name).tag(Optional(goal.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            TextField(appLanguage.text(he: "שם / הערה", en: "Name / note"), text: $note)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let amount = parsedAmount, amount > 0 else {
                        errorMessage = appLanguage.text(he: "צריך סכום תקין", en: "Enter a valid amount")
                        return
                    }

                    guard kind == .deposit || hasWithdrawalSources else {
                        errorMessage = appLanguage.text(
                            he: "אין חסכונות זמינים למשיכה",
                            en: "No savings available for withdrawal"
                        )
                        return
                    }

                    guard kind == .deposit || amount <= selectedAvailableBalance else {
                        errorMessage = appLanguage.text(
                            he: "לא ניתן למשוך יותר מהסכום הזמין",
                            en: "Cannot withdraw more than the available amount"
                        )
                        return
                    }

                    onSave(Saving(
                        id: saving?.id ?? UUID(),
                        amount: amount,
                        kind: kind,
                        location: location,
                        customLocation: customLocation.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: allowsDateTimeSelection ? date : Calendar.current.normalizedMonthDate(for: selectedMonth),
                        note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                        goalId: selectedGoalId,
                        createdAt: saving?.createdAt ?? Date()
                    ))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            normalizeWithdrawalSourceSelection()
        }
        .onChange(of: kind) {
            normalizeWithdrawalSourceSelection()
        }
    }

    private var selectedGoalBinding: Binding<UUID?> {
        Binding(
            get: { selectedGoalId },
            set: { selectedGoalId = $0 }
        )
    }

    private func normalizeWithdrawalSourceSelection() {
        guard kind == .withdrawal else {
            return
        }

        if let selectedGoalId, Saving.balance(for: savings, goalId: selectedGoalId) <= 0 {
            self.selectedGoalId = nil
        }

        if !availableLocationOptions.contains(location),
           let firstLocation = availableLocationOptions.first {
            location = firstLocation
        } else if availableLocationOptions.isEmpty,
                  let firstGoal = availableGoals.first {
            selectedGoalId = firstGoal.id
        }
    }
}

private struct EditRecurringExpenseView: View {
    @Environment(\.appLanguage) private var appLanguage

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
            Text(appLanguage.text(he: "עריכת הוצאה חוזרת", en: "Edit Recurring Expense"))
                .font(.title3.bold())

            TextField(appLanguage.text(he: "שם הוצאה", en: "Expense name"), text: $name)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.headline)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: name) {
                    errorMessage = nil
                }

            AmountInputField(amountText: $amountText)
                .onChange(of: amountText) {
                    errorMessage = nil
                }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    guard let amount = parsedAmount else {
                        errorMessage = appLanguage.text(he: "סכום לא תקין", en: "Invalid amount")
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
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
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
    @Environment(\.appLanguage) private var appLanguage

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
            Text(appLanguage.text(he: "עריכת קטגוריה", en: "Edit Category"))
                .font(.title3.bold())

            TextField(appLanguage.text(he: "שם קטגוריה", en: "Category name"), text: $categoryName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                .font(.title3)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: categoryName) {
                    errorMessage = nil
                }

            CategoryAppearancePicker(
                selectedSystemImageName: $selectedSystemImageName,
                selectedTintName: $selectedTintName
            )

            AmountInputField(amountText: $monthlyTargetText)
                .onChange(of: monthlyTargetText) {
                    errorMessage = nil
                }

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .localizedFieldMessage(appLanguage)
                .frame(height: 18)

            HStack(spacing: 12) {
                Button(appLanguage.text(he: "ביטול", en: "Cancel")) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(appLanguage.text(he: "שמור", en: "Save")) {
                    if !monthlyTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       monthlyTarget == nil {
                        errorMessage = appLanguage.text(he: "יעד חייב להיות חיובי", en: "Goal must be positive")
                        return
                    }

                    errorMessage = onSave(
                        category,
                        categoryNameForSave,
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
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            syncLocalizedCategoryName()
        }
        .onChange(of: appLanguage) {
            syncLocalizedCategoryName()
        }
    }

    private var isDefaultCategory: Bool {
        ExpenseCategory.localizedDefaultName(for: category.id, language: .he) != nil
    }

    private var localizedDefaultNames: Set<String> {
        [
            ExpenseCategory.localizedDefaultName(for: category.id, language: .he),
            ExpenseCategory.localizedDefaultName(for: category.id, language: .en),
            category.name
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .reduce(into: Set<String>()) { names, name in
            names.insert(name)
        }
    }

    private var categoryNameForSave: String {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isDefaultCategory,
           trimmedName == category.displayName(for: appLanguage) {
            return category.name
        }

        return categoryName
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

    private func syncLocalizedCategoryName() {
        guard isDefaultCategory else {
            return
        }

        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        if localizedDefaultNames.contains(trimmedName) {
            categoryName = category.displayName(for: appLanguage)
        }
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
    @Environment(\.appLanguage) private var appLanguage

    @Binding var selectedSystemImageName: String
    @Binding var selectedTintName: String
    @State private var isIconPickerPresented = false

    var body: some View {
        VStack(spacing: 14) {
            Button {
                selectedSystemImageName = selectedSystemImageName.safeCategorySystemImageName
                isIconPickerPresented = true
            } label: {
                CategoryIconView(
                    systemImageName: selectedSystemImageName.safeCategorySystemImageName,
                    tint: selectedTintName.categoryTint,
                    size: 34
                )
                .frame(width: 66, height: 66)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedTintName.categoryTint.opacity(0.55), lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appLanguage.text(he: "בחר אייקון", en: "Choose Icon"))

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
        .onAppear {
            selectedSystemImageName = selectedSystemImageName.safeCategorySystemImageName
        }
        .sheet(isPresented: $isIconPickerPresented) {
            CategorySymbolPickerSheet(
                selectedSystemImageName: $selectedSystemImageName,
                tintName: selectedTintName,
                onClose: {
                    isIconPickerPresented = false
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(520)])
        }
    }
}

private struct CategorySymbolPickerSheet: View {
    @Environment(\.appLanguage) private var appLanguage

    @Binding var selectedSystemImageName: String
    let tintName: String
    let onClose: () -> Void

    @State private var searchText = ""

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleGroups: [CategoryAppearanceSymbolGroup] {
        let query = trimmedSearchText.lowercased()

        guard !query.isEmpty else {
            return CategoryAppearanceOption.symbolGroups
        }

        return CategoryAppearanceOption.symbolGroups.compactMap { group in
            let groupMatches = group.titleHE.lowercased().contains(query)
                || group.titleEN.lowercased().contains(query)
                || group.searchKeywords.contains { keyword in
                    keyword.lowercased().contains(query)
                }
            let filteredSymbols = group.symbols.filter { symbol in
                groupMatches || symbol.lowercased().contains(query)
            }

            guard !filteredSymbols.isEmpty else {
                return nil
            }

            return CategoryAppearanceSymbolGroup(
                titleHE: group.titleHE,
                titleEN: group.titleEN,
                searchKeywords: group.searchKeywords,
                symbols: filteredSymbols
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField(appLanguage.text(he: "חיפוש אייקון", en: "Search Icon"), text: $searchText)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)

                ScrollView {
                    LazyVStack(alignment: appLanguage.horizontalAlignment, spacing: 18) {
                        if visibleGroups.isEmpty {
                            Text(appLanguage.text(he: "לא נמצאו אייקונים", en: "No icons found"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        }

                        ForEach(visibleGroups) { group in
                            VStack(alignment: appLanguage.horizontalAlignment, spacing: 8) {
                                Text(group.title(for: appLanguage))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                                    .padding(.horizontal, 16)

                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 10), count: 6), spacing: 10) {
                                    ForEach(group.symbols, id: \.self) { systemImageName in
                                        Button {
                                            selectedSystemImageName = systemImageName
                                            onClose()
                                        } label: {
                                            CategoryAppearanceOptionButton(
                                                value: systemImageName,
                                                selectedValue: selectedSystemImageName.safeCategorySystemImageName,
                                                tintName: tintName
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(systemImageName)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle(appLanguage.text(he: "בחר אייקון", en: "Choose Icon"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }
            }
        }
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
            Image(systemName: systemImageName.safeCategorySystemImageName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

private struct BackfillExpenseView: View {
    @Environment(\.appLanguage) private var appLanguage

    let categories: [ExpenseCategory]
    let onSave: (BackfillExpenseMode, Decimal, CurrencyOption, Date, Int, String?, String?, String) -> String?
    let onClose: () -> Void

    @State private var mode: BackfillExpenseMode = .oneTime
    @State private var expenseName = ""
    @State private var amountText = ""
    @State private var selectedCurrency = Storage.loadCurrency()
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
        let hasValidAmount = (parsedAmount ?? 0) > 0
        let hasCategory = categoryMode == .existing
            ? selectedCategoryId != nil
            : !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return hasValidAmount && hasCategory && monthCount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(appLanguage.text(he: "סוג הוצאה", en: "Expense type"), selection: $mode) {
                        ForEach(BackfillExpenseMode.allCases) { option in
                            Text(option.title(for: appLanguage)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(mode.detailsTitle(for: appLanguage)) {
                    TextField(appLanguage.text(he: "שם ההוצאה", en: "Expense name"), text: $expenseName)
                        .keyboardType(.default)
                        .textInputAutocapitalization(.never)
                        .localizedTextInput(appLanguage)
                        .onChange(of: expenseName) {
                            errorMessage = nil
                        }

                    AmountInputField(amountText: $amountText)
                        .onChange(of: amountText) {
                            errorMessage = nil
                        }

                    Picker(appLanguage.text(he: "מטבע", en: "Currency"), selection: $selectedCurrency) {
                        ForEach(CurrencyOption.allCases) { currency in
                            Text(currency.selectorTitle).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedCurrency) {
                        errorMessage = nil
                    }

                    if selectedCurrency != Storage.loadCurrency() {
                        Text(appLanguage.text(
                            he: "מטבע זר בדיעבד יישמר רק כשיש שער היסטורי לתאריך ההוצאה.",
                            en: "Past foreign-currency expenses require a historical rate for the expense date."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    MonthNavigationView(selectedMonth: $selectedMonth)

                    if mode == .recurring {
                        Stepper(value: $monthCount, in: 1...120) {
                            Text(appLanguage.text(he: "\(monthCount) חודשים", en: "\(monthCount) months"))
                        }
                    }
                }

                Section(appLanguage.text(he: "שיוך לקטגוריה", en: "Category Assignment")) {
                    Picker(appLanguage.text(he: "אפשרות", en: "Option"), selection: $categoryMode) {
                        Text(appLanguage.text(he: "קטגוריה קיימת", en: "Existing Category")).tag(RecurringCategoryMode.existing)
                        Text(appLanguage.text(he: "קטגוריה חדשה", en: "New Category")).tag(RecurringCategoryMode.new)
                    }
                    .pickerStyle(.segmented)

                    if categoryMode == .existing, !categories.isEmpty {
                        Picker(appLanguage.text(he: "קטגוריה", en: "Category"), selection: selectedCategoryBinding) {
                            ForEach(categories) { category in
                                Text(category.displayName(for: appLanguage)).tag(Optional(category.id))
                            }
                        }
                    } else {
                        TextField(appLanguage.text(he: "שם קטגוריה חדשה", en: "New category name"), text: $newCategoryName)
                            .keyboardType(.default)
                            .textInputAutocapitalization(.never)
                            .localizedTextInput(appLanguage)
                            .onChange(of: newCategoryName) {
                                errorMessage = nil
                            }
                    }
                }

                if mode == .recurring {
                    Section(appLanguage.text(he: "האם להמשיך להוסיף לקטגוריה שנבחרה?", en: "Continue adding to the selected category?")) {
                        Picker(appLanguage.text(he: "המשך הוספה", en: "Continue Adding"), selection: $shouldContinueAddingToCategory) {
                            Text(appLanguage.text(he: "כן", en: "Yes")).tag(true)
                            Text(appLanguage.text(he: "לא", en: "No")).tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .localizedFieldMessage(appLanguage)
                    }
                }
            }
            .navigationTitle(appLanguage.text(he: "הוסף הוצאה בדיעבד", en: "Add Past Expense"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(appLanguage.text(he: "הוסף", en: "Add")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
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
            errorMessage = appLanguage.text(he: "סכום לא תקין", en: "Invalid amount")
            return
        }

        errorMessage = onSave(
            mode,
            amount,
            selectedCurrency,
            Calendar.current.normalizedMonthDate(for: selectedMonth),
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

private struct AddExpenseModalView: View {
    @Environment(\.appLanguage) private var appLanguage

    let categories: [ExpenseCategory]
    let initialIsRecurring: Bool
    let initialDate: Date
    let onSave: (String, Decimal, Bool, Date, String?) -> String?
    let onCancel: () -> Void

    @State private var name = ""
    @State private var amountText = ""
    @State private var isRecurring: Bool
    @State private var expenseDate: Date
    @State private var selectedCategoryId: String?
    @State private var errorMessage: String?

    init(
        categories: [ExpenseCategory],
        initialIsRecurring: Bool = false,
        initialDate: Date = Date(),
        onSave: @escaping (String, Decimal, Bool, Date, String?) -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.categories = categories
        self.initialIsRecurring = initialIsRecurring
        self.initialDate = initialDate
        self.onSave = onSave
        self.onCancel = onCancel
        _isRecurring = State(initialValue: initialIsRecurring)
        _expenseDate = State(initialValue: initialDate)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private var canSave: Bool {
        (parsedAmount ?? 0) > 0
            && selectedCategoryId != nil
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(appLanguage.text(he: "הוסף הוצאה", en: "Add Expense"))
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 1)

                TextField(appLanguage.text(he: "שם ההוצאה", en: "Expense name"), text: $name)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                    .font(.headline)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: name) {
                        errorMessage = nil
                    }

                AmountInputField(amountText: $amountText)
                    .onChange(of: amountText) {
                        errorMessage = nil
                    }

                Picker(appLanguage.text(he: "סוג הוצאה", en: "Expense type"), selection: $isRecurring) {
                    Text(appLanguage.text(he: "חד פעמית", en: "One-time")).tag(false)
                    Text(appLanguage.text(he: "הוצאה חוזרת", en: "Recurring")).tag(true)
                }
                .pickerStyle(.segmented)

                DatePicker(appLanguage.text(he: "תאריך ושעה", en: "Date and Time"), selection: $expenseDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

                Picker(appLanguage.text(he: "קטגוריה", en: "Category"), selection: selectedCategoryBinding) {
                    ForEach(categories) { category in
                        Text(category.displayName(for: appLanguage)).tag(Optional(category.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

                Text(errorMessage ?? " ")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .localizedFieldMessage(appLanguage)
                    .frame(height: 18)

                Button {
                    guard let amount = parsedAmount else {
                        errorMessage = appLanguage.text(he: "סכום לא תקין", en: "Invalid amount")
                        return
                    }

                    errorMessage = onSave(name, amount, isRecurring, expenseDate, selectedCategoryId)
                } label: {
                    Text(appLanguage.text(he: "הוסף", en: "Add"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 14)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .onAppear {
            selectedCategoryId = categories.first?.id
        }
    }

    private var selectedCategoryBinding: Binding<String?> {
        Binding(
            get: { selectedCategoryId ?? categories.first?.id },
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

private struct RecurringExpenseModalView: View {
    @Environment(\.appLanguage) private var appLanguage

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
        VStack(spacing: 14) {
            Text(appLanguage.text(he: "הוסף הוצאה חוזרת", en: "Add Recurring Expense"))
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)

                TextField(appLanguage.text(he: "שם ההוצאה", en: "Expense name"), text: $name)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                    .font(.headline)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: name) {
                        errorMessage = nil
                    }

                AmountInputField(amountText: $amountText)
                    .onChange(of: amountText) {
                        errorMessage = nil
                    }

                Picker(appLanguage.text(he: "קטגוריה", en: "Category"), selection: $categoryMode) {
                    Text(appLanguage.text(he: "בחר קיימת", en: "Choose Existing")).tag(RecurringCategoryMode.existing)
                    Text(appLanguage.text(he: "צור חדשה", en: "Create New")).tag(RecurringCategoryMode.new)
                }
                .pickerStyle(.segmented)

                if categoryMode == .existing, !categories.isEmpty {
                    Picker(appLanguage.text(he: "בחר קטגוריה", en: "Choose Category"), selection: selectedCategoryBinding) {
                        ForEach(categories) { category in
                            Text(category.displayName(for: appLanguage)).tag(Optional(category.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    TextField(appLanguage.text(he: "שם קטגוריה חדשה", en: "New category name"), text: $newCategoryName)
                        .keyboardType(.default)
                        .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)
                        .font(.headline)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 14)
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
                    .localizedFieldMessage(appLanguage)
                    .frame(height: 18)

                Button {
                    guard let amount = parsedAmount else {
                        errorMessage = appLanguage.text(he: "סכום לא תקין", en: "Invalid amount")
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
                    Text(appLanguage.text(he: "שמור", en: "Save"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
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
        title(for: .he)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .oneTime:
            language.text(he: "חד פעמית", en: "One-time")
        case .recurring:
            language.text(he: "חוזרת", en: "Recurring")
        }
    }

    var detailsTitle: String {
        detailsTitle(for: .he)
    }

    func detailsTitle(for language: AppLanguage) -> String {
        switch self {
        case .oneTime:
            language.text(he: "סכום ותאריך", en: "Amount and Date")
        case .recurring:
            language.text(he: "סכום ומשך", en: "Amount and Duration")
        }
    }
}

private enum ReassignCategoryMode {
    case existing
    case new
}

private struct ManageCategoriesView: View {
    @Environment(\.appLanguage) private var appLanguage

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
    @State private var isAddCategoryPresented = false
    @State private var newCategoryName = ""
    @State private var newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
    @State private var newCategoryTintName = CategoryAppearanceOption.defaultTintName
    @State private var newCategoryError: String?

    var body: some View {
        NavigationStack {
            List {
                Section(appLanguage.text(he: "קטגוריות פעילות", en: "Active Categories")) {
                    if categories.isEmpty {
                        Text(appLanguage.text(he: "אין קטגוריות עדיין", en: "No categories yet"))
                            .foregroundStyle(.secondary)
                    } else {
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
                                onDelete: {
                                    startDeleting(category)
                                }
                            )
                        }
                    }
                }

                if !deletedCategoryBuckets.isEmpty {
                    Section(appLanguage.text(he: "קטגוריות שנמחקו", en: "Deleted Categories")) {
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
            .navigationTitle(appLanguage.text(he: "נהל קטגוריות", en: "Manage Categories"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(appLanguage.text(he: "סגור", en: "Close")) {
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openAddCategory()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(.thinMaterial, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appLanguage.text(he: "הוסף קטגוריה", en: "Add Category"))
                }
            }
        }
        .environment(\.layoutDirection, appLanguage.layoutDirection)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .sheet(isPresented: $isAddCategoryPresented) {
            AddCategoryView(
                categoryName: $newCategoryName,
                selectedSystemImageName: $newCategorySystemImageName,
                selectedTintName: $newCategoryTintName,
                errorMessage: $newCategoryError,
                onSave: saveNewManagedCategory,
                onCancel: closeAddCategory
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(620)])
        }
        .sheet(item: $categoryBeingRenamed) { category in
            EditCategoryView(
                category: category,
                onSave: saveEditedCategory,
                onCancel: clearRenameState
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.height(460)])
        }
        .sheet(item: $categoryForMonthlyDetails) { category in
            CategoryMonthlyDetailsView(
                category: category,
                expenses: $expenses,
                recurringExpenses: recurringExpenses.filter { $0.categoryId == category.id },
                onClose: {
                    categoryForMonthlyDetails = nil
                },
                onPersist: {
                    onPersist()
                }
            )
            .localizedPresentationEnvironment(appLanguage)
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            appLanguage.text(he: "לאן להעביר את ההוצאות?", en: "Where should the expenses move?"),
            isPresented: deleteDialogBinding,
            titleVisibility: .visible
        ) {
            if let pendingCategory = categoryPendingDelete {
                let transferTargets = categories.filter { $0.id != pendingCategory.id }

                ForEach(transferTargets) { category in
                    Button(appLanguage.text(he: "העבר ל\(category.displayName(for: appLanguage))", en: "Move to \(category.displayName(for: appLanguage))")) {
                        deleteCategory(pendingCategory, transferTo: category)
                    }
                }

                Button(appLanguage.text(he: "שייך יותר מאוחר", en: "Assign Later")) {
                    deleteCategoryLater(pendingCategory)
                }

                Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {
                    categoryPendingDelete = nil
                }
            }
        } message: {
            if let categoryPendingDelete {
                let displayName = categoryPendingDelete.displayName(for: appLanguage)
                Text(appLanguage.text(
                    he: "בקטגוריה \(displayName) יש \(monthlyTotal(categoryPendingDelete).formattedShekelAmount) החודש.",
                    en: "\(displayName) has \(monthlyTotal(categoryPendingDelete).formattedShekelAmount) this month."
                ))
            }
        }
        .confirmationDialog(
            appLanguage.text(he: "שייך מחדש", en: "Reassign"),
            isPresented: reassignDialogBinding,
            titleVisibility: .visible
        ) {
            if let bucketPendingReassignment {
                if !categories.isEmpty {
                    ForEach(categories) { category in
                        Button(appLanguage.text(he: "שייך ל\(category.displayName(for: appLanguage))", en: "Assign to \(category.displayName(for: appLanguage))")) {
                            reassign(bucketPendingReassignment, to: category)
                        }
                    }
                }

                Button(appLanguage.text(he: "צור קטגוריה חדשה", en: "Create New Category")) {
                    reassignMode = .new
                    reassignNewCategoryName = bucketPendingReassignment.originalCategoryName
                }

                Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {
                    clearReassignState()
                }
            }
        } message: {
            if let bucketPendingReassignment {
                Text("\(bucketPendingReassignment.displayName(for: appLanguage)) - \(bucketPendingReassignment.amount.formattedShekelAmount)")
            }
        }
        .alert(appLanguage.text(he: "קטגוריה חדשה", en: "New Category"), isPresented: newReassignCategoryAlertBinding) {
            TextField(appLanguage.text(he: "שם קטגוריה", en: "Category name"), text: $reassignNewCategoryName)
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .localizedTextInput(appLanguage)

            Button(appLanguage.text(he: "ביטול", en: "Cancel"), role: .cancel) {
                clearReassignState()
            }

            Button(appLanguage.text(he: "שמור", en: "Save")) {
                createCategoryAndReassign()
            }
            .disabled(reassignNewCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(appLanguage.text(he: "בחר שם לקטגוריה שאליה נשייך את הסכום.", en: "Choose the category name for this amount."))
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

    private func openAddCategory() {
        newCategoryName = ""
        newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
        newCategoryTintName = CategoryAppearanceOption.defaultTintName
        newCategoryError = nil
        isAddCategoryPresented = true
    }

    private func closeAddCategory() {
        isAddCategoryPresented = false
        newCategoryName = ""
        newCategorySystemImageName = CategoryAppearanceOption.defaultSystemImageName
        newCategoryTintName = CategoryAppearanceOption.defaultTintName
        newCategoryError = nil
    }

    private func saveNewManagedCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            newCategoryError = appLanguage.text(he: "צריך שם קטגוריה", en: "Enter a category name")
            return
        }

        guard !categories.contains(where: { $0.name.normalizedForComparison == trimmedName.normalizedForComparison }) else {
            newCategoryError = appLanguage.text(he: "קטגוריה זו כבר קיימת", en: "This category already exists")
            return
        }

        let category = ExpenseCategory(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            systemImageName: newCategorySystemImageName,
            tintName: newCategoryTintName
        )
        categories.append(category)
        currentCategoryIndex = categories.count - 1
        onPersist()
        closeAddCategory()
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
            return appLanguage.text(he: "צריך שם קטגוריה", en: "Enter a category name")
        }

        let editedCategoryId = category.id
        let isDuplicate = categories.contains { existingCategory in
            existingCategory.id != editedCategoryId &&
            existingCategory.name.normalizedForComparison == trimmedName.normalizedForComparison
        }

        guard !isDuplicate else {
            return appLanguage.text(he: "קטגוריה זו כבר קיימת", en: "This category already exists")
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
                total + expense.netAmount
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
                expense.categoryId == category.id && expense.date >= monthStart
            }
            .sorted { $0.date > $1.date }
    }
}

private struct CategoryManagementRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let category: ExpenseCategory
    let monthlyTotal: Decimal
    let onRename: () -> Void
    let onDetails: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(systemImageName: category.systemImageName, tint: category.tint, size: 22)
                .frame(width: 30)

            categoryText

            Spacer()

            actionButtons
        }
        .padding(.vertical, 6)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onDetails()
            } label: {
                Image(systemName: "eye")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(appLanguage.text(he: "פירוט הוצאות", en: "Expense Details"))

            Button {
                onRename()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(appLanguage.text(he: "שנה שם", en: "Rename"))

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(appLanguage.text(he: "מחק", en: "Delete"))
        }
    }

    private var categoryText: some View {
        VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
            Text(category.displayName(for: appLanguage))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            Text(appLanguage.text(
                he: "החודש \(monthlyTotal.formattedShekelAmount)",
                en: "This month \(monthlyTotal.formattedShekelAmount)"
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)

            if let monthlyTarget = category.monthlyTarget, monthlyTarget > 0 {
                let status = CategoryMonthlyTargetStatus(targetAmount: monthlyTarget, spentAmount: monthlyTotal)
                Text(categoryMonthlyTargetStatusText(status, language: appLanguage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.isOverBudget ? Color(red: 1, green: 0.05, blue: 0.05) : .secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: appLanguage.frameAlignment)
            }
        }
    }
}

private struct DeletedCategoryBucketRow: View {
    @Environment(\.appLanguage) private var appLanguage

    let bucket: DeletedCategoryBucket
    let onReassign: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full")
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: appLanguage.horizontalAlignment, spacing: 4) {
                Text(bucket.displayName(for: appLanguage))
                    .font(.headline)

                Text(bucket.amount.formattedShekelAmount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onReassign()
            } label: {
                Label(appLanguage.text(he: "שייך", en: "Assign"), systemImage: "arrow.right.arrow.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(appLanguage.text(he: "שייך מחדש", en: "Reassign"))
        }
        .padding(.vertical, 6)
    }
}

private struct CategoryCard: View {
    @Environment(\.appLanguage) private var appLanguage

    let category: ExpenseCategory
    let isSelected: Bool
    let positionText: String
    let monthlyTotal: Decimal
    let monthlyTargetStatus: CategoryMonthlyTargetStatus?
    let onAddTarget: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 7) {
                Text(positionText)
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)

                if let monthlyTargetStatus {
                    categoryTargetText(monthlyTargetStatus)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                } else {
                    Text(appLanguage.text(he: "ללא יעד", en: "No Target"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                }

                Button {
                    onAddTarget()
                } label: {
                    Text(monthlyTargetStatus == nil
                        ? appLanguage.text(he: "הוסף יעד", en: "Add Target")
                        : appLanguage.text(he: "שנה יעד", en: "Change Target"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 280, height: 72, alignment: .center)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.tint.opacity(isSelected ? 0.24 : 0.14))

                CategoryIconView(systemImageName: category.systemImageName, tint: category.tint, size: 84)
            }
            .frame(width: 188, height: 188)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.tint : .clear, lineWidth: 3)
            }

        }
        .scaleEffect(isSelected ? 1 : 0.96)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category.displayName(for: appLanguage))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func categoryTargetText(_ status: CategoryMonthlyTargetStatus) -> some View {
        let categoryName = category.displayName(for: appLanguage)
        let ratioText = compactTargetRatioText(
            spentAmount: status.spentAmount,
            targetAmount: status.targetAmount,
            language: appLanguage
        )
        let percentText = compactTargetPercentText(
            spentAmount: status.spentAmount,
            targetAmount: status.targetAmount
        )

        if appLanguage == .he {
            FixedHebrewVisualText(
                parts: ["על \(categoryName)", ratioText, percentText, "הוצאת"],
                accessibilityLabel: "הוצאת \(ratioText) \(percentText) על \(categoryName)",
                fontSize: 15,
                minimumScaleFactor: 0.62
            )
            .frame(height: 18)
            .fixedSize(horizontal: true, vertical: false)
        } else {
            Text("Spent \(ratioText) \(percentText) on \(categoryName)")
        }
    }
}

private struct CategoryTargetCompactSummaryView: View {
    @Environment(\.appLanguage) private var appLanguage

    let status: CategoryMonthlyTargetStatus

    var body: some View {
        VStack(spacing: 4) {
            Text(categoryTargetRatioText(status, language: appLanguage))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Text(categoryTargetStatusLineText(status, language: appLanguage))
            .font(.caption.weight(.bold))
            .foregroundStyle(status.isOverBudget ? Color.red : (status.remainingAmount > 0 ? Color.green : .secondary))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CategoryPageDots: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.32))
                    .frame(width: index == currentIndex ? 7 : 6, height: index == currentIndex ? 7 : 6)
                    .animation(.easeInOut(duration: 0.18), value: currentIndex)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

private extension Decimal {
    func mainTargetAmountText(for language: AppLanguage) -> String {
        let symbol = Storage.loadCurrency().symbol
        return language == .he ? "\(plainString)\(symbol)" : "\(symbol)\(plainString)"
    }

    var formattedShekelAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = Storage.loadCurrency().symbol
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

    var hebrewShekelWords: String {
        if self == 1 {
            return "שקל אחד"
        }

        return "\(plainString) שקלים"
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

    var roundedCurrencyAmount: Decimal {
        var value = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
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

    var safeCategorySystemImageName: String {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty,
              categoryEmoji == nil,
              CategoryAppearanceOption.systemImages.contains(trimmedValue) else {
            return CategoryAppearanceOption.fallbackSystemImageName
        }

        return trimmedValue
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

private extension Int {
    func salaryReceiptDayTitle(for language: AppLanguage, dateDisplayFormat: DateDisplayFormat) -> String {
        let day = Swift.min(Swift.max(self, 1), 31)

        if dateDisplayFormat == .hebrewCalendar {
            return "\(day.hebrewNumeralDayText) לחודש"
        }

        switch language {
        case .he:
            return "\(day.hebrewOrdinalDayText) לחודש"
        case .en:
            return "\(day)\(day.englishOrdinalSuffix) of the month"
        }
    }

    private var englishOrdinalSuffix: String {
        let day = Swift.min(Swift.max(self, 1), 31)
        let lastTwoDigits = day % 100

        if (11...13).contains(lastTwoDigits) {
            return "th"
        }

        switch day % 10 {
        case 1:
            return "st"
        case 2:
            return "nd"
        case 3:
            return "rd"
        default:
            return "th"
        }
    }

    private var hebrewNumeralDayText: String {
        switch Swift.min(Swift.max(self, 1), 31) {
        case 1: "א׳"
        case 2: "ב׳"
        case 3: "ג׳"
        case 4: "ד׳"
        case 5: "ה׳"
        case 6: "ו׳"
        case 7: "ז׳"
        case 8: "ח׳"
        case 9: "ט׳"
        case 10: "י׳"
        case 11: "י״א"
        case 12: "י״ב"
        case 13: "י״ג"
        case 14: "י״ד"
        case 15: "ט״ו"
        case 16: "ט״ז"
        case 17: "י״ז"
        case 18: "י״ח"
        case 19: "י״ט"
        case 20: "כ׳"
        case 21: "כ״א"
        case 22: "כ״ב"
        case 23: "כ״ג"
        case 24: "כ״ד"
        case 25: "כ״ה"
        case 26: "כ״ו"
        case 27: "כ״ז"
        case 28: "כ״ח"
        case 29: "כ״ט"
        case 30: "ל׳"
        case 31: "ל״א"
        default: "א׳"
        }
    }

    private var hebrewOrdinalDayText: String {
        switch Swift.min(Swift.max(self, 1), 31) {
        case 1: "ראשון"
        case 2: "שני"
        case 3: "שלישי"
        case 4: "רביעי"
        case 5: "חמישי"
        case 6: "שישי"
        case 7: "שביעי"
        case 8: "שמיני"
        case 9: "תשיעי"
        case 10: "עשירי"
        case 11: "אחד עשר"
        case 12: "שנים עשר"
        case 13: "שלושה עשר"
        case 14: "ארבעה עשר"
        case 15: "חמישה עשר"
        case 16: "שישה עשר"
        case 17: "שבעה עשר"
        case 18: "שמונה עשר"
        case 19: "תשעה עשר"
        case 20: "עשרים"
        case 21: "עשרים ואחד"
        case 22: "עשרים ושניים"
        case 23: "עשרים ושלושה"
        case 24: "עשרים וארבעה"
        case 25: "עשרים וחמישה"
        case 26: "עשרים ושישה"
        case 27: "עשרים ושבעה"
        case 28: "עשרים ושמונה"
        case 29: "עשרים ותשעה"
        case 30: "שלושים"
        case 31: "שלושים ואחד"
        default: "ראשון"
        }
    }
}

private extension Calendar {
    func monthStart(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }

    func normalizedMonthDate(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: 1,
            hour: 12,
            minute: 0,
            second: 0
        )) ?? date
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

    func salaryPromptDate(year: Int, month: Int, day: Int) -> Date? {
        let range = range(of: .day, in: .month, for: date(from: DateComponents(year: year, month: month, day: 1)) ?? Date())
        let lastDay = range?.count ?? 28
        return date(from: DateComponents(year: year, month: month, day: min(max(day, 1), lastDay)))
    }
}

private extension Date {
    var shortDateText: String {
        shortDateText(for: .he)
    }

    func shortDateText(for language: AppLanguage) -> String {
        formattedDateText(for: language, style: .date)
    }

    func monthYearText(for language: AppLanguage) -> String {
        formattedDateText(for: language, style: .monthYear)
    }

    var expenseDateTimeText: String {
        expenseDateTimeText(for: .he)
    }

    func expenseDateTimeText(for language: AppLanguage) -> String {
        formattedDateText(for: language, style: .dateTime)
    }

    var restoreSnapshotDateText: String {
        localizedDateTimeText(for: .he)
    }

    func localizedDateTimeText(for language: AppLanguage) -> String {
        formattedDateText(for: language, style: .dateTime)
    }

    private enum DisplayDateStyle {
        case date
        case dateTime
        case monthYear
    }

    private func formattedDateText(for language: AppLanguage, style: DisplayDateStyle) -> String {
        let displayFormat = Storage.loadDateDisplayFormat()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)

        if displayFormat == .hebrewCalendar {
            formatter.calendar = Calendar(identifier: .hebrew)
        }

        switch style {
        case .date:
            formatter.dateFormat = displayFormat.dateFormat
        case .dateTime:
            formatter.dateFormat = displayFormat.dateTimeFormat
        case .monthYear:
            formatter.dateFormat = displayFormat.monthYearFormat
        }

        return formatter.string(from: self)
    }
}

private struct CategoryAppearanceSymbolGroup: Identifiable {
    let titleHE: String
    let titleEN: String
    let searchKeywords: [String]
    let symbols: [String]

    var id: String {
        titleEN
    }

    func title(for language: AppLanguage) -> String {
        language.text(he: titleHE, en: titleEN)
    }
}

private enum CategoryAppearanceOption {
    static let fallbackSystemImageName = "tag"
    static let defaultSystemImageName = "square.grid.2x2.fill"
    static let defaultTintName = "purple"

    static let symbolGroups: [CategoryAppearanceSymbolGroup] = [
        CategoryAppearanceSymbolGroup(
            titleHE: "אוכל",
            titleEN: "Food",
            searchKeywords: ["food", "meal", "restaurant", "coffee", "drink", "אוכל", "מסעדה", "קפה", "שתיה"],
            symbols: [
                "fork.knife", "cup.and.saucer", "takeoutbag.and.cup.and.straw", "cart", "cart.fill",
                "basket", "basket.fill", "mug", "mug.fill", "wineglass", "birthday.cake",
                "birthday.cake.fill", "waterbottle", "waterbottle.fill", "carrot", "carrot.fill",
                "fish", "fish.fill", "popcorn", "popcorn.fill", "leaf", "leaf.fill",
                "drop", "drop.fill", "flame", "flame.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "תחבורה",
            titleEN: "Transport",
            searchKeywords: ["transport", "car", "bus", "train", "fuel", "flight", "תחבורה", "רכב", "אוטובוס", "דלק"],
            symbols: [
                "car", "car.fill", "car.circle", "car.circle.fill", "bus", "bus.fill",
                "tram", "tram.fill", "airplane", "airplane.circle", "airplane.departure", "airplane.arrival",
                "bicycle", "fuelpump", "fuelpump.fill", "parkingsign", "parkingsign.circle",
                "parkingsign.circle.fill", "road.lanes", "road.lanes.curved.left", "figure.walk",
                "figure.walk.circle", "figure.run", "sailboat", "sailboat.fill", "ferry",
                "ferry.fill", "truck.box", "truck.box.fill", "box.truck", "box.truck.fill",
                "bus.doubledecker", "bus.doubledecker.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "בית",
            titleEN: "Home",
            searchKeywords: ["home", "house", "rent", "utilities", "wifi", "בית", "שכירות", "חשמל", "מים"],
            symbols: [
                "house", "house.fill", "house.circle", "house.circle.fill", "building.2",
                "building.2.fill", "building.columns", "building.columns.fill", "lightbulb",
                "lightbulb.fill", "lamp.table", "lamp.table.fill", "sofa", "sofa.fill",
                "bed.double", "bed.double.fill", "shower", "shower.fill", "bathtub", "bathtub.fill",
                "washer", "washer.fill", "dryer", "dryer.fill", "dishwasher", "dishwasher.fill",
                "toilet", "toilet.fill", "wifi", "wifi.circle", "wifi.circle.fill", "thermometer",
                "humidity", "humidity.fill", "fan", "fan.fill", "lock", "lock.fill",
                "key", "key.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "בריאות",
            titleEN: "Health",
            searchKeywords: ["health", "medical", "doctor", "medicine", "pharmacy", "בריאות", "רופא", "תרופה", "קופה"],
            symbols: [
                "cross", "cross.fill", "cross.case", "cross.case.fill", "heart",
                "heart.fill", "heart.circle", "heart.circle.fill", "heart.text.square",
                "heart.text.square.fill", "pills", "pills.fill", "stethoscope", "bandage",
                "bandage.fill", "syringe", "syringe.fill", "staroflife", "staroflife.fill",
                "facemask", "facemask.fill", "brain.head.profile", "lungs", "lungs.fill",
                "waveform.path.ecg", "waveform.path.ecg.rectangle", "eye", "eye.fill",
                "ear", "ear.badge.checkmark", "figure.mind.and.body", "figure.walk",
                "figure.run", "figure.yoga"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "קניות",
            titleEN: "Shopping",
            searchKeywords: ["shopping", "shop", "store", "clothes", "gift", "קניות", "חנות", "בגדים", "מתנה"],
            symbols: [
                "bag", "bag.fill", "bag.circle", "bag.circle.fill", "cart", "cart.fill",
                "cart.circle", "cart.circle.fill", "basket", "basket.fill", "tshirt",
                "tshirt.fill", "shoe", "shoe.fill", "gift", "gift.fill", "gift.circle",
                "shippingbox", "shippingbox.fill", "shippingbox.circle", "archivebox",
                "archivebox.fill", "tag", "tag.fill", "tag.circle", "tag.circle.fill",
                "barcode", "qrcode", "creditcard", "storefront", "storefront.fill",
                "scalemass", "scalemass.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "כספים",
            titleEN: "Finance",
            searchKeywords: ["finance", "money", "card", "bank", "cash", "budget", "כסף", "כרטיס", "בנק", "תקציב"],
            symbols: [
                "creditcard", "creditcard.fill", "creditcard.circle", "creditcard.circle.fill",
                "banknote", "banknote.fill", "dollarsign", "dollarsign.circle",
                "dollarsign.circle.fill", "dollarsign.square", "dollarsign.square.fill",
                "shekelsign", "shekelsign.circle", "shekelsign.circle.fill", "shekelsign.square",
                "eurosign", "eurosign.circle", "eurosign.circle.fill", "sterlingsign.circle",
                "yensign.circle", "bitcoinsign.circle", "chart.pie", "chart.pie.fill",
                "chart.bar", "chart.bar.fill", "chart.line.uptrend.xyaxis", "chart.line.downtrend.xyaxis",
                "chart.xyaxis.line", "wallet.pass", "wallet.pass.fill", "percent",
                "percent.ar", "number", "plus.forwardslash.minus", "equal.circle"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "עבודה וקבצים",
            titleEN: "Work & Files",
            searchKeywords: ["work", "office", "file", "folder", "document", "עבודה", "משרד", "קובץ", "תיקיה"],
            symbols: [
                "briefcase", "briefcase.fill", "case", "case.fill", "folder", "folder.fill",
                "folder.circle", "folder.circle.fill", "folder.badge.plus", "folder.badge.minus",
                "doc", "doc.fill", "doc.text", "doc.text.fill", "doc.richtext",
                "doc.on.doc", "doc.on.doc.fill", "doc.badge.plus", "doc.badge.gearshape",
                "doc.badge.ellipsis", "tray", "tray.fill", "tray.full", "tray.full.fill",
                "archivebox", "archivebox.fill", "clipboard", "list.clipboard", "paperclip",
                "paperplane", "paperplane.fill", "signature", "calendar", "calendar.badge.plus",
                "calendar.badge.clock", "calendar.circle", "printer", "printer.fill",
                "scanner", "faxmachine"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "לימודים",
            titleEN: "Education",
            searchKeywords: ["education", "school", "book", "learn", "study", "לימודים", "ספר", "בית ספר", "אוניברסיטה"],
            symbols: [
                "book", "book.fill", "book.closed", "book.closed.fill", "books.vertical",
                "books.vertical.fill", "graduationcap", "graduationcap.fill", "studentdesk",
                "pencil", "pencil.circle", "pencil.circle.fill", "pencil.and.outline",
                "pencil.line", "pencil.tip", "highlighter", "text.book.closed",
                "text.book.closed.fill", "character.book.closed", "bookmark", "bookmark.fill",
                "bookmark.circle", "bookmark.circle.fill", "textformat", "textformat.abc",
                "textformat.abc.dottedunderline", "text.alignleft", "list.bullet.rectangle",
                "checklist", "note.text", "note.text.badge.plus"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "מכשירים ודיגיטל",
            titleEN: "Devices & Digital",
            searchKeywords: ["device", "phone", "computer", "digital", "subscription", "מכשיר", "טלפון", "מחשב", "מנוי"],
            symbols: [
                "iphone", "iphone.circle", "iphone.gen1", "iphone.gen2", "iphone.gen3",
                "ipad", "ipad.landscape", "laptopcomputer", "desktopcomputer", "display",
                "display.2", "applewatch", "applewatch.watchface", "keyboard", "keyboard.fill",
                "computermouse", "computermouse.fill", "magicmouse", "magicmouse.fill",
                "trackpad", "trackpad.fill", "headphones", "earbuds", "earbuds.case",
                "hifispeaker", "hifispeaker.fill", "tv", "tv.fill", "gamecontroller",
                "gamecontroller.fill", "camera", "camera.fill", "video", "video.fill",
                "wifi", "antenna.radiowaves.left.and.right", "dot.radiowaves.left.and.right",
                "app", "app.fill", "app.badge", "app.badge.fill", "bell", "bell.fill",
                "icloud", "icloud.fill", "externaldrive", "externaldrive.fill",
                "internaldrive", "internaldrive.fill", "battery.100", "powerplug", "powerplug.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "אנשים ומשפחה",
            titleEN: "People & Family",
            searchKeywords: ["people", "family", "person", "child", "pet", "אנשים", "משפחה", "ילד", "חיות"],
            symbols: [
                "person", "person.fill", "person.circle", "person.circle.fill", "person.crop.circle",
                "person.crop.circle.fill", "person.2", "person.2.fill", "person.3",
                "person.3.fill", "person.badge.plus", "person.badge.minus", "person.badge.clock",
                "person.text.rectangle", "figure.2.and.child.holdinghands", "figure.and.child.holdinghands",
                "figure.walk", "figure.run", "figure.wave", "figure.roll", "figure.stand",
                "figure.stand.line.dotted.figure.stand", "hands.clap", "hands.clap.fill",
                "hand.raised", "hand.raised.fill", "hand.thumbsup", "hand.thumbsup.fill",
                "hand.heart", "hand.heart.fill", "pawprint", "pawprint.fill", "teddybear",
                "teddybear.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "נסיעות וטבע",
            titleEN: "Travel & Nature",
            searchKeywords: ["travel", "trip", "vacation", "nature", "weather", "נסיעות", "טיול", "טבע", "מזג אוויר"],
            symbols: [
                "suitcase", "suitcase.fill", "map", "map.fill", "globe", "globe.europe.africa",
                "globe.asia.australia", "globe.americas", "location", "location.fill",
                "location.circle", "location.circle.fill", "mappin", "mappin.circle",
                "mappin.and.ellipse", "tent", "tent.fill", "beach.umbrella",
                "beach.umbrella.fill", "mountain.2", "mountain.2.fill", "tree",
                "tree.fill", "leaf", "leaf.fill", "camera", "camera.fill", "binoculars",
                "binoculars.fill", "sun.max", "sun.max.fill", "moon", "moon.fill",
                "cloud", "cloud.fill", "cloud.rain", "cloud.rain.fill", "snowflake",
                "wind", "rainbow"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "מדיה ובידור",
            titleEN: "Media & Entertainment",
            searchKeywords: ["media", "entertainment", "music", "movie", "game", "מדיה", "בידור", "מוזיקה", "סרט"],
            symbols: [
                "music.note", "music.note.list", "music.mic", "music.quarternote.3",
                "play", "play.fill", "play.circle", "play.circle.fill", "pause",
                "pause.fill", "stop", "stop.fill", "forward", "forward.fill",
                "backward", "backward.fill", "shuffle", "repeat", "speaker",
                "speaker.fill", "speaker.wave.2", "speaker.wave.2.fill", "mic",
                "mic.fill", "mic.circle", "film", "film.fill", "movieclapper",
                "movieclapper.fill", "theatermasks", "theatermasks.fill", "ticket",
                "ticket.fill", "paintpalette", "paintpalette.fill", "photo", "photo.fill",
                "photo.on.rectangle", "photo.stack", "camera.filters", "sparkles",
                "wand.and.stars"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "תקשורת",
            titleEN: "Communication",
            searchKeywords: ["communication", "message", "mail", "phone", "chat", "תקשורת", "הודעה", "מייל", "טלפון"],
            symbols: [
                "phone", "phone.fill", "phone.circle", "phone.circle.fill", "phone.badge.plus",
                "envelope", "envelope.fill", "envelope.circle", "envelope.circle.fill",
                "message", "message.fill", "message.circle", "message.circle.fill",
                "bubble.left", "bubble.left.fill", "bubble.right", "bubble.right.fill",
                "bubble.left.and.bubble.right", "bubble.left.and.bubble.right.fill",
                "quote.bubble", "quote.bubble.fill", "at", "at.circle", "at.circle.fill",
                "paperplane", "paperplane.fill", "bell", "bell.fill", "bell.badge",
                "bell.badge.fill", "megaphone", "megaphone.fill", "antenna.radiowaves.left.and.right"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "כלים ותחזוקה",
            titleEN: "Tools & Maintenance",
            searchKeywords: ["tool", "repair", "maintenance", "settings", "fix", "כלים", "תיקון", "תחזוקה", "הגדרות"],
            symbols: [
                "wrench", "wrench.fill", "hammer", "hammer.fill", "screwdriver",
                "screwdriver.fill", "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
                "gear", "gearshape", "gearshape.fill", "slider.horizontal.3",
                "slider.horizontal.2.square", "switch.2", "paintbrush", "paintbrush.fill",
                "paintroller", "paintroller.fill", "eyedropper", "eyedropper.full",
                "scissors", "ruler", "ruler.fill", "level", "level.fill",
                "briefcase", "case", "lock", "lock.fill", "lock.open", "lock.open.fill",
                "key", "key.fill", "trash", "trash.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "סטטוס ובטיחות",
            titleEN: "Status & Safety",
            searchKeywords: ["status", "safety", "alert", "security", "warning", "סטטוס", "בטיחות", "אזהרה", "אבטחה"],
            symbols: [
                "checkmark", "checkmark.circle", "checkmark.circle.fill", "checkmark.square",
                "checkmark.square.fill", "xmark", "xmark.circle", "xmark.circle.fill",
                "xmark.square", "xmark.square.fill", "plus", "plus.circle", "plus.circle.fill",
                "minus", "minus.circle", "minus.circle.fill", "exclamationmark.circle",
                "exclamationmark.circle.fill", "exclamationmark.triangle", "exclamationmark.triangle.fill",
                "info.circle", "info.circle.fill", "questionmark.circle", "questionmark.circle.fill",
                "shield", "shield.fill", "shield.lefthalf.filled", "lock.shield",
                "lock.shield.fill", "eye", "eye.fill", "eye.slash", "eye.slash.fill",
                "flag", "flag.fill", "bookmark", "bookmark.fill"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "חיצים ופעולות",
            titleEN: "Arrows & Actions",
            searchKeywords: ["arrow", "action", "move", "direction", "upload", "חץ", "פעולה", "כיוון", "העלאה"],
            symbols: [
                "arrow.up", "arrow.down", "arrow.left", "arrow.right", "arrow.up.circle",
                "arrow.down.circle", "arrow.left.circle", "arrow.right.circle",
                "arrow.up.circle.fill", "arrow.down.circle.fill", "arrow.left.circle.fill",
                "arrow.right.circle.fill", "arrow.up.square", "arrow.down.square",
                "arrow.left.square", "arrow.right.square", "arrow.clockwise", "arrow.counterclockwise",
                "arrow.2.circlepath", "arrow.triangle.2.circlepath", "arrow.up.arrow.down",
                "arrow.left.arrow.right", "arrow.down.to.line", "arrow.up.to.line",
                "arrow.down.doc", "arrow.up.doc", "square.and.arrow.up", "square.and.arrow.down",
                "square.and.pencil", "pencil", "plus.app", "minus.plus.batteryblock",
                "chevron.up", "chevron.down", "chevron.left", "chevron.right",
                "chevron.up.circle", "chevron.down.circle", "chevron.left.circle", "chevron.right.circle"
            ]
        ),
        CategoryAppearanceSymbolGroup(
            titleHE: "צורות וכללי",
            titleEN: "Shapes & General",
            searchKeywords: ["general", "shape", "grid", "star", "tag", "כללי", "צורה", "כוכב", "תג"],
            symbols: [
                "tag", "tag.fill", "star", "star.fill", "star.circle", "star.circle.fill",
                "heart", "heart.fill", "circle", "circle.fill", "circle.grid.3x3",
                "circle.grid.3x3.fill", "square", "square.fill", "square.grid.2x2",
                "square.grid.2x2.fill", "square.grid.3x3", "rectangle", "rectangle.fill",
                "capsule", "capsule.fill", "triangle", "triangle.fill", "diamond",
                "diamond.fill", "hexagon", "hexagon.fill", "seal", "seal.fill",
                "rosette", "target", "scope", "smallcircle.filled.circle",
                "ellipsis", "ellipsis.circle", "ellipsis.circle.fill", "line.3.horizontal",
                "line.3.horizontal.circle", "line.3.horizontal.circle.fill", "list.bullet",
                "list.bullet.circle", "magnifyingglass"
            ]
        )
    ]

    static let systemImages = Array(Set(symbolGroups.flatMap(\.symbols) + [fallbackSystemImageName, defaultSystemImageName]))

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

private enum DateDisplayFormat: String, CaseIterable, Identifiable, Codable {
    case dayMonthYear
    case monthDayYear
    case yearMonthDay
    case dotDayMonthYear
    case dayMonthNameYear
    case hebrewCalendar

    var id: String {
        rawValue
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .dayMonthYear:
            language.text(he: "יום/חודש/שנה", en: "Day/Month/Year")
        case .monthDayYear:
            language.text(he: "חודש/יום/שנה", en: "Month/Day/Year")
        case .yearMonthDay:
            language.text(he: "שנה-חודש-יום", en: "Year-Month-Day")
        case .dotDayMonthYear:
            language.text(he: "יום.חודש.שנה", en: "Day.Month.Year")
        case .dayMonthNameYear:
            language.text(he: "יום - חודש בשם - שנה", en: "Day - Month Name - Year")
        case .hebrewCalendar:
            language.text(he: "תאריך עברי", en: "Hebrew Date")
        }
    }

    var dateFormat: String {
        switch self {
        case .dayMonthYear:
            "dd/MM/yyyy"
        case .monthDayYear:
            "MM/dd/yyyy"
        case .yearMonthDay:
            "yyyy-MM-dd"
        case .dotDayMonthYear:
            "dd.MM.yyyy"
        case .dayMonthNameYear:
            "d - MMMM - yyyy"
        case .hebrewCalendar:
            "d MMMM yyyy"
        }
    }

    var dateTimeFormat: String {
        switch self {
        case .dayMonthYear:
            "dd/MM/yyyy, HH:mm"
        case .monthDayYear:
            "MM/dd/yyyy, HH:mm"
        case .yearMonthDay:
            "yyyy-MM-dd, HH:mm"
        case .dotDayMonthYear:
            "dd.MM.yyyy, HH:mm"
        case .dayMonthNameYear:
            "d - MMMM - yyyy, HH:mm"
        case .hebrewCalendar:
            "d MMMM yyyy, HH:mm"
        }
    }

    var monthYearFormat: String {
        switch self {
        case .dayMonthYear, .monthDayYear:
            "MM/yyyy"
        case .yearMonthDay:
            "yyyy-MM"
        case .dotDayMonthYear:
            "MM.yyyy"
        case .dayMonthNameYear:
            "MMMM yyyy"
        case .hebrewCalendar:
            "MMMM yyyy"
        }
    }
}

private enum CurrencyOption: String, CaseIterable, Identifiable, Codable {
    case ils
    case usd
    case eur
    case gbp
    case jpy
    case cad
    case aud
    case thb

    var id: String {
        rawValue
    }

    static func option(for code: String) -> CurrencyOption? {
        CurrencyOption(rawValue: code.lowercased())
    }

    var code: String {
        rawValue.uppercased()
    }

    var symbol: String {
        switch self {
        case .ils:
            "₪"
        case .usd:
            "$"
        case .eur:
            "€"
        case .gbp:
            "£"
        case .jpy:
            "¥"
        case .cad:
            "C$"
        case .aud:
            "A$"
        case .thb:
            "฿"
        }
    }

    var selectorTitle: String {
        "\(code) \(symbol)"
    }

    var title: String {
        title(for: .he)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .ils:
            language.text(he: "₪ שקל", en: "₪ Shekel")
        case .usd:
            language.text(he: "$ דולר", en: "$ Dollar")
        case .eur:
            language.text(he: "€ אירו", en: "€ Euro")
        case .gbp:
            language.text(he: "£ לירה שטרלינג", en: "£ British Pound")
        case .jpy:
            language.text(he: "¥ ין יפני", en: "¥ Japanese Yen")
        case .cad:
            language.text(he: "C$ דולר קנדי", en: "C$ Canadian Dollar")
        case .aud:
            language.text(he: "A$ דולר אוסטרלי", en: "A$ Australian Dollar")
        case .thb:
            language.text(he: "฿ באט תאילנדי", en: "฿ Thai Baht")
        }
    }
}

private struct CurrencyExchangeRate: Codable {
    let currencyCode: String
    let rateInILS: Decimal
    let unit: Decimal
    let rateDate: Date

    var normalizedRateInILS: Decimal {
        guard unit > 0 else {
            return rateInILS
        }

        return rateInILS / unit
    }
}

private struct CurrencyConversionResult {
    let convertedAmount: Decimal
    let exchangeRate: Decimal
    let exchangeRateDate: Date
}

private enum CurrencyExchangeService {
    private static let cacheRefreshInterval: TimeInterval = 24 * 60 * 60
    private static let bankOfIsraelURL = URL(string: "https://boi.org.il/PublicApi/GetExchangeRates?asXML=false")

    static func markRatesStale() {
        UserDefaults.standard.removeObject(forKey: Storage.currencyRatesLastRefreshKey)
    }

    static func refreshIfNeeded() async {
        guard shouldRefreshRates else {
            return
        }

        await refreshRates()
    }

    static func convert(amount: Decimal, from sourceCurrency: CurrencyOption, to targetCurrency: CurrencyOption) -> CurrencyConversionResult? {
        guard amount > 0 else {
            return nil
        }

        if sourceCurrency == targetCurrency {
            return CurrencyConversionResult(convertedAmount: amount, exchangeRate: 1, exchangeRateDate: Date())
        }

        var rates = Storage.loadCurrencyExchangeRates()
        rates["ILS"] = CurrencyExchangeRate(currencyCode: "ILS", rateInILS: 1, unit: 1, rateDate: Date())

        guard let sourceRate = rates[sourceCurrency.code],
              let targetRate = rates[targetCurrency.code],
              sourceRate.normalizedRateInILS > 0,
              targetRate.normalizedRateInILS > 0 else {
            return nil
        }

        let amountInILS = amount * sourceRate.normalizedRateInILS
        let convertedAmount = amountInILS / targetRate.normalizedRateInILS
        let directRate = sourceRate.normalizedRateInILS / targetRate.normalizedRateInILS
        let rateDate = min(sourceRate.rateDate, targetRate.rateDate)

        return CurrencyConversionResult(
            convertedAmount: convertedAmount.roundedCurrencyAmount,
            exchangeRate: directRate,
            exchangeRateDate: rateDate
        )
    }

    private static var shouldRefreshRates: Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: Storage.currencyRatesLastRefreshKey) as? Date else {
            return true
        }

        return Date().timeIntervalSince(lastRefresh) >= cacheRefreshInterval
    }

    private static func refreshRates() async {
        guard let bankOfIsraelURL else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: bankOfIsraelURL)
            let rates = try BankOfIsraelExchangeRateParser.parse(data: data)

            guard !rates.isEmpty else {
                return
            }

            Storage.saveCurrencyExchangeRates(rates)
            UserDefaults.standard.set(Date(), forKey: Storage.currencyRatesLastRefreshKey)
        } catch {
            return
        }
    }
}

private enum BankOfIsraelExchangeRateParser {
    static func parse(data: Data) throws -> [String: CurrencyExchangeRate] {
        let json = try JSONSerialization.jsonObject(with: data)
        let objects = collectDictionaries(from: json)
        var rates: [String: CurrencyExchangeRate] = [:]

        for object in objects {
            guard let code = stringValue(object, keys: ["key", "currency", "currencyCode", "code"])?.uppercased(),
                  CurrencyOption.allCases.contains(where: { $0.code == code }),
                  let rate = decimalValue(object, keys: ["currentExchangeRate", "rate", "exchangeRate"]),
                  rate > 0 else {
                continue
            }

            let unit = decimalValue(object, keys: ["unit", "currencyUnits", "units"]) ?? 1
            let date = dateValue(object, keys: ["lastUpdate", "date", "rateDate"]) ?? Date()
            rates[code] = CurrencyExchangeRate(currencyCode: code, rateInILS: rate, unit: unit, rateDate: date)
        }

        rates["ILS"] = CurrencyExchangeRate(currencyCode: "ILS", rateInILS: 1, unit: 1, rateDate: Date())
        return rates
    }

    private static func collectDictionaries(from value: Any) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] {
            return [dictionary] + dictionary.values.flatMap { collectDictionaries(from: $0) }
        }

        if let array = value as? [Any] {
            return array.flatMap { collectDictionaries(from: $0) }
        }

        return []
    }

    private static func stringValue(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private static func decimalValue(_ object: [String: Any], keys: [String]) -> Decimal? {
        for key in keys {
            if let decimal = object[key] as? Decimal {
                return decimal
            }

            if let number = object[key] as? NSNumber {
                return number.decimalValue
            }

            if let string = object[key] as? String,
               let decimal = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) {
                return decimal
            }
        }

        return nil
    }

    private static func dateValue(_ object: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            guard let string = object[key] as? String else {
                continue
            }

            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")

            for format in ["yyyy-MM-dd", "dd/MM/yyyy", "yyyy-MM-dd'T'HH:mm:ss"] {
                formatter.dateFormat = format

                if let date = formatter.date(from: string) {
                    return date
                }
            }
        }

        return nil
    }
}

private struct CategoryMonthlyTargetStatus {
    let targetAmount: Decimal
    let spentAmount: Decimal

    private var budget: BudgetCalculation {
        BudgetCalculation(spentAmount: spentAmount, targetAmount: targetAmount)
    }

    var remainingAmount: Decimal {
        budget.remainingAmount
    }

    var overBudgetAmount: Decimal {
        budget.overBudgetAmount
    }

    var overBudgetPercentage: Decimal? {
        budget.overBudgetPercentage
    }

    var isOverBudget: Bool {
        spentAmount > targetAmount
    }
}

private func netExpenseTotal(for expenses: [Expense]) -> Decimal {
    ExpenseCalculations.netExpenseTotal(expenses.map(\.netAmount))
}

private func netExpenseTotalByCategory(for expenses: [Expense]) -> Decimal {
    let groupedExpenses = Dictionary(grouping: expenses) { expense in
        expense.categoryId
    }

    return groupedExpenses.reduce(Decimal(0)) { total, groupedExpense in
        total + netExpenseTotal(for: groupedExpense.value)
    }
}

private func categoryMonthlyTargetStatus(category: ExpenseCategory, expenses: [Expense], month: Date) -> CategoryMonthlyTargetStatus? {
    guard let monthlyTarget = category.monthlyTarget, monthlyTarget > 0 else {
        return nil
    }

    let monthlyExpenses = expenses.filter { expense in
        expense.categoryId == category.id
            && ExpenseCalculations.isDate(expense.date, inSameMonthAs: month)
    }

    return CategoryMonthlyTargetStatus(
        targetAmount: monthlyTarget,
        spentAmount: netExpenseTotal(for: monthlyExpenses)
    )
}

private enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case he
    case en

    var id: String {
        rawValue
    }

    var title: String {
        title(for: .he)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .he:
            language.text(he: "עברית", en: "Hebrew")
        case .en:
            language.text(he: "אנגלית", en: "English")
        }
    }

    var localeIdentifier: String {
        switch self {
        case .he:
            "he_IL"
        case .en:
            "en_US"
        }
    }

    var layoutDirection: LayoutDirection {
        self == .he ? .rightToLeft : .leftToRight
    }

    var loadingText: String {
        text(he: "רק רגע...", en: "One moment...")
    }

    var textAlignment: TextAlignment {
        .leading
    }

    var horizontalAlignment: HorizontalAlignment {
        .leading
    }

    var frameAlignment: Alignment {
        .leading
    }

    func text(he: String, en: String) -> String {
        switch self {
        case .he:
            he
        case .en:
            en
        }
    }
}

private enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        title(for: .he)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .system:
            language.text(he: "לפי המכשיר", en: "Follow Device")
        case .light:
            language.text(he: "מצב בהיר", en: "Light Mode")
        case .dark:
            language.text(he: "מצב כהה", en: "Dark Mode")
        }
    }

    var menuTitle: String {
        menuTitle(for: .he)
    }

    func menuTitle(for language: AppLanguage) -> String {
        switch self {
        case .system:
            language.text(he: "מערכת", en: "System")
        case .light:
            language.text(he: "בהיר", en: "Light")
        case .dark:
            language.text(he: "כהה", en: "Dark")
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
        themeToggleAccessibilityLabel(for: .he)
    }

    func themeToggleAccessibilityLabel(for language: AppLanguage) -> String {
        self == .dark
            ? language.text(he: "עבור למצב בהיר", en: "Switch to light mode")
            : language.text(he: "עבור למצב כהה", en: "Switch to dark mode")
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

    func displayName(for language: AppLanguage) -> String {
        Self.localizedDefaultName(for: id, language: language) ?? name
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

    static func localizedDefaultName(for id: String, language: AppLanguage) -> String? {
        switch id {
        case "food":
            return language.text(he: "אוכל", en: "Food")
        case "transport":
            return language.text(he: "נסיעות", en: "Transport")
        case "home":
            return language.text(he: "בית", en: "Home")
        case "shopping":
            return language.text(he: "קניות", en: "Shopping")
        case "health":
            return language.text(he: "בריאות", en: "Health")
        default:
            return nil
        }
    }

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

private enum SavingLocation: String, CaseIterable, Identifiable, Codable {
    case bank
    case cash
    case investmentPortfolio
    case deposit
    case other

    var id: String {
        rawValue
    }

    static var withdrawalOptions: [SavingLocation] {
        allCases.filter { $0 != .other }
    }

    var title: String {
        title(for: .he)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .bank:
            language.text(he: "בנק", en: "Bank")
        case .cash:
            language.text(he: "מזומן", en: "Cash")
        case .investmentPortfolio:
            language.text(he: "בורסה", en: "Brokerage")
        case .deposit:
            language.text(he: "פיקדון", en: "Deposit")
        case .other:
            language.text(he: "אחר", en: "Other")
        }
    }
}

private enum SavingKind: String, Codable {
    case deposit
    case withdrawal

    var title: String {
        title(for: .he)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .deposit:
            language.text(he: "חסכון", en: "Saving")
        case .withdrawal:
            language.text(he: "משיכה מחיסכון", en: "Savings Withdrawal")
        }
    }

    var formTitle: String {
        formTitle(for: .he)
    }

    func formTitle(for language: AppLanguage) -> String {
        switch self {
        case .deposit:
            language.text(he: "הוסף חסכון", en: "Add Saving")
        case .withdrawal:
            language.text(he: "משיכה מחיסכון", en: "Withdraw from Savings")
        }
    }
}

private struct Saving: Identifiable, Codable {
    let id: UUID
    let amount: Decimal
    let kind: SavingKind
    let location: SavingLocation
    let customLocation: String
    let date: Date
    let note: String
    let goalId: UUID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        kind: SavingKind = .deposit,
        location: SavingLocation,
        customLocation: String = "",
        date: Date,
        note: String,
        goalId: UUID? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.amount = amount
        self.kind = kind
        self.location = location
        self.customLocation = customLocation
        self.date = date
        self.note = note
        self.goalId = goalId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case kind
        case location
        case customLocation
        case date
        case note
        case goalId
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        amount = try container.decode(Decimal.self, forKey: .amount)
        kind = try container.decodeIfPresent(SavingKind.self, forKey: .kind) ?? .deposit
        location = try container.decode(SavingLocation.self, forKey: .location)
        customLocation = try container.decodeIfPresent(String.self, forKey: .customLocation) ?? ""
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decode(String.self, forKey: .note)
        goalId = try container.decodeIfPresent(UUID.self, forKey: .goalId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    var locationDisplayText: String {
        locationDisplayText(for: .he)
    }

    func locationDisplayText(for language: AppLanguage) -> String {
        if location == .other {
            let trimmedLocation = customLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedLocation.isEmpty ? location.title(for: language) : trimmedLocation
        }

        return location.title(for: language)
    }

    static func balance(for savings: [Saving]) -> Decimal {
        let deposits = savings
            .filter { $0.kind == .deposit }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let withdrawals = savings
            .filter { $0.kind == .withdrawal }
            .reduce(Decimal(0)) { $0 + $1.amount }

        return ExpenseCalculations.savingsBalance(deposits: deposits, withdrawals: withdrawals)
    }

    static func balance(for savings: [Saving], goalId: UUID) -> Decimal {
        balance(for: savings.filter { $0.goalId == goalId })
    }

    static func balance(for savings: [Saving], location: SavingLocation) -> Decimal {
        balance(for: savings.filter { $0.location == location })
    }

    static func hasPositiveBalance(for savings: [Saving], location: SavingLocation) -> Bool {
        balance(for: savings, location: location) > 0
    }
}

private struct SavingGoal: Identifiable, Codable {
    let id: UUID
    let name: String
    let targetAmount: Decimal
    let location: SavingLocation?
    let customLocation: String
    let isActive: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        location: SavingLocation? = nil,
        customLocation: String = "",
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.location = location
        self.customLocation = customLocation
        self.isActive = isActive
        self.createdAt = createdAt
    }

    func locationDisplayText(for language: AppLanguage) -> String {
        guard let location else {
            return language.text(he: "לא צוין מיקום", en: "No location set")
        }

        if location == .other {
            let trimmedLocation = customLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedLocation.isEmpty ? location.title(for: language) : trimmedLocation
        }

        return location.title(for: language)
    }
}

private struct RecurringSaving: Identifiable, Codable {
    let id: UUID
    let amount: Decimal
    let goalId: UUID?
    let startDate: Date
    let isActive: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        goalId: UUID?,
        startDate: Date,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.goalId = goalId
        self.startDate = startDate
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

private enum DebtDirection: String, CaseIterable, Identifiable, Codable {
    case owedToMe
    case iOwe

    var id: String {
        rawValue
    }

    var title: String {
        title(for: .he)
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .owedToMe:
            language.text(he: "חייבים לי", en: "Owed to Me")
        case .iOwe:
            language.text(he: "אני חייב", en: "I Owe")
        }
    }
}

private struct Debt: Identifiable, Codable {
    let id: UUID
    let direction: DebtDirection
    let personName: String
    let originalAmount: Decimal
    let repaidAmount: Decimal
    let reason: String
    let date: Date
    let returnedAt: Date?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        direction: DebtDirection,
        personName: String,
        originalAmount: Decimal,
        repaidAmount: Decimal = 0,
        reason: String,
        date: Date,
        returnedAt: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.direction = direction
        self.personName = personName
        self.originalAmount = originalAmount
        self.repaidAmount = min(max(repaidAmount, 0), originalAmount)
        self.reason = reason
        self.date = date
        self.returnedAt = returnedAt
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case direction
        case personName
        case amount
        case originalAmount
        case repaidAmount
        case reason
        case date
        case isReturned
        case returnedAt
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        direction = try container.decode(DebtDirection.self, forKey: .direction)
        personName = try container.decode(String.self, forKey: .personName)

        let decodedOriginalAmount = try container.decodeIfPresent(Decimal.self, forKey: .originalAmount)
            ?? container.decode(Decimal.self, forKey: .amount)
        let wasReturned = try container.decodeIfPresent(Bool.self, forKey: .isReturned) ?? false
        let decodedRepaidAmount = try container.decodeIfPresent(Decimal.self, forKey: .repaidAmount)
            ?? (wasReturned ? decodedOriginalAmount : 0)

        originalAmount = decodedOriginalAmount
        repaidAmount = min(max(decodedRepaidAmount, 0), decodedOriginalAmount)
        reason = try container.decode(String.self, forKey: .reason)
        date = try container.decode(Date.self, forKey: .date)
        returnedAt = try container.decodeIfPresent(Date.self, forKey: .returnedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(direction, forKey: .direction)
        try container.encode(personName, forKey: .personName)
        try container.encode(originalAmount, forKey: .originalAmount)
        try container.encode(repaidAmount, forKey: .repaidAmount)
        try container.encode(reason, forKey: .reason)
        try container.encode(date, forKey: .date)
        try container.encode(returnedAt, forKey: .returnedAt)
        try container.encode(createdAt, forKey: .createdAt)
    }

    var amount: Decimal {
        originalAmount
    }

    var remainingAmount: Decimal {
        ExpenseCalculations.debtRemaining(originalAmount: originalAmount, repaidAmount: repaidAmount)
    }

    var repaymentPercentage: Decimal {
        ExpenseCalculations.debtRepaymentPercentage(originalAmount: originalAmount, repaidAmount: repaidAmount)
    }

    var repaymentProgress: Double {
        NSDecimalNumber(decimal: repaymentPercentage / 100).doubleValue
    }

    var isFullyRepaid: Bool {
        repaidAmount == originalAmount
    }

    var isPartiallyRepaid: Bool {
        repaidAmount > 0 && repaidAmount < originalAmount
    }

    var isReturned: Bool {
        isFullyRepaid
    }

    func updatedRepaidAmount(_ amount: Decimal) -> Debt {
        let sanitizedAmount = min(max(amount, 0), originalAmount)
        return Debt(
            id: id,
            direction: direction,
            personName: personName,
            originalAmount: originalAmount,
            repaidAmount: sanitizedAmount,
            reason: reason,
            date: date,
            returnedAt: sanitizedAmount == originalAmount ? Date() : nil,
            createdAt: createdAt
        )
    }

    var statusText: String {
        statusText(for: .he)
    }

    func statusText(for language: AppLanguage) -> String {
        if isFullyRepaid {
            return direction == .owedToMe
                ? language.text(he: "הוחזר במלואו", en: "Fully repaid")
                : language.text(he: "שולם במלואו", en: "Fully paid")
        }

        if isPartiallyRepaid {
            return direction == .owedToMe
                ? language.text(he: "הוחזר חלקית", en: "Partially repaid")
                : language.text(he: "שולם חלקית", en: "Partially paid")
        }

        return language.text(he: "פתוח", en: "Open")
    }

    var reasonDisplayText: String {
        reasonDisplayText(for: .he)
    }

    func reasonDisplayText(for language: AppLanguage) -> String {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedReason.isEmpty ? language.text(he: "ללא סיבה", en: "No reason") : trimmedReason
    }

    var naturalSentence: String {
        naturalSentence(for: .he)
    }

    func naturalSentence(for language: AppLanguage) -> String {
        let amountText = originalAmount.hebrewShekelWords
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        switch direction {
        case .owedToMe:
            if trimmedReason.isEmpty {
                return language.text(
                    he: "\(personName) חייב לך \(amountText)",
                    en: "\(personName) owes you \(originalAmount.formattedShekelAmount)"
                )
            }

            return language.text(
                he: "\(personName) חייב לך \(amountText) על \(trimmedReason)",
                en: "\(personName) owes you \(originalAmount.formattedShekelAmount) for \(trimmedReason)"
            )
        case .iOwe:
            if trimmedReason.isEmpty {
                return language.text(
                    he: "אתה חייב ל\(personName) \(amountText)",
                    en: "You owe \(personName) \(originalAmount.formattedShekelAmount)"
                )
            }

            return language.text(
                he: "אתה חייב ל\(personName) \(amountText) על \(trimmedReason)",
                en: "You owe \(personName) \(originalAmount.formattedShekelAmount) for \(trimmedReason)"
            )
        }
    }

    var repaidLine: String {
        repaidLine(for: .he)
    }

    func repaidLine(for language: AppLanguage) -> String {
        switch direction {
        case .owedToMe:
            return language.text(
                he: "הוחזר: \(repaidAmount.formattedShekelAmount) מתוך \(originalAmount.formattedShekelAmount)",
                en: "Repaid: \(repaidAmount.formattedShekelAmount) of \(originalAmount.formattedShekelAmount)"
            )
        case .iOwe:
            return language.text(
                he: "שולם: \(repaidAmount.formattedShekelAmount) מתוך \(originalAmount.formattedShekelAmount)",
                en: "Paid: \(repaidAmount.formattedShekelAmount) of \(originalAmount.formattedShekelAmount)"
            )
        }
    }

    var percentageLine: String {
        percentageLine(for: .he)
    }

    func percentageLine(for language: AppLanguage) -> String {
        switch direction {
        case .owedToMe:
            return language.text(
                he: "\(repaymentPercentage.formattedPercentText) הוחזר",
                en: "\(repaymentPercentage.formattedPercentText) repaid"
            )
        case .iOwe:
            return language.text(
                he: "\(repaymentPercentage.formattedPercentText) שולם",
                en: "\(repaymentPercentage.formattedPercentText) paid"
            )
        }
    }

    var repaymentButtonTitle: String {
        repaymentButtonTitle(for: .he)
    }

    func repaymentButtonTitle(for language: AppLanguage) -> String {
        switch direction {
        case .owedToMe:
            return language.text(he: "התקבל החזר", en: "Received repayment")
        case .iOwe:
            return language.text(he: "שילמתי החזר", en: "I repaid")
        }
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

    func displayCategoryName(for language: AppLanguage) -> String {
        ExpenseCategory.localizedDefaultName(for: categoryId, language: language) ?? categoryName
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

    func displayName(for language: AppLanguage) -> String {
        ExpenseCategory.localizedDefaultName(for: categoryId, language: language) ?? categoryName
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
        netExpenseTotal(for: expenses)
    }

    func displayName(for language: AppLanguage) -> String {
        ExpenseCategory.localizedDefaultName(for: categoryId, language: language) ?? categoryName
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
        displayName(for: .he)
    }

    func displayName(for language: AppLanguage) -> String {
        let categoryName = ExpenseCategory.localizedDefaultName(for: originalCategoryId, language: language) ?? originalCategoryName
        return language.text(
            he: "שייך מחדש מ\(categoryName)",
            en: "Reassign from \(categoryName)"
        )
    }
}

private enum ExpenseSource: String, Codable {
    case regular
    case backfill
}

private enum ExpenseRefundStatus {
    case none
    case partial
    case full
}

private struct Expense: Identifiable, Codable {
    let id: UUID
    let categoryId: String
    let categoryName: String
    let amount: Decimal
    let refundedAmount: Decimal
    let createdAt: Date
    let modifiedAt: Date?
    let date: Date
    let name: String?
    let isRecurring: Bool
    let source: ExpenseSource
    let originalAmount: Decimal
    let originalCurrencyCode: String
    let exchangeRate: Decimal
    let exchangeRateDate: Date
    let convertedAmount: Decimal
    let convertedCurrencyCode: String

    init(
        id: UUID = UUID(),
        categoryId: String,
        categoryName: String,
        amount: Decimal,
        refundedAmount: Decimal = 0,
        createdAt: Date,
        modifiedAt: Date? = nil,
        date: Date? = nil,
        name: String?,
        isRecurring: Bool = false,
        source: ExpenseSource = .regular,
        originalAmount: Decimal? = nil,
        originalCurrencyCode: String? = nil,
        exchangeRate: Decimal = 1,
        exchangeRateDate: Date = Date(),
        convertedAmount: Decimal? = nil,
        convertedCurrencyCode: String? = nil
    ) {
        self.id = id
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.amount = amount
        self.refundedAmount = min(max(refundedAmount, 0), amount)
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.date = date ?? createdAt
        self.name = name
        self.isRecurring = isRecurring
        self.source = source
        self.originalAmount = originalAmount ?? amount
        self.originalCurrencyCode = originalCurrencyCode ?? Storage.loadCurrency().code
        self.exchangeRate = exchangeRate
        self.exchangeRateDate = exchangeRateDate
        self.convertedAmount = convertedAmount ?? amount
        self.convertedCurrencyCode = convertedCurrencyCode ?? Storage.loadCurrency().code
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId
        case categoryName
        case amount
        case refundedAmount
        case createdAt
        case modifiedAt
        case date
        case name
        case isRecurring
        case source
        case originalAmount
        case originalCurrencyCode
        case exchangeRate
        case exchangeRateDate
        case convertedAmount
        case convertedCurrencyCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        amount = try container.decode(Decimal.self, forKey: .amount)
        let decodedRefundedAmount = try container.decodeIfPresent(Decimal.self, forKey: .refundedAmount) ?? 0
        refundedAmount = min(max(decodedRefundedAmount, 0), amount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? createdAt
        name = try container.decodeIfPresent(String.self, forKey: .name)
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        source = try container.decodeIfPresent(ExpenseSource.self, forKey: .source) ?? .regular
        originalAmount = try container.decodeIfPresent(Decimal.self, forKey: .originalAmount) ?? amount
        originalCurrencyCode = try container.decodeIfPresent(String.self, forKey: .originalCurrencyCode) ?? Storage.loadCurrency().code
        exchangeRate = try container.decodeIfPresent(Decimal.self, forKey: .exchangeRate) ?? 1
        exchangeRateDate = try container.decodeIfPresent(Date.self, forKey: .exchangeRateDate) ?? createdAt
        convertedAmount = try container.decodeIfPresent(Decimal.self, forKey: .convertedAmount) ?? amount
        convertedCurrencyCode = try container.decodeIfPresent(String.self, forKey: .convertedCurrencyCode) ?? Storage.loadCurrency().code
    }

    func displayCategoryName(for language: AppLanguage) -> String {
        ExpenseCategory.localizedDefaultName(for: categoryId, language: language) ?? categoryName
    }

    func withName(_ name: String) -> Expense {
        return Expense(
            id: id,
            categoryId: categoryId,
            categoryName: categoryName,
            amount: amount,
            refundedAmount: refundedAmount,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            date: date,
            name: name,
            isRecurring: isRecurring,
            source: source,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            convertedAmount: convertedAmount,
            convertedCurrencyCode: convertedCurrencyCode
        )
    }

    func withCategory(_ category: ExpenseCategory) -> Expense {
        return Expense(
            id: id,
            categoryId: category.id,
            categoryName: category.name,
            amount: amount,
            refundedAmount: refundedAmount,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            date: date,
            name: name,
            isRecurring: isRecurring,
            source: source,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            convertedAmount: convertedAmount,
            convertedCurrencyCode: convertedCurrencyCode
        )
    }

    func updated(
        category: ExpenseCategory,
        amount: Decimal,
        refundedAmount: Decimal,
        date: Date,
        name: String,
        originalAmount: Decimal,
        originalCurrencyCode: String,
        exchangeRate: Decimal,
        exchangeRateDate: Date,
        convertedAmount: Decimal,
        convertedCurrencyCode: String
    ) -> Expense {
        return Expense(
            id: id,
            categoryId: category.id,
            categoryName: category.name,
            amount: amount,
            refundedAmount: refundedAmount,
            createdAt: createdAt,
            modifiedAt: Date(),
            date: date,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name,
            isRecurring: isRecurring,
            source: source,
            originalAmount: originalAmount,
            originalCurrencyCode: originalCurrencyCode,
            exchangeRate: exchangeRate,
            exchangeRateDate: exchangeRateDate,
            convertedAmount: convertedAmount,
            convertedCurrencyCode: convertedCurrencyCode
        )
    }

    var netAmount: Decimal {
        ExpenseCalculations.netExpenseAmount(amount: amount, refundedAmount: refundedAmount)
    }

    var refundStatus: ExpenseRefundStatus {
        if refundedAmount <= 0 {
            return .none
        }

        if refundedAmount >= amount {
            return .full
        }

        return .partial
    }

    func refundStatusText(for language: AppLanguage) -> String {
        switch refundStatus {
        case .none:
            return language.text(he: "ללא החזר", en: "No Refund")
        case .partial:
            return language.text(he: "החזר חלקי", en: "Partial Refund")
        case .full:
            return language.text(he: "החזר מלא", en: "Full Refund")
        }
    }

    func refundSummaryText(for language: AppLanguage) -> String? {
        let originalDetails: String? = originalCurrencyCode == convertedCurrencyCode ? nil : language.text(
            he: "מקור: \(originalAmount.plainString) \(originalCurrencyCode) · מומר: \(convertedAmount.formattedShekelAmount)",
            en: "Original: \(originalAmount.plainString) \(originalCurrencyCode) · Converted: \(convertedAmount.formattedShekelAmount)"
        )

        guard refundedAmount > 0 else {
            return originalDetails
        }

        let refundSummary = language.text(
            he: "מקורי: \(amount.formattedShekelAmount) · הוחזר: \(refundedAmount.formattedShekelAmount) · נטו: \(netAmount.formattedShekelAmount)",
            en: "Original: \(amount.formattedShekelAmount) · Refunded: \(refundedAmount.formattedShekelAmount) · Net: \(netAmount.formattedShekelAmount)"
        )

        if let originalDetails {
            return "\(originalDetails) · \(refundSummary)"
        }

        return refundSummary
    }
}

private struct SalaryEntry: Identifiable, Codable {
    let id: UUID
    let month: Int
    let year: Int
    let amount: Decimal
    let createdAt: Date

    init(id: UUID = UUID(), year: Int, month: Int, amount: Decimal, createdAt: Date) {
        self.id = id
        self.year = year
        self.month = month
        self.amount = amount
        self.createdAt = createdAt
    }

    var monthDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? createdAt
    }

    var monthName: String {
        monthName(for: .he)
    }

    func monthName(for language: AppLanguage) -> String {
        monthDate.monthYearText(for: language)
    }
}

private struct RestoreSnapshot: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let expenses: [Expense]
    let recurringExpenses: [RecurringExpense]
    let savings: [Saving]
    let savingGoals: [SavingGoal]
    let recurringSavings: [RecurringSaving]
    let debts: [Debt]
    let salaryEntries: [SalaryEntry]
    let categories: [ExpenseCategory]
    let deletedCategoryBuckets: [DeletedCategoryBucket]
    let userName: String
    let currency: CurrencyOption
    let appLanguage: AppLanguage
    let salaryReceiptDay: Int
    let checkingBalance: Decimal?
    let savingsGoal: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case expenses
        case recurringExpenses
        case savings
        case savingGoals
        case recurringSavings
        case debts
        case salaryEntries
        case categories
        case deletedCategoryBuckets
        case userName
        case currency
        case appLanguage
        case salaryReceiptDay
        case checkingBalance
        case savingsGoal
    }

    init(
        id: UUID = UUID(),
        createdAt: Date,
        expenses: [Expense],
        recurringExpenses: [RecurringExpense],
        savings: [Saving],
        savingGoals: [SavingGoal] = [],
        recurringSavings: [RecurringSaving] = [],
        debts: [Debt],
        salaryEntries: [SalaryEntry],
        categories: [ExpenseCategory],
        deletedCategoryBuckets: [DeletedCategoryBucket],
        userName: String,
        currency: CurrencyOption,
        appLanguage: AppLanguage,
        salaryReceiptDay: Int,
        checkingBalance: Decimal?,
        savingsGoal: Decimal?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.expenses = expenses
        self.recurringExpenses = recurringExpenses
        self.savings = savings
        self.savingGoals = savingGoals
        self.recurringSavings = recurringSavings
        self.debts = debts
        self.salaryEntries = salaryEntries
        self.categories = categories
        self.deletedCategoryBuckets = deletedCategoryBuckets
        self.userName = userName
        self.currency = currency
        self.appLanguage = appLanguage
        self.salaryReceiptDay = salaryReceiptDay
        self.checkingBalance = checkingBalance
        self.savingsGoal = savingsGoal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expenses = try container.decode([Expense].self, forKey: .expenses)
        recurringExpenses = try container.decode([RecurringExpense].self, forKey: .recurringExpenses)
        savings = try container.decode([Saving].self, forKey: .savings)
        savingGoals = try container.decodeIfPresent([SavingGoal].self, forKey: .savingGoals) ?? []
        recurringSavings = try container.decodeIfPresent([RecurringSaving].self, forKey: .recurringSavings) ?? []
        debts = try container.decode([Debt].self, forKey: .debts)
        salaryEntries = try container.decode([SalaryEntry].self, forKey: .salaryEntries)
        categories = try container.decode([ExpenseCategory].self, forKey: .categories)
        deletedCategoryBuckets = try container.decode([DeletedCategoryBucket].self, forKey: .deletedCategoryBuckets)
        userName = try container.decode(String.self, forKey: .userName)
        currency = try container.decode(CurrencyOption.self, forKey: .currency)
        appLanguage = try container.decode(AppLanguage.self, forKey: .appLanguage)
        salaryReceiptDay = try container.decode(Int.self, forKey: .salaryReceiptDay)
        checkingBalance = try container.decodeIfPresent(Decimal.self, forKey: .checkingBalance)
        savingsGoal = try container.decodeIfPresent(Decimal.self, forKey: .savingsGoal)
    }

    var displayTitle: String {
        displayTitle(for: .he)
    }

    func displayTitle(for language: AppLanguage) -> String {
        language.text(
            he: "איפוס מ־\(createdAt.localizedDateTimeText(for: language))",
            en: "Reset from \(createdAt.localizedDateTimeText(for: language))"
        )
    }
}

#if DEBUG
func debugRestoreSnapshotPreservesSavingModelsForTests() -> Bool {
    let goal = SavingGoal(
        name: "Unit Test Goal",
        targetAmount: 1000,
        location: .bank,
        createdAt: Date(timeIntervalSince1970: 1)
    )
    let recurringSaving = RecurringSaving(
        amount: 100,
        goalId: goal.id,
        startDate: Date(timeIntervalSince1970: 2),
        createdAt: Date(timeIntervalSince1970: 2)
    )
    let snapshot = RestoreSnapshot(
        createdAt: Date(timeIntervalSince1970: 3),
        expenses: [],
        recurringExpenses: [],
        savings: [],
        savingGoals: [goal],
        recurringSavings: [recurringSaving],
        debts: [],
        salaryEntries: [],
        categories: [],
        deletedCategoryBuckets: [],
        userName: "QA",
        currency: .ils,
        appLanguage: .en,
        salaryReceiptDay: 1,
        checkingBalance: nil,
        savingsGoal: nil
    )

    guard let data = try? JSONEncoder().encode(snapshot),
          let decoded = try? JSONDecoder().decode(RestoreSnapshot.self, from: data) else {
        return false
    }

    return decoded.savingGoals.map(\.id) == [goal.id]
        && decoded.recurringSavings.map(\.id) == [recurringSaving.id]
        && decoded.recurringSavings.first?.goalId == goal.id
}
#endif

private enum Storage {
    private static let expensesKey = "expenses"
    private static let recurringExpensesKey = "recurringExpenses"
    private static let savingsKey = "savings"
    private static let savingGoalsKey = "savingGoals"
    private static let recurringSavingsKey = "recurringSavings"
    private static let debtsKey = "debts"
    private static let salaryEntriesKey = "salaryEntries"
    private static let categoriesKey = "categories"
    private static let deletedCategoryBucketsKey = "deletedCategoryBuckets"
    private static let restoreSnapshotsKey = "restoreSnapshots"
    private static let appThemeKey = "appTheme"
    private static let userNameKey = "userName"
    private static let initialSetupCompletedKey = "initialSetupCompleted"
    private static let savingsGoalKey = "savingsGoal"
    private static let currencyKey = "currency"
    private static let appLanguageKey = "appLanguage"
    private static let dateDisplayFormatKey = "dateDisplayFormat"
    private static let salaryReceiptDayKey = "salaryReceiptDay"
    private static let checkingBalanceKey = "checkingBalance"
    private static let monthlyAnalyticsSnapshotsKey = "monthlyAnalyticsSnapshots"
    private static let currencyExchangeRatesKey = "currencyExchangeRates"
    private static let temporaryCurrencyKey = "temporaryCurrency"
    private static let temporaryCurrencyStartDateKey = "temporaryCurrencyStartDate"
    private static let temporaryCurrencyExpirationDateKey = "temporaryCurrencyExpirationDate"
    static let currencyRatesLastRefreshKey = "currencyRatesLastRefresh"

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

    static func loadSavings() -> [Saving] {
        guard let data = UserDefaults.standard.data(forKey: savingsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([Saving].self, from: data)) ?? []
    }

    static func saveSavings(_ savings: [Saving]) {
        guard let data = try? JSONEncoder().encode(savings) else {
            return
        }

        UserDefaults.standard.set(data, forKey: savingsKey)
    }

    static func loadSavingGoals() -> [SavingGoal] {
        guard let data = UserDefaults.standard.data(forKey: savingGoalsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([SavingGoal].self, from: data)) ?? []
    }

    static func saveSavingGoals(_ goals: [SavingGoal]) {
        guard let data = try? JSONEncoder().encode(goals) else {
            return
        }

        UserDefaults.standard.set(data, forKey: savingGoalsKey)
    }

    static func loadRecurringSavings() -> [RecurringSaving] {
        guard let data = UserDefaults.standard.data(forKey: recurringSavingsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([RecurringSaving].self, from: data)) ?? []
    }

    static func saveRecurringSavings(_ recurringSavings: [RecurringSaving]) {
        guard let data = try? JSONEncoder().encode(recurringSavings) else {
            return
        }

        UserDefaults.standard.set(data, forKey: recurringSavingsKey)
    }

    static func loadDebts() -> [Debt] {
        guard let data = UserDefaults.standard.data(forKey: debtsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([Debt].self, from: data)) ?? []
    }

    static func saveDebts(_ debts: [Debt]) {
        guard let data = try? JSONEncoder().encode(debts) else {
            return
        }

        UserDefaults.standard.set(data, forKey: debtsKey)
    }

    static func loadSalaryEntries() -> [SalaryEntry] {
        guard let data = UserDefaults.standard.data(forKey: salaryEntriesKey) else {
            return []
        }

        return (try? JSONDecoder().decode([SalaryEntry].self, from: data)) ?? []
    }

    static func saveSalaryEntries(_ entries: [SalaryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        UserDefaults.standard.set(data, forKey: salaryEntriesKey)
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

    static func loadRestoreSnapshots() -> [RestoreSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: restoreSnapshotsKey) else {
            return []
        }

        return ((try? JSONDecoder().decode([RestoreSnapshot].self, from: data)) ?? [])
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func saveRestoreSnapshots(_ snapshots: [RestoreSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        UserDefaults.standard.set(data, forKey: restoreSnapshotsKey)
    }

    static func appendRestoreSnapshot(_ snapshot: RestoreSnapshot) {
        var snapshots = loadRestoreSnapshots()
        snapshots.append(snapshot)
        saveRestoreSnapshots(snapshots.sorted { $0.createdAt > $1.createdAt })
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

    static func loadUserName() -> String? {
        UserDefaults.standard.string(forKey: userNameKey)
    }

    static func saveUserName(_ userName: String) {
        UserDefaults.standard.set(userName, forKey: userNameKey)
    }

    static func loadCurrency() -> CurrencyOption {
        guard let rawValue = UserDefaults.standard.string(forKey: currencyKey),
              let currency = CurrencyOption(rawValue: rawValue) else {
            return .ils
        }

        return currency
    }

    static func saveCurrency(_ currency: CurrencyOption) {
        UserDefaults.standard.set(currency.rawValue, forKey: currencyKey)
    }

    static func loadTemporaryCurrency(primaryCurrency: CurrencyOption) -> CurrencyOption {
        let now = Date()

        if let expirationDate = loadTemporaryCurrencyExpirationDate(), expirationDate <= now {
            clearTemporaryCurrency()
            return primaryCurrency
        }

        if let startDate = loadTemporaryCurrencyStartDate(), startDate > now {
            return primaryCurrency
        }

        guard let rawValue = UserDefaults.standard.string(forKey: temporaryCurrencyKey),
              let currency = CurrencyOption(rawValue: rawValue) else {
            return primaryCurrency
        }

        return currency
    }

    static func loadStoredTemporaryCurrency() -> CurrencyOption? {
        guard let rawValue = UserDefaults.standard.string(forKey: temporaryCurrencyKey) else {
            return nil
        }

        return CurrencyOption(rawValue: rawValue)
    }

    static func saveTemporaryCurrency(_ currency: CurrencyOption, startDate: Date, expirationDate: Date) {
        UserDefaults.standard.set(currency.rawValue, forKey: temporaryCurrencyKey)
        UserDefaults.standard.set(startDate, forKey: temporaryCurrencyStartDateKey)
        UserDefaults.standard.set(expirationDate, forKey: temporaryCurrencyExpirationDateKey)
    }

    static func loadTemporaryCurrencyStartDate() -> Date? {
        UserDefaults.standard.object(forKey: temporaryCurrencyStartDateKey) as? Date
    }

    static func loadTemporaryCurrencyExpirationDate() -> Date? {
        UserDefaults.standard.object(forKey: temporaryCurrencyExpirationDateKey) as? Date
    }

    static func clearTemporaryCurrency() {
        UserDefaults.standard.removeObject(forKey: temporaryCurrencyKey)
        UserDefaults.standard.removeObject(forKey: temporaryCurrencyStartDateKey)
        UserDefaults.standard.removeObject(forKey: temporaryCurrencyExpirationDateKey)
    }

    static func loadCurrencyExchangeRates() -> [String: CurrencyExchangeRate] {
        guard let data = UserDefaults.standard.data(forKey: currencyExchangeRatesKey) else {
            return ["ILS": CurrencyExchangeRate(currencyCode: "ILS", rateInILS: 1, unit: 1, rateDate: Date())]
        }

        var rates = (try? JSONDecoder().decode([String: CurrencyExchangeRate].self, from: data)) ?? [:]
        rates["ILS"] = CurrencyExchangeRate(currencyCode: "ILS", rateInILS: 1, unit: 1, rateDate: Date())
        return rates
    }

    static func saveCurrencyExchangeRates(_ rates: [String: CurrencyExchangeRate]) {
        guard let data = try? JSONEncoder().encode(rates) else {
            return
        }

        UserDefaults.standard.set(data, forKey: currencyExchangeRatesKey)
    }

    static func loadAppLanguage() -> AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: appLanguageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return .en
        }

        return language
    }

    static func saveAppLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: appLanguageKey)
    }

    static func loadDateDisplayFormat() -> DateDisplayFormat {
        guard let rawValue = UserDefaults.standard.string(forKey: dateDisplayFormatKey),
              let format = DateDisplayFormat(rawValue: rawValue) else {
            return .dayMonthYear
        }

        return format
    }

    static func saveDateDisplayFormat(_ format: DateDisplayFormat) {
        UserDefaults.standard.set(format.rawValue, forKey: dateDisplayFormatKey)
    }

    static func loadSalaryReceiptDay() -> Int {
        let day = UserDefaults.standard.integer(forKey: salaryReceiptDayKey)
        return day == 0 ? 1 : min(max(day, 1), 31)
    }

    static func saveSalaryReceiptDay(_ day: Int) {
        UserDefaults.standard.set(min(max(day, 1), 31), forKey: salaryReceiptDayKey)
    }

    static func loadCheckingBalance() -> Decimal? {
        guard let value = UserDefaults.standard.string(forKey: checkingBalanceKey),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func saveCheckingBalance(_ balance: Decimal?) {
        guard let balance else {
            UserDefaults.standard.removeObject(forKey: checkingBalanceKey)
            return
        }

        UserDefaults.standard.set(balance.plainString, forKey: checkingBalanceKey)
    }

    static func loadSavingsGoal() -> Decimal? {
        guard let value = UserDefaults.standard.string(forKey: savingsGoalKey),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func saveSavingsGoal(_ goal: Decimal?) {
        guard let goal else {
            UserDefaults.standard.removeObject(forKey: savingsGoalKey)
            return
        }

        UserDefaults.standard.set(goal.plainString, forKey: savingsGoalKey)
    }

    static func loadMonthlyAnalyticsSnapshots() -> [String: MonthlyAnalyticsSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: monthlyAnalyticsSnapshotsKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: MonthlyAnalyticsSnapshot].self, from: data)) ?? [:]
    }

    static func saveMonthlyAnalyticsSnapshots(_ snapshots: [String: MonthlyAnalyticsSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        UserDefaults.standard.set(data, forKey: monthlyAnalyticsSnapshotsKey)
    }

    static func saveMonthlyAnalyticsSnapshot(_ snapshot: MonthlyAnalyticsSnapshot) {
        var snapshots = loadMonthlyAnalyticsSnapshots()
        snapshots[snapshot.id] = snapshot
        saveMonthlyAnalyticsSnapshots(snapshots)
    }

    static func isInitialSetupCompleted() -> Bool {
        if UserDefaults.standard.object(forKey: initialSetupCompletedKey) != nil {
            return UserDefaults.standard.bool(forKey: initialSetupCompletedKey)
                && isValidSetupUserName(loadUserName() ?? "")
        }

        return isValidSetupUserName(loadUserName() ?? "")
    }

    static func saveInitialSetupCompleted(_ isCompleted: Bool) {
        UserDefaults.standard.set(isCompleted, forKey: initialSetupCompletedKey)
    }

    static func resetAllAppData() {
        [
            expensesKey,
            recurringExpensesKey,
            savingsKey,
            savingGoalsKey,
            recurringSavingsKey,
            debtsKey,
            salaryEntriesKey,
            categoriesKey,
            deletedCategoryBucketsKey,
            appThemeKey,
            userNameKey,
            savingsGoalKey,
            currencyKey,
            appLanguageKey,
            dateDisplayFormatKey,
            salaryReceiptDayKey,
            checkingBalanceKey,
            monthlyAnalyticsSnapshotsKey,
            currencyExchangeRatesKey,
            temporaryCurrencyKey,
            temporaryCurrencyStartDateKey,
            temporaryCurrencyExpirationDateKey,
            currencyRatesLastRefreshKey
        ].forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }

        saveCategories(ExpenseCategory.placeholderCategories)
        saveInitialSetupCompleted(false)
    }

    #if DEBUG
    private static let debugFoodExpenseID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    private static let debugShoppingExpenseID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
    private static let debugOpenDebtID = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
    private static let debugRepaidDebtID = UUID(uuidString: "00000000-0000-0000-0000-00000000D002")!
    private static let debugSavingGoalID = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    private static let debugSavingDepositID = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!
    private static let debugSavingWithdrawalID = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
    private static let debugSalaryEntryID = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    private static let debugIOweDebtID = UUID(uuidString: "00000000-0000-0000-0000-00000000D003")!
    private static let debugRecurringSavingID = UUID(uuidString: "00000000-0000-0000-0000-00000000B004")!
    private static let debugForeignCurrentExpenseID = UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!
    private static let debugForeignPastExpenseID = UUID(uuidString: "00000000-0000-0000-0000-00000000A004")!

    static func createDebugQATestData() {
        clearDebugQATestData()

        let foodDate = debugDate(year: 2026, month: 7, day: 7, hour: 10)
        let shoppingDate = debugDate(year: 2026, month: 7, day: 8, hour: 11)
        let debtDate = debugDate(year: 2026, month: 7, day: 9, hour: 12)
        let savingDate = debugDate(year: 2026, month: 7, day: 10, hour: 13)
        let withdrawalDate = debugDate(year: 2026, month: 7, day: 11, hour: 13)
        let salaryDate = debugDate(year: 2026, month: 7, day: 1, hour: 9)
        let futureExpenseDate = debugDate(year: 2026, month: 8, day: 3, hour: 10)
        let foreignCurrentDate = debugDate(year: 2026, month: 7, day: 10, hour: 14)
        let foreignPastDate = debugDate(year: 2026, month: 6, day: 15, hour: 14)

        var categories = loadCategories(defaults: ExpenseCategory.placeholderCategories)
        categories = categories.map { category in
            guard category.id == "food" else {
                return category
            }

            return category.updated(
                name: category.name,
                systemImageName: category.systemImageName,
                tintName: category.tintName,
                monthlyTarget: 100
            )
        }
        categories.append(contentsOf: [
            ExpenseCategory(id: "qa-below-target", name: "QA Below Target", systemImageName: "chart.bar", tintName: "green", monthlyTarget: 500),
            ExpenseCategory(id: "qa-exact-target", name: "QA Exact Target", systemImageName: "equal.circle", tintName: "blue", monthlyTarget: 300),
            ExpenseCategory(id: "qa-over-target", name: "QA Over Target", systemImageName: "exclamationmark.triangle", tintName: "red", monthlyTarget: 800),
            ExpenseCategory(id: "qa-no-target-long-category-name-for-layout-check", name: "QA Very Long Category Name For Layout And Wrapping", systemImageName: "textformat.size", tintName: "purple", monthlyTarget: nil)
        ])
        saveCategories(categories)

        var expenses = loadExpenses()
        expenses.append(contentsOf: [
            Expense(
                id: debugFoodExpenseID,
                categoryId: "food",
                categoryName: "אוכל",
                amount: 120,
                refundedAmount: 50,
                createdAt: foodDate,
                date: foodDate,
                name: "QA Food Partial Refund"
            ),
            Expense(
                id: debugShoppingExpenseID,
                categoryId: "shopping",
                categoryName: "קניות",
                amount: 80,
                refundedAmount: 80,
                createdAt: shoppingDate,
                date: shoppingDate,
                name: "QA Shopping Full Refund"
            ),
            Expense(
                id: debugUUID(101),
                categoryId: "qa-below-target",
                categoryName: "QA Below Target",
                amount: 450,
                createdAt: foodDate,
                date: foodDate,
                name: "QA Below Target July"
            ),
            Expense(
                id: debugUUID(102),
                categoryId: "qa-exact-target",
                categoryName: "QA Exact Target",
                amount: 300,
                createdAt: foodDate,
                date: foodDate,
                name: "QA Exact Target July"
            ),
            Expense(
                id: debugUUID(103),
                categoryId: "qa-over-target",
                categoryName: "QA Over Target",
                amount: 900,
                createdAt: foodDate,
                date: foodDate,
                name: "QA Over Target July"
            ),
            Expense(
                id: debugUUID(104),
                categoryId: "qa-no-target-long-category-name-for-layout-check",
                categoryName: "QA Very Long Category Name For Layout And Wrapping",
                amount: 123456,
                refundedAmount: 3456,
                createdAt: foodDate,
                date: foodDate,
                name: "QA Large Amount Long Category"
            ),
            Expense(
                id: debugUUID(105),
                categoryId: "food",
                categoryName: "אוכל",
                amount: 9999,
                createdAt: futureExpenseDate,
                date: futureExpenseDate,
                name: "QA Future Expense Must Not Affect July"
            ),
            Expense(
                id: debugForeignCurrentExpenseID,
                categoryId: "food",
                categoryName: "אוכל",
                amount: 35,
                createdAt: foreignCurrentDate,
                date: foreignCurrentDate,
                name: "QA Foreign Current USD",
                originalAmount: 10,
                originalCurrencyCode: CurrencyOption.usd.code,
                exchangeRate: 3.5,
                exchangeRateDate: foreignCurrentDate,
                convertedAmount: 35,
                convertedCurrencyCode: CurrencyOption.ils.code
            ),
            Expense(
                id: debugForeignPastExpenseID,
                categoryId: "qa-below-target",
                categoryName: "QA Below Target",
                amount: 80,
                createdAt: foreignPastDate,
                date: foreignPastDate,
                name: "QA Foreign Past EUR",
                originalAmount: 20,
                originalCurrencyCode: CurrencyOption.eur.code,
                exchangeRate: 4,
                exchangeRateDate: foreignPastDate,
                convertedAmount: 80,
                convertedCurrencyCode: CurrencyOption.ils.code
            )
        ])
        for month in 1...12 {
            let monthDate = debugDate(year: 2026, month: month, day: 15, hour: 10)
            expenses.append(Expense(
                id: debugUUID(200 + month),
                categoryId: "qa-below-target",
                categoryName: "QA Below Target",
                amount: Decimal(50 + month),
                createdAt: monthDate,
                date: monthDate,
                name: "QA 12 Month Expense \(month)"
            ))
        }
        saveExpenses(expenses.sorted { $0.date > $1.date })

        var debts = loadDebts()
        debts.append(contentsOf: [
            Debt(
                id: debugOpenDebtID,
                direction: .owedToMe,
                personName: "QA Partial Debt",
                originalAmount: 1000,
                repaidAmount: 300,
                reason: "QA debt repayment",
                date: debtDate,
                returnedAt: nil,
                createdAt: debtDate
            ),
            Debt(
                id: debugRepaidDebtID,
                direction: .owedToMe,
                personName: "QA Repaid Debt",
                originalAmount: 500,
                repaidAmount: 500,
                reason: "QA fully repaid debt",
                date: debtDate,
                returnedAt: debtDate,
                createdAt: debtDate
            ),
            Debt(
                id: debugIOweDebtID,
                direction: .iOwe,
                personName: "QA Debt I Owe",
                originalAmount: 750,
                repaidAmount: 250,
                reason: "QA opposite debt direction",
                date: debtDate,
                returnedAt: nil,
                createdAt: debtDate
            )
        ])
        saveDebts(debts.sorted { $0.date > $1.date })

        var savingGoals = loadSavingGoals()
        savingGoals.append(SavingGoal(
            id: debugSavingGoalID,
            name: "QA Saving Goal",
            targetAmount: 1000,
            location: .bank,
            createdAt: savingDate
        ))
        saveSavingGoals(savingGoals.sorted { $0.createdAt > $1.createdAt })

        var savings = loadSavings()
        savings.append(contentsOf: [
            Saving(
                id: debugSavingDepositID,
                amount: 250,
                kind: .deposit,
                location: .bank,
                date: savingDate,
                note: "QA deposit",
                goalId: debugSavingGoalID,
                createdAt: savingDate
            ),
            Saving(
                id: debugSavingWithdrawalID,
                amount: 100,
                kind: .withdrawal,
                location: .bank,
                date: withdrawalDate,
                note: "QA withdrawal",
                goalId: debugSavingGoalID,
                createdAt: withdrawalDate
            )
        ])
        saveSavings(savings.sorted { $0.date > $1.date })

        var recurringSavings = loadRecurringSavings()
        recurringSavings.append(RecurringSaving(
            id: debugRecurringSavingID,
            amount: 75,
            goalId: debugSavingGoalID,
            startDate: savingDate,
            createdAt: savingDate
        ))
        saveRecurringSavings(recurringSavings.sorted { $0.startDate > $1.startDate })

        var salaryEntries = loadSalaryEntries()
        salaryEntries.append(SalaryEntry(
            id: debugSalaryEntryID,
            year: 2026,
            month: 7,
            amount: 3000,
            createdAt: salaryDate
        ))
        saveSalaryEntries(salaryEntries.sorted { $0.monthDate > $1.monthDate })
    }

    static func clearDebugQATestData() {
        saveExpenses(loadExpenses().filter { expense in
            ![debugFoodExpenseID, debugShoppingExpenseID, debugForeignCurrentExpenseID, debugForeignPastExpenseID].contains(expense.id)
                && !(expense.name ?? "").hasPrefix("QA ")
        })
        saveDebts(loadDebts().filter { debt in
            ![debugOpenDebtID, debugRepaidDebtID, debugIOweDebtID].contains(debt.id)
                && !debt.personName.hasPrefix("QA ")
        })
        saveSavingGoals(loadSavingGoals().filter { goal in
            goal.id != debugSavingGoalID && !goal.name.hasPrefix("QA ")
        })
        saveCategories(loadCategories(defaults: ExpenseCategory.placeholderCategories).filter { !$0.id.hasPrefix("qa-") })
        saveSavings(loadSavings().filter { ![debugSavingDepositID, debugSavingWithdrawalID].contains($0.id) })
        saveRecurringSavings(loadRecurringSavings().filter { $0.id != debugRecurringSavingID })
        saveSalaryEntries(loadSalaryEntries().filter { $0.id != debugSalaryEntryID })
    }

    private static func debugUUID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }

    private static func debugDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour
        )) ?? Date()
    }
    #endif
}

#Preview {
    ContentView()
}
