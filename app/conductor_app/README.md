# conductor_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS real device: HTTP backend

When running on a physical iOS device, `localhost` points to the phone, not your Mac. To connect to the local backend over HTTP:

- Ensure the backend listens on all interfaces: run `make run` (binds `HOST=0.0.0.0`).
- Make sure the phone and your Mac are on the same network.
- Launch the app with your Mac's IP injected:
  - `make run-ios` will auto-detect your IP and pass `--dart-define=API_BASE_URL=http://<your-ip>:4000` and `--dart-define=WS_URL=ws://<your-ip>:4000/ws/app`.
  - If auto-detection fails, run `make run-ios HOST_IP=192.168.x.x`.

The iOS `Info.plist` is configured to allow cleartext HTTP for development via App Transport Security.
