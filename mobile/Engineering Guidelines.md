# Engineering Guidelines

Follow these rules for every code change in this repository.

## General principles

* Write clean, readable, maintainable code from the beginning.
* Do not wait until the end of the task to refactor obvious code-quality issues.
* Preserve the existing project architecture and naming conventions.
* Prefer the smallest correct change that fully solves the task.
* Do not introduce unnecessary abstractions, packages, layers, or patterns.
* Do not rewrite unrelated code.
* Do not change existing behavior unless the task explicitly requires it.

## Flutter and Dart guidelines

* Follow Dart and Flutter best practices.
* Use `const` constructors wherever possible.
* Keep widgets small and focused on one responsibility.
* Avoid deeply nested widget trees where extraction improves readability.
* Extract repeated UI into reusable widgets.
* Do not extract one-off widgets only to reduce line count.
* Avoid large private `_buildSomething()` methods.
* Prefer dedicated `StatelessWidget` or `StatefulWidget` classes for meaningful UI sections.
* Keep business logic out of widget `build()` methods.
* Keep API calls, filtering, data transformation, and business rules in the appropriate Bloc, Cubit, ViewModel, controller, repository, or service.
* Use the state-management approach already used by the feature.
* Do not introduce another state-management library.

## File responsibility

Each file should have one clear responsibility.

* Pages compose major screen sections.
* Sections organize related UI.
* Reusable widgets render focused UI components.
* Models represent data.
* Controllers, Cubits, Blocs, or ViewModels manage state.
* Repositories and services handle data access and external communication.

When adding new code, place it in the appropriate existing layer instead of putting everything in the current file.

## File size

Do not optimize for an arbitrary line-count limit.

However:

* Avoid creating new page files that mix layout, state, models, styling, and business logic.
* If a page becomes difficult to understand, extract meaningful sections before continuing.
* A page should normally remain a high-level composition file.
* Do not allow a single new widget or page to grow excessively when responsibilities can be separated naturally.
* Before adding a large block of code to an already large file, check whether it belongs in a dedicated widget, model, mapper, or controller.

## Reusability and duplication

* Avoid duplicated widgets, styles, conditions, and mappings.
* Reuse existing project components before creating new ones.
* Use the existing `ThemeData`, `AppColors`, text theme, spacing, radius, and decoration tokens.
* Do not hard-code arbitrary colors, font sizes, spacing, or border radii when a design token already exists.
* Extract shared code only when there is real duplication or a clear shared responsibility.
* Avoid premature generic abstractions.

## Naming

* Use descriptive names that express intent.
* Avoid vague names such as `data`, `item`, `temp`, `widget1`, or `handleStuff`.
* Use nouns for models and widgets.
* Use verbs for methods and commands.
* Use boolean names beginning with `is`, `has`, `can`, or `should`.
* Follow the naming style already used in the project.

## Functions and methods

* Keep functions focused on one task.
* Prefer early returns over deeply nested conditions.
* Avoid methods with many unrelated parameters.
* Avoid hidden side effects.
* Do not place complex expressions directly inside widget trees when a named variable improves clarity.

## Models and type safety

* Prefer typed models and enums over raw maps and string comparisons.
* Avoid using magic strings for statuses, event types, and severity levels.
* Preserve null safety.
* Do not use `dynamic` unless required by an external API boundary.
* Use immutable objects where practical.

## Error handling

* Do not silently swallow exceptions.
* Handle loading, success, empty, and error states explicitly.
* Show user-friendly messages in the UI.
* Keep technical error details in logs rather than exposing them directly to users.
* Preserve existing error-handling conventions.

## Comments

* Write comments only when they explain why something exists or clarify a non-obvious decision.
* Do not add comments that merely repeat what the code already says.
* Remove obsolete and misleading comments.
* Public APIs should have documentation when the project convention requires it.

## Before editing

Before writing code:

1. Inspect the relevant files and nearby implementations.
2. Identify the existing architecture and reusable components.
3. Determine where the new responsibility belongs.
4. Check whether the requested feature can be implemented without increasing duplication or coupling.
5. Make a focused implementation plan.

For small tasks, proceed after inspection without producing a long written plan.

## During implementation

While implementing:

* Continuously keep responsibilities separated.
* Do not first create a large monolithic implementation with the intention of refactoring later.
* Reuse existing helpers and components.
* Keep changes scoped to the requested feature.
* Preserve backward compatibility where applicable.

