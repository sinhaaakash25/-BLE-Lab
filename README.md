# BLE Lab

BLE Lab is a two-target SwiftUI sample project that demonstrates a production-style Bluetooth Low Energy central/peripheral workflow on Apple platforms.

The project contains:

- `DeviceLabCentral`: scans for a BLE peripheral, connects, discovers services and characteristics, reads data, subscribes to telemetry, and sends commands.
- `DeviceLabPeripheral`: advertises a custom BLE service, exposes readable/writable/notifiable characteristics, publishes telemetry, and handles central commands.
- `Shared`: contains the common BLE UUIDs, command definitions, and Codable payload models used by both targets.

## Architecture

Both targets follow a lightweight MVVM + Coordinator + Router structure:

- `App`: launches the target.
- `Coordinator`: creates long-lived dependencies and selects the active route.
- `Router`: owns navigation state.
- `ViewModel`: formats manager state for SwiftUI and forwards user actions.
- `Manager`: owns the CoreBluetooth implementation.
- `View`: displays state and sends user intent to the view model.

This keeps Bluetooth logic separate from presentation and makes the code easier to test, extend, and debug.

## BLE Contract

The shared service is defined in `Shared/BLEUUIDs.swift`.

The peripheral exposes one custom service:

```text
DeviceLab Service
├── Telemetry      read + notify
├── Command        write + write without response
├── Configuration  read + write
└── Device Info    read
```

The central scans specifically for the DeviceLab service UUID, connects to a matching peripheral, discovers the expected characteristics, then reads and subscribes to updates.

## Data Flow

Peripheral flow:

```text
Bluetooth powers on
    ↓
Peripheral configures service and characteristics
    ↓
Peripheral starts advertising
    ↓
Central connects
    ↓
Central reads, writes, or subscribes
    ↓
Peripheral responds and publishes telemetry
```

Central flow:

```text
Bluetooth powers on
    ↓
Central scans for DeviceLab service
    ↓
Central discovers peripheral
    ↓
User connects
    ↓
Central discovers service and characteristics
    ↓
Central reads device info and telemetry
    ↓
Central subscribes to telemetry notifications
    ↓
Central sends commands to the peripheral
```

## Running The Project

1. Open `DeviceLabCentral.xcodeproj` in Xcode.
2. Build and run the `DeviceLabPeripheral` target on one physical device.
3. Build and run the `DeviceLabCentral` target on another physical device.
4. Keep Bluetooth enabled on both devices.
5. Use the central app to discover, connect, read telemetry, and send commands.

CoreBluetooth behavior is best tested on physical devices. Simulator support for BLE workflows is limited.

## Production Notes

The sample includes practical edge-case handling for:

- Bluetooth powered off, unauthorized, unsupported, resetting, and unknown states.
- Scan start/stop flow.
- Connection failure and disconnect handling.
- Missing service or characteristic discovery failures.
- Read/write errors.
- Invalid telemetry decoding.
- Peripheral advertising failure.
- Subscriber count cleanup.

Good next production improvements would include:

- A richer connection state enum.
- Required-characteristic validation before marking a connection ready.
- Scan timeout and retry behavior.
- Notification backpressure handling with `peripheralManagerIsReady(toUpdateSubscribers:)`.
- Strict command validation.
- Persistent configuration state.
- Structured logging with Apple `Logger`.
- Unit tests for shared payload encoding and decoding.

## Author

Aakash Sinha
