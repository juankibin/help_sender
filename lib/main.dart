import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LocationApp(title: 'Flutter Demo Home Page'),
    );
  }
}

class LocationApp extends StatefulWidget {
  const LocationApp({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<LocationApp> createState() => _LocationAppState();
}

// ignore: unused_element
class _LocationAppState extends State<LocationApp> {
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  var locationMessage = "";
  var address = "";
  var message = "", link = "";
  late Position position2;
  var lati = "";
  var long = "";
  void getCurrentLocation() async {
    var position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    var lastPosition = await Geolocator.getLastKnownPosition();

    setState(() {
      lati = position.latitude.toString();
      long = position.longitude.toString();
      link = "https://www.google.com/maps/@$lati,$long,15z?hl=en";
    });
  }

  Future<void> GetAddressFromLatLong(Position position) async {
    List<Placemark> placemark =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    print(placemark);
    Placemark place = placemark[0];
    address =
        "${place.street},${place.locality}, ${place.subAdministrativeArea}";
    message = "$address.\n$link";
  }

  Future<void> _showMyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    // List<String> contacts = prefs.getStringList('contactNums') ?? [];
    _phoneController.text = prefs.getString('contactNum') ?? "-";
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Emergency Number'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter number to send';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Phone number',
                      labelText: 'Number'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Set'),
              onPressed: () {
                // //Adding Item
                // contacts.add("value");

                // //Removing Item
                // var index = contacts.indexWhere((x) => x == "value");
                // contacts.removeAt(index);

                // prefs.setStringList("contactNums", contacts); //Saving

                prefs.setString('contactNum', _phoneController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

//sms sender
  final Telephony telephony = Telephony.instance;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _valueSms = TextEditingController();

  @override
  void initState() {
    super.initState();
    _valueSms.text = '1';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Location Services"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 46, color: Colors.blue),
              SizedBox(
                height: 10.0,
              ),
              Text("Get user Location",
                  style:
                      TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold)),
              SizedBox(height: 20.0),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ElevatedButton(
                            onPressed: () async {
                              _showMyDialog();
                            },
                            child: const Text('Show Dialog')),
                        ElevatedButton(
                            onPressed: () async {
                              Position position = await _determinePosition();
                              getCurrentLocation();
                              await GetAddressFromLatLong(position);
                              await _sendSMS();
                              print("here");
                            },
                            child: const Text('Send')),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _sendSMS() async {
    try {
      await telephony.sendSms(
          to: _phoneController.text, message: "Please Help Me!!! $message");
    } catch (e) {
      print(e);
    }
  }

  _getSMS() async {
    List<SmsMessage> _messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY],
        filter:
            SmsFilter.where(SmsColumn.ADDRESS).equals(_phoneController.text));

    for (var msg in _messages) {
      print(msg.body);
    }
  }
}