## Validation

After every meaningful change:

* Run `dart format` on modified Dart files.
* Run `flutter analyze`.
* Run relevant tests if they exist.
* Fix warnings and errors introduced by the change.
* Do not claim that validation passed unless the commands were actually run successfully.

## Final response

At the end of the task, report:

1. What was changed.
2. Which files were created or modified.
3. Important design decisions.
4. Validation commands and results.
5. Any remaining limitations.

Do not include unrelated recommendations unless they are important for correctness or maintainability.
## Navigation

* Use `GoRouter` for all application navigation.
* Use `context.go`, `context.push`, `context.replace`, or named-route equivalents according to the existing routing convention.
* Do not use `Navigator.push`, `Navigator.pushReplacement`, or `Navigator.pop` for normal page navigation.
* Direct `Navigator` usage is allowed only for local overlays such as dialogs, modal bottom sheets, and other temporary routes where appropriate.
* Reuse existing route names, route paths, and navigation helpers.
* Do not hard-code route strings in widgets when a route constant or named route already exists.
* Keep navigation decisions at the page, coordinator, or Bloc listener level rather than inside low-level reusable widgets.
* Reusable widgets should expose callbacks instead of navigating directly unless navigation is explicitly their responsibility.

## BLoC naming conventions

Use consistent, intent-based names for BLoC events.

Preferred event suffixes:

* `Started` for initial loading or feature initialization.
* `Refreshed` for explicitly reloading existing data.
* `Tapped` for direct user taps that represent a meaningful application action.
* `Changed` for input, selection, filter, toggle, or form value changes.
* `Submitted` for form or confirmation submissions.
* `Selected` for choosing an item from a collection.
* `Created` for create operations.
* `Updated` for update operations.
* `Deleted` for delete operations.
* `Confirmed` and `Cancelled` for confirmation flows.
* `RetryRequested` for retrying a failed operation.

Examples:

* `HomeStarted`
* `EventFilterChanged`
* `EmergencyContactTapped`
* `MonitoringPauseConfirmed`
* `CaregiverSelected`
* `SafetyEventDeleted`
* `IncidentReportSubmitted`

Avoid inconsistent names such as:

* `OnButtonPressed`
* `ButtonClick`
* `HandleTap`
* `DoRefresh`
* `FetchDataEvent`

Event names should describe the user's intent or domain action, not the UI implementation detail.

State classes should describe the feature state clearly and follow the existing project convention. Do not introduce a different state style within the same feature.

## User-facing language and assets

* All user-facing strings must be written in Vietnamese unless the task explicitly requires another language.
* Do not mix Vietnamese and English in the same user interface.
* Code identifiers, class names, file names, comments, and technical logs should remain in English.
* Reuse existing asset constants, generated asset accessors, localization keys, or asset helpers.
* Do not hard-code asset paths repeatedly inside widgets.
* Do not introduce a localization package unless the project already uses one or the task explicitly requires localization.
* Keep repeated user-facing strings in the project's existing string-constant or localization structure.
* Preserve Vietnamese diacritics and use natural, user-friendly wording.
* Error messages shown to users must be understandable and must not expose raw exceptions or technical stack traces.

## Standard UI fallback states

Every asynchronous screen or section must explicitly handle:

* initial state
* loading state
* success state
* empty state
* error state

Unless the existing feature uses another established component, use the following defaults:

### Loading

* Display a centered `CircularProgressIndicator`.
* Use `AppColors.primary` or the current theme color.
* Avoid blocking the entire screen when only one section is loading.
* Preserve existing content during background refresh when possible.

Example:

```dart
const Center(
  child: CircularProgressIndicator(),
)
```

### Empty

* Show a clear Vietnamese message explaining that no data is currently available.
* Include a retry or primary action only when it is useful.
* Do not display an empty `ListView`, blank screen, or silent placeholder.

### Error

* Show a user-friendly Vietnamese error message.
* Provide a retry action when the operation can be retried.
* Log technical details through the existing logging mechanism.
* Do not show raw exceptions directly to users.

### Success

* Render from typed state data.
* Do not assume collections are non-empty.
* Handle optional and missing values safely.

### Refreshing

* Distinguish initial loading from background refresh.
* Do not replace already loaded content with a full-screen loading indicator during refresh unless required by the current UX.
