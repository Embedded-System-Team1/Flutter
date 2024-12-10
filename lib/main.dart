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
  final List<ScanResult> devicesList = [];
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

    // 기존 리스너가 있으면 해제
    scanSubscription?.cancel();
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      print("Scan results: ${results.length} devices found");
      for (ScanResult result in results) {
        print('Device: ${result.device.name}, ID: ${result.device.id}');
        if (!devicesList.any((item) => item.device.id == result.device.id)) {
          setState(() {
            devicesList.add(result);
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
                ? Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ],
            )
                : Icon(Icons.search),
            onPressed: isScanning ? null : scanForDevices,
          ),
        ],
      ),
      body: connectedDevice == null
          ? ListView.builder(
        itemCount: devicesList.length,
        itemBuilder: (context, index) {
          final result = devicesList[index];
          return ListTile(
            title: Text(
              result.device.name.isEmpty
                  ? 'Unknown Device (${result.device.id})'
                  : result.device.name,
            ),
            subtitle: Text('ID: ${result.device.id}\nRSSI: ${result.rssi}'),
            onTap: () => connectToDevice(result.device),
          );
        },
      )
          : Column(
        children: [
          Text(
            'Connected to: ${connectedDevice!.name.isEmpty ? 'Unknown Device' : connectedDevice!.name}',
          ),
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
