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
        title: Text('Bluetooth Classic Example'),
        actions: [
          IconButton(
            icon: Icon(isDiscovering ? Icons.stop : Icons.search),
            onPressed: isDiscovering ? stopDiscovery : startDiscovery,
          ),
          if (isConnected)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: disconnectFromDevice,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index].device;
                return ListTile(
                  title: Text(device.name ?? "Unknown Device"),
                  subtitle: Text(device.address),
                  onTap: () => connectToDevice(device),
                );
              },
            ),
          ),
          if (isConnected)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    onSubmitted: sendData, // Send data on submit
                    decoration: InputDecoration(
                      labelText: "Enter data to send",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("Connected. You can send data."),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
