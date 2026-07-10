# ExpenseManager Reliability QA Checklist

## Monthly Category Totals

1. Create a Food expense in July 2026 for 120 with a 50 refund.
2. Create a Food expense in August 2026 for 9999.
3. Set the system date/test context to July 2026 or use the DEBUG QA seed.
4. Open the main category carousel on Food.

Expected:
- July Food total uses only July net expenses.
- August expense does not affect the July category total.
- Food target shows 70 / 100 for the original QA seed case.

Broken logic indicator:
- July Food total includes the August 9999 expense.

## Reset / Restore

1. Create at least one saving goal.
2. Create at least one recurring saving linked to a goal.
3. Create savings, expenses, debts, salary entries, and category targets.
4. Open Settings -> Reset and restore.
5. Reset the app.
6. Complete the first-launch setup.
7. Open Settings -> Reset and restore -> restore the latest snapshot.

Expected:
- Saving goals are restored.
- Recurring savings are restored.
- Savings, expenses, debts, salary entries, categories, and category targets are restored.
- No old stale totals appear before restore after reset.

Broken logic indicator:
- Saving goals or recurring savings are missing after restore.
- Restore option is empty immediately after reset.

## DEBUG QA Seed

1. Open Settings in a DEBUG build.
2. Tap Create Test Data.
3. Review Past Data and Analytics across 12 months.

Expected:
- 12 monthly expense entries exist.
- Below-target, exact-target, over-target, no-target, long-name, large-amount, future-expense, both debt directions, partial repayment, and full repayment cases exist.
- Future expense does not affect the current month total.
