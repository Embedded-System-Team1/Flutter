import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothClassicExample extends StatefulWidget {
  @override
  _BluetoothClassicExampleState createState() =>
      _BluetoothClassicExampleState();
}

class _BluetoothClassicExampleState extends State<BluetoothClassicExample> {
  List<BluetoothDiscoveryResult> devices = [];
  StreamSubscription<BluetoothDiscoveryResult>? discoveryStream;
  BluetoothConnection? connection; // Bluetooth connection instance
  bool isDiscovering = false;
  bool isConnected = false;
  int currentSpeed = 0; // 현재 속도
  Timer? speedTimer; // Timer for speed increase
  bool autoLightEnabled = false; // 오토라이트 상태

  void startDiscovery() {
    setState(() {
      isDiscovering = true;
      devices.clear();
    });

    discoveryStream =
        FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
          // Add only devices with a name
          if (result.device.name != null && result.device.name!.isNotEmpty) {
            setState(() {
              // Avoid duplicate devices
              if (!devices.any((existingDevice) =>
              existingDevice.device.address == result.device.address)) {
                devices.add(result);
              }
            });
          }
        }, onDone: () {
          // Restart discovery if still discovering
          if (isDiscovering) {
            startDiscovery();
          }
        });
  }

  void stopDiscovery() {
    discoveryStream?.cancel();
    setState(() {
      isDiscovering = false;
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("Connecting to ${device.name}...");
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        isConnected = true;
      });
      print("Connected to ${device.name}");

      // Listen for incoming data
      connection?.input?.listen((data) {
        print('Received: ${utf8.decode(data)}'); // Decode incoming bytes
      }).onDone(() {
        print('Disconnected by remote');
        setState(() {
          isConnected = false;
          connection = null;
        });
      });
    } catch (e) {
      print("Error connecting to ${device.name}: $e");
    }
  }

  void disconnectFromDevice() {
    if (connection != null) {
      connection?.close();
      setState(() {
        isConnected = false;
        connection = null;
      });
      print("Disconnected");
    }
  }

  void sendJsonData(int id, int speed, int directionX, int directionY) {
    if (connection != null && connection!.isConnected) {
      final jsonData = jsonEncode({
        "id": id,
        "speed": speed,
        "directionX": directionX,
        "directionY": directionY,
      });

      connection?.output.add(utf8.encode("$jsonData\n")); // Send JSON as UTF-8 encoded bytes
      connection?.output.allSent.then((_) {
        print("Sent: $jsonData");
      });
    } else {
      print("No active connection to send data");
    }
  }

  void sendHornCommand(int hornState) {
    if (connection != null && connection!.isConnected) {
      final jsonData = jsonEncode({
        "id": 1, // ID for horn command
        "hornState": hornState, // 1: ON, 0: OFF
      });

      connection?.output.add(utf8.encode("$jsonData\n")); // Send JSON as UTF-8 encoded bytes
      connection?.output.allSent.then((_) {
        print("Sent Horn Command: $jsonData");
      });
    } else {
      print("No active connection to send data");
    }
  }

  void toggleAutoLightMode() {
    setState(() {
      autoLightEnabled = !autoLightEnabled; // Toggle state
    });

    int mode = autoLightEnabled ? 1 : 0; // 1: ON, 0: OFF
    if (connection != null && connection!.isConnected) {
      final jsonData = jsonEncode({
        "id": 2, // ID for auto light command
        "mode": mode, // 1: ON, 0: OFF
      });

      connection?.output.add(utf8.encode("$jsonData\n")); // Send JSON as UTF-8 encoded bytes
      connection?.output.allSent.then((_) {
        print("Sent AutoLight Command: $jsonData");
      });
    } else {
      print("No active connection to send data");
    }
  }

  void handleButtonPress(String direction) {
    int directionX = 0;
    int directionY = 0;

    switch (direction) {
      case "UP":
        directionY = 1; // Forward
        break;
      case "DOWN":
        directionY = -1; // Backward
        break;
      case "LEFT":
        directionX = -1; // Left
        break;
      case "RIGHT":
        directionX = 1; // Right
        break;
      default:
        directionX = 0;
        directionY = 0; // STOP or undefined
    }

    // Reset speed and start increasing
    currentSpeed = 400; // Initial speed
    speedTimer?.cancel(); // Cancel any existing timer
    speedTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (currentSpeed < 1000) {
        currentSpeed += 10; // Increment speed
      }
      if (currentSpeed > 1000) {
        currentSpeed = 1000; // Cap at 1000
      }
      sendJsonData(0, currentSpeed, directionX, directionY);
    });
  }

  void handleButtonRelease() {
    speedTimer?.cancel(); // Stop increasing speed
    currentSpeed = 0; // Reset speed
    sendJsonData(0, 0, 0, 0); // Send STOP command
  }

  @override
  void dispose() {
    discoveryStream?.cancel();
    connection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF1D2330),
        title: Text(
          'RC카 컨트롤러',
          style: TextStyle(fontSize: 18, color: Color(0xFF52B47A)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDiscovering ? Icons.stop : Icons.search),
            onPressed: isDiscovering ? stopDiscovery : startDiscovery,
            color: Colors.white,
          ),
          if (isConnected)
            IconButton(
              icon: Icon(Icons.close),
              color: Colors.white,
              onPressed: disconnectFromDevice,
            ),
        ],
      ),
      body: Container(
        color: Color(0xFF1D2330), // Set background color
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index].device;
                  return ListTile(
                    title: Text(
                      device.name ?? "Unknown Device",
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      device.address,
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () => connectToDevice(device),
                  );
                },
              ),
            ),
            if (isConnected)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "버튼을 눌러 자동차를 조종해보세요!",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTapDown: (_) => handleButtonPress("UP"),
                              onTapUp: (_) => handleButtonRelease(),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2E3646), // Set button color
                                  borderRadius: BorderRadius.circular(8), // Rounded corners
                                ),
                                child: Text(
                                  "↑",
                                  style: TextStyle(
                                    color: Color(0xFF9DA6B6), // Text color
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTapDown: (_) => handleButtonPress("LEFT"),
                              onTapUp: (_) => handleButtonRelease(),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2E3646), // Set button color
                                  borderRadius: BorderRadius.circular(8), // Rounded corners
                                ),
                                child: Text(
                                  "←",
                                  style: TextStyle(
                                    color: Color(0xFF9DA6B6), // Text color
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            GestureDetector(
                              onTapDown: (_) => handleButtonPress("DOWN"),
                              onTapUp: (_) => handleButtonRelease(),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2E3646), // Set button color
                                  borderRadius: BorderRadius.circular(8), // Rounded corners
                                ),
                                child: Text(
                                  "↓",
                                  style: TextStyle(
                                    color: Color(0xFF9DA6B6), // Text color
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            GestureDetector(
                              onTapDown: (_) => handleButtonPress("RIGHT"),
                              onTapUp: (_) => handleButtonRelease(),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2E3646), // Set button color
                                  borderRadius: BorderRadius.circular(8), // Rounded corners
                                ),
                                child: Text(
                                  "→",
                                  style: TextStyle(
                                    color: Color(0xFF9DA6B6), // Text color
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTapDown: (_) => sendHornCommand(1),
                              onTapUp: (_) => sendHornCommand(0),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2E3646), // Horn button color
                                  borderRadius: BorderRadius.circular(8), // Rounded corners
                                ),
                                child: Text(
                                  "Horn",
                                  style: TextStyle(
                                    color: Color(0xFF9DA6B6),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: toggleAutoLightMode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: autoLightEnabled
                                    ? Colors.green
                                    : Colors.grey,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                autoLightEnabled ? "AutoLight ON" : "AutoLight OFF",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
