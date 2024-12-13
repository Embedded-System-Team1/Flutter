import 'package:flutter/material.dart';
import 'screens/bluetooth_serial_example.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Classic Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothClassicExample(), // 제공된 BluetoothClassicExample 위젯 사용
    );
  }
}