import 'dart:async';

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
  bool isDiscovering = false;

  void startDiscovery() {
    setState(() {
      isDiscovering = true;
      devices.clear(); // 이전 검색 결과 초기화
    });

    discoveryStream = FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
      // 이름이 있는 장치만 추가
      if (result.device.name != null && result.device.name!.isNotEmpty) {
        setState(() {
          // 중복된 장치 추가 방지
          if (!devices.any((existingDevice) =>
          existingDevice.device.address == result.device.address)) {
            devices.add(result);
          }
        });
      }
    }, onDone: () {
      // 검색 완료 시, 재시작하도록 처리
      if (isDiscovering) {
        startDiscovery(); // 검색을 계속 반복
      }
    });
  }

  void stopDiscovery() {
    discoveryStream?.cancel();
    setState(() {
      isDiscovering = false;
    });
  }

  @override
  void dispose() {
    discoveryStream?.cancel();
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
                final connection =
                await FlutterBluetoothSerial.instance.connect(device);
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
