# GitLane

A premium Git client for mobile, powered by a native C bridge.

## Project Structure

- **lib/main.dart**: Entry point for the Flutter application.
- **lib/services/**: contains `GitService`, the bridge to the native Git implementation.
- **lib/ui/**: Premium UI components and screens.
    - **screens/home/**: Dashboard for repository management.
    - **screens/repository/**: Repository management hub (Explorer, History, Status).
    - **screens/commit/**: Detailed diff viewer and commit information.
    - **theme/**: Custom dark theme with glassmorphism support.
    - **widgets/**: Reusable UI components like `GlassCard`.

## Key Features

- **Native Git Bridge**: Efficient Git operations via `MethodChannel` to a custom C library.
- **Premium UI**: Modern dark theme with glassmorphic effects and dynamic gradients.
- **Diff Viewer**: Stylized, color-coded visualization of code changes.
- **Conflict Resolution**: Integrated 3-way merge interface.

## Getting Started

1. **Install Git LFS**: Ensure Git Large File Storage is installed on your system.
2. **Setup Flutter**: Run `flutter pub get` in the `gitlane` directory.
3. **Run Application**: Use `flutter run` or launch via Android Studio/VS Code.

## Development

This project unifies the work from `flutter-ui` (Interface) and `native-core` (Backend Logic).

- **Architecture**: The UI communicates with `GitService` which invokes native methods via the `git_channel`.
- **Assets**: Large native binaries and assets are managed via Git LFS.

---
Part of the Saasuke-Clan project.
