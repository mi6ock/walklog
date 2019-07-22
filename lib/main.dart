import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors/sensors.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '歩速実験室',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _loggingFlag = true;
  bool _calcelLoggingFlag = false;

  LocationData _startLocation;
  LocationData _currentLocation;

  Timer _timer;

  StreamSubscription<LocationData> _locationSubscription;

  Location _locationService = new Location();
  bool _permission = false;
  String error;

  bool currentWidget = true;

  // センサーデータ類
  List<double> _accelerometerValues;
  List<double> _userAccelerometerValues;
  List<double> _gyroscopeValues;
  List<StreamSubscription<dynamic>> _streamSubscriptions =
      <StreamSubscription<dynamic>>[];

  // 全てのデータ
  String _data = "";

  @override
  void initState() {
    // TODO: implement initState
    initPlatformState();
    initSensors();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<String> arr = _data.split(",");
    return Scaffold(
      appBar: AppBar(
        title: Text("歩速実験室"),
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height - 100,
        width: MediaQuery.of(context).size.width,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: arr.length,
                itemBuilder: (BuildContext context, int index) {
                  return Text(arr[index] + "\n");
                },
              )
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logging,
        label: _loggingFlag ? Text("ログ取得スタート") : Text("ログ取得ストップ"),
        icon: _loggingFlag ? Icon(Icons.play_arrow) : Icon(Icons.stop),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation
          .centerFloat, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _logging() async {
    bool tmpFlag;
    if (_loggingFlag) {
      _writeLog();
      tmpFlag = false;
    } else {
      tmpFlag = true;
    }

    setState(() {
      _loggingFlag = tmpFlag;
      _calcelLoggingFlag = tmpFlag ? false : true;
    });
  }

  void _writeLog() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filePath = appDocDir.path +
        "/" +
        DateTime.now().millisecondsSinceEpoch.toString() +
        "_log.csv";
    File outputFile = File(filePath);
    StringBuffer allBuffer = StringBuffer();
    String header = "time,accelerometer_x,accelerometer_y,accelerometer_z,"
        "gyroscope_x,gyroscope_y,gyroscope_z,userAccelerometer_x,"
        "userAccelerometer_y,userAccelerometer_z,latitude,longitude,"
        "accuracy,altitude,speed,speedAccuracy,heading\n";
    allBuffer.write(header);

    _timer = new Timer.periodic(
      Duration(seconds: 1),
      (Timer timer) {
        if (_calcelLoggingFlag) {
          final List<String> accelerometer = _accelerometerValues
              ?.map((double v) => v.toStringAsFixed(1))
              ?.toList();
          final List<String> gyroscope = _gyroscopeValues
              ?.map((double v) => v.toStringAsFixed(1))
              ?.toList();
          final List<String> userAccelerometer = _userAccelerometerValues
              ?.map((double v) => v.toStringAsFixed(1))
              ?.toList();
          StringBuffer buffer = StringBuffer();
          buffer.write(DateTime.now().millisecondsSinceEpoch.toString());
          buffer.write(",");
          buffer.write(accelerometer[0] +
              "," +
              accelerometer[1] +
              "," +
              accelerometer[2]);
          buffer.write(",");
          buffer.write(gyroscope[0] + "," + gyroscope[1] + "," + gyroscope[2]);
          buffer.write(",");
          buffer.write(userAccelerometer[0] +
              "," +
              userAccelerometer[1] +
              "," +
              userAccelerometer[2]);
          buffer.write(",");
          if (_currentLocation != null) {
            buffer.write(_currentLocation.latitude);
            buffer.write(",");
            buffer.write(_currentLocation.longitude);
            buffer.write(",");
            buffer.write(_currentLocation.accuracy);
            buffer.write(",");
            buffer.write(_currentLocation.altitude);
            buffer.write(",");
            buffer.write(_currentLocation.speed);
            buffer.write(",");
            buffer.write(_currentLocation.speedAccuracy);
            buffer.write(",");
            buffer.write(_currentLocation.heading);
          } else {
            buffer.write(",");
            buffer.write(",");
            buffer.write(",");
            buffer.write(",");
            buffer.write(",");
            buffer.write(",");
          }
          buffer.write("\n");
          print(buffer.toString());
          allBuffer.write(buffer.toString());
          setState(() {
            _data = buffer.toString();
          });
        } else {
          //todo close file write
          outputFile.writeAsString(allBuffer.toString());
          print("stop");
          _timer.cancel();
        }
      },
    );
  }

  initPlatformState() async {
    await _locationService.changeSettings(
        accuracy: LocationAccuracy.HIGH, interval: 1000);

    LocationData location;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      bool serviceStatus = await _locationService.serviceEnabled();
      print("Service status: $serviceStatus");
      if (serviceStatus) {
        _permission = await _locationService.requestPermission();
        print("Permission: $_permission");
        if (_permission) {
          location = await _locationService.getLocation();

          _locationSubscription = _locationService
              .onLocationChanged()
              .listen((LocationData result) async {
            if (mounted) {
              setState(() {
                _currentLocation = result;
              });
            }
          });
        }
      } else {
        bool serviceStatusResult = await _locationService.requestService();
        print("Service status activated after request: $serviceStatusResult");
        if (serviceStatusResult) {
          initPlatformState();
        }
      }
    } on PlatformException catch (e) {
      print(e);
      if (e.code == 'PERMISSION_DENIED') {
        error = e.message;
      } else if (e.code == 'SERVICE_STATUS_ERROR') {
        error = e.message;
      }
      location = null;
    }
  }

  void initSensors() {
    _streamSubscriptions
        .add(accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = <double>[event.x, event.y, event.z];
      });
    }));
    _streamSubscriptions.add(gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeValues = <double>[event.x, event.y, event.z];
      });
    }));
    _streamSubscriptions
        .add(userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      setState(() {
        _userAccelerometerValues = <double>[event.x, event.y, event.z];
      });
    }));
  }
}
