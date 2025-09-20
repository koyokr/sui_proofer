# Sui Proofer

SMS verification overlay for incoming calls.

## Usage

1. Install and grant permissions (phone, SMS, overlay)
2. Receive incoming call → overlay appears
3. SMS with Sui address arrives → verification runs automatically
4. Green = verified, Red = failed, Gray = waiting

## Build

```bash
flutter pub get
flutter build apk --debug
```

## Development

```bash
dart fix
flutter analyze
```