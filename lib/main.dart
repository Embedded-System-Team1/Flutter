import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BluetoothSerialExample(),
    );
  }
}

class BluetoothSerialExample extends StatefulWidget {
  @override
  _BluetoothSerialExampleState createState() => _BluetoothSerialExampleState();
}

class _BluetoothSerialExampleState extends State<BluetoothSerialExample> {
  final List<BluetoothDevice> devicesList = [];
  BluetoothDevice? connectedDevice;
  List<BluetoothService>? bluetoothServices;
  StreamSubscription? scanSubscription;

  bool isScanning = false;

  void scanForDevices() {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      devicesList.clear();
    });

    print("Starting Bluetooth scan...");
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4)).then((_) {
      print("Bluetooth scan complete");
      setState(() {
        isScanning = false;
      });
    });

    FlutterBluePlus.scanResults.listen((results) {
      print("Scan results: ${results.length} devices found");
      for (ScanResult result in results) {
        print('Device: ${result.device.name}, ID: ${result.device.id}');
        if (!devicesList.any((device) => device.id == result.device.id)) {
          setState(() {
            devicesList.add(result.device);
          });
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
      });

      bluetoothServices = await device.discoverServices();
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  void disconnectFromDevice() {
    connectedDevice?.disconnect();
    setState(() {
      connectedDevice = null;
      bluetoothServices = null;
    });
  }

  void sendData(
      BluetoothService service, BluetoothCharacteristic characteristic, String data) async {
    try {
      await characteristic.write(utf8.encode(data), withoutResponse: true);
    } catch (e) {
      print('Error sending data: $e');
    }
  }

  void receiveData(BluetoothCharacteristic characteristic) async {
    try {
      characteristic.value.listen((value) {
        print('Received data: ${utf8.decode(value)}');
      });
      await characteristic.setNotifyValue(true);
    } catch (e) {
      print('Error receiving data: $e');
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Serial Example'),
        actions: [
          IconButton(
            icon: isScanning
                ? CircularProgressIndicator(color: Colors.white)
                : Icon(Icons.search),
            onPressed: scanForDevices,
          ),
        ],
      ),
      body: connectedDevice == null
          ? ListView.builder(
        itemCount: devicesList.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(devicesList[index].name.isEmpty
                ? 'Unknown Device'
                : devicesList[index].name),
            subtitle: Text(devicesList[index].id.toString()),
            onTap: () => connectToDevice(devicesList[index]),
          );
        },
      )
          : Column(
        children: [
          Text('Connected to: ${connectedDevice!.name.isEmpty ? 'Unknown Device' : connectedDevice!.name}'),
          ElevatedButton(
            onPressed: disconnectFromDevice,
            child: Text('Disconnect'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: bluetoothServices?.length ?? 0,
              itemBuilder: (context, index) {
                BluetoothService service = bluetoothServices![index];
                return ExpansionTile(
                  title: Text('Service: ${service.uuid}'),
                  children: service.characteristics.map((characteristic) {
                    return ListTile(
                      title: Text('Characteristic: ${characteristic.uuid}'),
                      onTap: () {
                        sendData(service, characteristic, 'Hello Raspberry Pi');
                        receiveData(characteristic);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
