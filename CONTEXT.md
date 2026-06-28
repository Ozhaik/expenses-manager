# Context

This is a local Xcode project for a native iPhone expense management app.

## Product Direction

Use:

- Xcode
- Swift
- SwiftUI
- Local-first architecture

Do not use:

- Web app architecture
- Python desktop UI
- React/Vite
- Backend services for the first version

The app should prioritize fast expense entry:

1. Choose a category.
2. Enter an amount.
3. Save the expense with the current date and time.

## Current Scope

The app opens to a quick expense entry screen.

Current behavior:

- Category image buttons are shown in the center.
- Categories can be browsed with arrow buttons or horizontal swipe/drag.
- Tapping a category selects it.
- Only an amount is requested after category selection.
- The amount field shows a shekel symbol.
- Amount input is sanitized to valid numeric values.
- Expenses are stored in memory first.

## Notes

- Keep this project separate from other repositories.
- Do not use browser previews as the main development environment.
- Use the local filesystem and local Git repository.
