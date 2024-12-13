import 'dart:async';
import 'dart:convert'; // for utf8 encoding/decoding
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

  void startDiscovery() {
    setState(() {
      isDiscovering = true;
      devices.clear(); // Clear previous results
    });

    discoveryStream = FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
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

  void sendData(String data) {
    if (connection != null && connection!.isConnected) {
      connection?.output.add(utf8.encode(data)); // Send data as UTF-8 encoded bytes
      connection?.output.allSent.then((_) {
        print("Sent: $data");
      });
    } else {
      print("No active connection to send data");
    }
  }

  void handleButtonPress(String command) {
    sendData("$command\n");
  }

  void handleButtonRelease() {
    sendData("STOP\n");
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
        backgroundColor: Color(0xFF333333),
        title: Text(
          'RC 조종기',
          style: TextStyle(fontSize: 18, color: Colors.white),
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
                    // Directional Buttons
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
                            // LEFT 버튼
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
                            // DOWN 버튼
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
                            // RIGHT 버튼
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
