import XCTest
@testable import ExpenseManager

final class ExpenseCalculationsTests: XCTestCase {
    func testBudgetAtHalfTarget() {
        let budget = ExpenseCalculations.budget(spentAmount: 1000, targetAmount: 2000)

        XCTAssertEqual(budget?.usedPercentage, 50)
        XCTAssertEqual(budget?.remainingAmount, 1000)
        XCTAssertEqual(budget?.overBudgetAmount, 0)
        XCTAssertNil(budget?.overBudgetPercentage)
    }

    func testBudgetOverTarget() {
        let budget = ExpenseCalculations.budget(spentAmount: 900, targetAmount: 800)

        XCTAssertEqual(budget?.remainingAmount, 0)
        XCTAssertEqual(budget?.overBudgetAmount, 100)
        XCTAssertEqual(budget?.overBudgetPercentage, 12.5)
    }

    func testNoTargetReturnsNoBudget() {
        XCTAssertNil(ExpenseCalculations.budget(spentAmount: 500, targetAmount: nil))
        XCTAssertNil(ExpenseCalculations.budget(spentAmount: 500, targetAmount: 0))
    }

    func testUndoDurationIsClampedToSupportedRange() {
        XCTAssertEqual(ExpenseCalculations.clampedUndoDuration(-1), 1)
        XCTAssertEqual(ExpenseCalculations.clampedUndoDuration(3), 3)
        XCTAssertEqual(ExpenseCalculations.clampedUndoDuration(9), 5)
    }

    func testMonthlySummaryTotalTargetProgressIncludesUntargetedCategories() {
        let calendar = Calendar(identifier: .gregorian)
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let foodSpent = Decimal(string: "680.48")!
        let homeSpent = Decimal(string: "5010.4")!
        let shoppingSpent = Decimal(string: "300517.36")!
        let totalSpent = Decimal(string: "306208.24")!
        let foodTarget = Decimal(string: "100")!
        let entries = [
            ExpenseCalculations.DatedNetAmount(categoryId: "food", date: july, netAmount: foodSpent),
            ExpenseCalculations.DatedNetAmount(categoryId: "home", date: july, netAmount: homeSpent),
            ExpenseCalculations.DatedNetAmount(categoryId: "shopping", date: july, netAmount: shoppingSpent)
        ]
        let progress = ExpenseCalculations.monthlyTargetProgress(
            for: entries,
            categoryTargets: [
                "food": foodTarget
            ],
            month: july,
            calendar: calendar
        )

        XCTAssertEqual(progress?.spentAmount, totalSpent)
        XCTAssertEqual(progress?.targetAmount, foodTarget)
        XCTAssertEqual(progress?.budget.overBudgetAmount, Decimal(string: "306108.24")!)
        XCTAssertEqual(
            ExpenseCalculations.monthlyNetExpenseTotal(
                for: entries,
                categoryId: "food",
                month: july,
                calendar: calendar
            ),
            foodSpent
        )
    }

    func testFullRefundMakesNetExpenseZero() {
        XCTAssertEqual(ExpenseCalculations.netExpenseAmount(amount: 80, refundedAmount: 80), 0)
    }

    func testPartialRefundReducesNetExpense() {
        XCTAssertEqual(ExpenseCalculations.netExpenseAmount(amount: 120, refundedAmount: 50), 70)
    }

    func testFutureMonthExpenseIsNotCountedInCurrentMonthTotal() {
        let calendar = Calendar(identifier: .gregorian)
        let currentMonth = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let currentExpenseDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 7))!
        let futureMonth = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let entries = [
            ExpenseCalculations.DatedNetAmount(categoryId: "food", date: currentExpenseDate, netAmount: 70),
            ExpenseCalculations.DatedNetAmount(categoryId: "food", date: futureMonth, netAmount: 9999)
        ]

        XCTAssertEqual(
            ExpenseCalculations.monthlyNetExpenseTotal(
                for: entries,
                categoryId: "food",
                month: currentMonth,
                calendar: calendar
            ),
            70
        )
    }

    func testBackfilledExpenseFiltersIntoHistoricalMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let june = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let entries = [
            ExpenseCalculations.DatedNetAmount(categoryId: "food", date: june, netAmount: 33),
            ExpenseCalculations.DatedNetAmount(categoryId: "food", date: july, netAmount: 70)
        ]

        XCTAssertEqual(
            ExpenseCalculations.monthlyNetExpenseTotal(for: entries, categoryId: "food", month: june, calendar: calendar),
            33
        )
        XCTAssertEqual(
            ExpenseCalculations.monthlyNetExpenseTotal(for: entries, categoryId: "food", month: july, calendar: calendar),
            70
        )
    }

    func testPastForeignCurrencyRequiresHistoricalRate() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let past = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!

        XCTAssertTrue(ExpenseCalculations.requiresHistoricalExchangeRate(
            expenseDate: past,
            sourceCurrencyCode: "USD",
            primaryCurrencyCode: "ILS",
            referenceDate: today,
            calendar: calendar
        ))
        XCTAssertFalse(ExpenseCalculations.requiresHistoricalExchangeRate(
            expenseDate: today,
            sourceCurrencyCode: "USD",
            primaryCurrencyCode: "ILS",
            referenceDate: today,
            calendar: calendar
        ))
        XCTAssertFalse(ExpenseCalculations.requiresHistoricalExchangeRate(
            expenseDate: past,
            sourceCurrencyCode: "ILS",
            primaryCurrencyCode: "ILS",
            referenceDate: today,
            calendar: calendar
        ))
    }

    func testDebtRepaymentIsClamped() {
        XCTAssertEqual(ExpenseCalculations.debtRemaining(originalAmount: 500, repaidAmount: 700), 0)
        XCTAssertEqual(ExpenseCalculations.debtRepaymentPercentage(originalAmount: 500, repaidAmount: 700), 100)
        XCTAssertEqual(ExpenseCalculations.debtRemaining(originalAmount: 500, repaidAmount: -50), 500)
    }

    func testSavingsBalanceHandlesDepositsAndWithdrawals() {
        XCTAssertEqual(ExpenseCalculations.savingsBalance(deposits: 250, withdrawals: 100), 150)
        XCTAssertEqual(ExpenseCalculations.savingsBalance(deposits: 5, withdrawals: 6), -1)
    }

    func testRestoreSnapshotPreservesSavingGoalsAndRecurringSavings() {
        XCTAssertTrue(debugRestoreSnapshotPreservesSavingModelsForTests())
    }
}
