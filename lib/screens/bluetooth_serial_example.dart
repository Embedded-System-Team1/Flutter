import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothClassicExample extends StatefulWidget {
  @override
  _BluetoothClassicExampleState createState() => _BluetoothClassicExampleState();
}

class _BluetoothClassicExampleState extends State<BluetoothClassicExample> {
  List<BluetoothDiscoveryResult> devices = [];
  bool isDiscovering = false;

  @override
  void initState() {
    super.initState();
    startDiscovery();
  }

  void startDiscovery() {
    setState(() {
      isDiscovering = true;
    });

    FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
      setState(() {
        devices.add(result);
      });
    }).onDone(() {
      setState(() {
        isDiscovering = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Classic Example'),
        actions: [
          IconButton(
            icon: Icon(isDiscovering ? Icons.stop : Icons.search),
            onPressed: isDiscovering ? null : startDiscovery,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index].device;
          return ListTile(
            title: Text(device.name ?? "Unknown Device"),
            subtitle: Text(device.address),
            onTap: () async {
              try {
                final connection = await FlutterBluetoothSerial.instance
                    .connect(device);
                print("Connected to ${device.name}");
              } catch (e) {
                print("Error connecting to ${device.name}: $e");
              }
            },
          );
        },
      ),
    );
  }
}
