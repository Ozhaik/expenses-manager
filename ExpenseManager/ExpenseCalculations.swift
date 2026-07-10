import Foundation

struct BudgetCalculation {
    let spentAmount: Decimal
    let targetAmount: Decimal

    var usedPercentage: Decimal? {
        guard targetAmount > 0 else {
            return nil
        }

        return spentAmount / targetAmount * 100
    }

    var remainingAmount: Decimal {
        max(targetAmount - spentAmount, 0)
    }

    var overBudgetAmount: Decimal {
        max(spentAmount - targetAmount, 0)
    }

    var overBudgetPercentage: Decimal? {
        guard targetAmount > 0, overBudgetAmount > 0 else {
            return nil
        }

        return overBudgetAmount / targetAmount * 100
    }
}

enum ExpenseCalculations {
    struct DatedNetAmount {
        let categoryId: String
        let date: Date
        let netAmount: Decimal
    }

    static func netExpenseAmount(amount: Decimal, refundedAmount: Decimal) -> Decimal {
        let sanitizedAmount = max(amount, 0)
        let sanitizedRefund = min(max(refundedAmount, 0), sanitizedAmount)
        return max(sanitizedAmount - sanitizedRefund, 0)
    }

    static func netExpenseTotal(_ netAmounts: [Decimal]) -> Decimal {
        max(netAmounts.reduce(Decimal(0), +), 0)
    }

    static func isDate(_ date: Date, inSameMonthAs month: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    static func monthlyNetExpenseTotal(
        for entries: [DatedNetAmount],
        categoryId: String? = nil,
        month: Date,
        calendar: Calendar = .current
    ) -> Decimal {
        let monthlyAmounts = entries.compactMap { entry -> Decimal? in
            guard isDate(entry.date, inSameMonthAs: month, calendar: calendar) else {
                return nil
            }

            if let categoryId, entry.categoryId != categoryId {
                return nil
            }

            return entry.netAmount
        }

        return netExpenseTotal(monthlyAmounts)
    }

    static func budget(spentAmount: Decimal, targetAmount: Decimal?) -> BudgetCalculation? {
        guard let targetAmount, targetAmount > 0 else {
            return nil
        }

        return BudgetCalculation(spentAmount: spentAmount, targetAmount: targetAmount)
    }

    static func savingsBalance(deposits: Decimal, withdrawals: Decimal) -> Decimal {
        deposits - withdrawals
    }

    static func debtRemaining(originalAmount: Decimal, repaidAmount: Decimal) -> Decimal {
        max(max(originalAmount, 0) - min(max(repaidAmount, 0), max(originalAmount, 0)), 0)
    }

    static func debtRepaymentPercentage(originalAmount: Decimal, repaidAmount: Decimal) -> Decimal {
        let originalAmount = max(originalAmount, 0)
        guard originalAmount > 0 else {
            return 0
        }

        let clampedRepaidAmount = min(max(repaidAmount, 0), originalAmount)
        return clampedRepaidAmount / originalAmount * 100
    }
}
