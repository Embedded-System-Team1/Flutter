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
  final Map<String, ScanResult> devicesMap = {};
  BluetoothDevice? connectedDevice;
  List<BluetoothService>? bluetoothServices;
  StreamSubscription? scanSubscription;

  bool isScanning = false;

  void scanForDevices() {
    if (isScanning) return;

    setState(() {
      isScanning = true;
    });

    print("Starting Bluetooth scan...");
    FlutterBluePlus.startScan(); // timeout 제거

    scanSubscription?.cancel();
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // MAC 주소로 중복 확인 후 추가
        final deviceId = result.device.id.toString();
        if (!devicesMap.containsKey(deviceId)) {
          setState(() {
            devicesMap[deviceId] = result;
          });
          print("Device added: ${result.device.name}, ID: $deviceId");
        } else {
          print("Duplicate device ignored: ${result.device.name}, ID: $deviceId");
        }
      }
    });
  }

  void stopScanning() {
    if (!isScanning) return;

    setState(() {
      isScanning = false;
    });

    print("Stopping Bluetooth scan...");
    FlutterBluePlus.stopScan();
    scanSubscription?.cancel();
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
                ? Icon(Icons.stop, color: Colors.red) // 스캔 중단 버튼
                : Icon(Icons.search),               // 스캔 시작 버튼
            onPressed: isScanning ? stopScanning : scanForDevices,
          ),
        ],
      ),
      body: connectedDevice == null
          ?ListView.builder(
        itemCount: devicesMap.values.where((result) => result.device.name.isNotEmpty).length,
        itemBuilder: (context, index) {
          // 이름이 있는 장치만 필터링
          final result = devicesMap.values
              .where((result) => result.device.name.isNotEmpty)
              .toList()[index];
          return ListTile(
            title: Text(result.device.name),
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
