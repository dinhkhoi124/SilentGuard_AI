# Project: SlientGuard Flutter App
## Stack: Flutter 3.x, BLoC, GoRouter, GetIt, Clean Architecture
## Navigation: GoRouter only. Navigator.push/pop ONLY for dialogs/bottom sheets.
## State: HomeBloc owns home+device state. AuthNotifier owns auth state.
## Language: All user-facing strings in Vietnamese.
## Routes: /welcome → /signup | /signin → /home → /camera/:id
## Bottom nav: custom widget in home/presentation/widgets/bottom_nav_bar.dart
## Conventions: see ENGINEERING_GUIDELINES.md