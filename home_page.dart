import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../global/global_var.dart';
import '../methods/map_theme_methods.dart';
import '../pushNotification/push_notification_system.dart';
import '../widgets/popUpwidget.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> googleMapCompleterController =
  Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  Position? currentPositionOfDriver;
  Color colorToShow = Colors.green;
  String titleToShow = "CONECTARSE AHORA";
  bool isDriverAvailable = false;
  DatabaseReference? newTripRequestReference;
  MapThemeMethods themeMethods = MapThemeMethods();

  BitmapDescriptor? customMarkerIcon;

  getCurrentLiveLocationOfDriver() async {
    Position positionOfUser = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
    currentPositionOfDriver = positionOfUser;
    driverCurrentPosition = currentPositionOfDriver;

    LatLng positionOfUserInLatLng =
    LatLng(currentPositionOfDriver!.latitude, currentPositionOfDriver!.longitude);

    CameraPosition cameraPosition =
    CameraPosition(target: positionOfUserInLatLng, zoom: 15);
    controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  Future<void> _createCustomMarker() async {
    if (customMarkerIcon == null) {
      customMarkerIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(),
        'assets/images/ubi.png',
      );
    }
  }


  goOnlineNow() {
    // Obtenemos una referencia al nodo del conductor actual
    DatabaseReference driverRef =
    FirebaseDatabase.instance.ref().child("drivers").child(FirebaseAuth.instance.currentUser!.uid);

    // Establecemos la ubicación del conductor utilizando Geofire
    Geofire.initialize("onlineDrivers");
    Geofire.setLocation(
      FirebaseAuth.instance.currentUser!.uid,
      currentPositionOfDriver!.latitude,
      currentPositionOfDriver!.longitude,
    );

    // Creamos una referencia al estado del nuevo viaje para este conductor
    newTripRequestReference = driverRef.child("newTripStatus");
    newTripRequestReference!.set("waiting");

    // Escuchamos los cambios en el estado del nuevo viaje
    newTripRequestReference!.onValue.listen((event) {});
  }

  setAndGetLocationUpdates() {
    positionStreamHomePage = Geolocator.getPositionStream().listen((Position position) {
      currentPositionOfDriver = position;

      if (isDriverAvailable == true) {
        Geofire.setLocation(
          FirebaseAuth.instance.currentUser!.uid,
          currentPositionOfDriver!.latitude,
          currentPositionOfDriver!.longitude,
        );
      }

      LatLng positionLatLng = LatLng(position.latitude, position.longitude);
      controllerGoogleMap!.animateCamera(CameraUpdate.newLatLng(positionLatLng));
    });
  }

  goOfflineNow() {
    //stop sharing driver live location updates
    Geofire.removeLocation(FirebaseAuth.instance.currentUser!.uid);

    //stop listening to the newTripStatus
    newTripRequestReference!.onDisconnect();
    newTripRequestReference!.remove();
    newTripRequestReference = null;
  }

  initializePushNotificationSystem() {
    PushNotificationSystem notificationSystem = PushNotificationSystem();
    notificationSystem.generateDeviceRegistrationToken();
    notificationSystem.startListeningForNewNotification(context);
  }

  retrieveCurrentDriverInfo() async {
    await FirebaseDatabase.instance
        .ref()
        .child("drivers")
        .child(FirebaseAuth.instance.currentUser!.uid)
        .once()
        .then((snap) {
      driverName = (snap.snapshot.value as Map)["name"];
      driverPhone = (snap.snapshot.value as Map)["phone"];
      driverPhoto = (snap.snapshot.value as Map)["photo"];
      carColor = (snap.snapshot.value as Map)["car_details"]["carColor"];
      carModel = (snap.snapshot.value as Map)["car_details"]["carModel"];
      carNumber = (snap.snapshot.value as Map)["car_details"]["carNumber"];
    });

    initializePushNotificationSystem();
  }

  @override
  void initState() {
    super.initState();
    _createCustomMarker(); // Create custom marker icon
    retrieveCurrentDriverInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ///google map
          GoogleMap(
            padding: const EdgeInsets.only(top: 136),
            mapType: MapType.hybrid,
            myLocationEnabled: false,
            initialCameraPosition: googlePlexInitialPosition,
            onMapCreated: (GoogleMapController mapController) {
              controllerGoogleMap = mapController;
              themeMethods.updateMapTheme(controllerGoogleMap!);

              googleMapCompleterController.complete(controllerGoogleMap);

              getCurrentLiveLocationOfDriver();
            },
            markers: {
              Marker(
                markerId: MarkerId('driver_location'),
                position: LatLng(currentPositionOfDriver?.latitude ?? 0.0, currentPositionOfDriver?.longitude ?? 0.0),
                icon: customMarkerIcon ?? BitmapDescriptor.defaultMarker,
              ),
            },


          ),

          Container(
            height: 136,
            width: double.infinity,
            color: Colors.black54,
          ),

          ///go online offline button
          Positioned(
            top: 61,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isDismissible: false,
                      builder: (BuildContext context) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey,
                                blurRadius: 5.0,
                                spreadRadius: 0.5,
                                offset: Offset(
                                  0.7,
                                  0.7,
                                ),
                              ),
                            ],
                          ),
                          height: 221,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            child: Column(
                              children: [
                                const SizedBox(
                                  height: 11,
                                ),
                                Text(
                                  (!isDriverAvailable) ? "CONECTARSE AHORA" : "DESCONECTARSE AHORA",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 21,
                                ),
                                Text(
                                  (!isDriverAvailable)
                                      ? "Está a punto de conectarse, estará disponible para recibir solicitudes de viaje de los usuarios."
                                      : "Estás a punto de desconectarte, dejarás de recibir nuevas solicitudes de viaje de los usuarios.",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white30,
                                  ),
                                ),
                                const SizedBox(
                                  height: 25,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text("ATRÁS"),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (!isDriverAvailable) {
                                            //go online
                                            goOnlineNow();

                                            //get driver location updates
                                            setAndGetLocationUpdates();

                                            Navigator.pop(context);

                                            setState(() {
                                              colorToShow = Colors.pink;
                                              titleToShow = "DESCONECTARSE AHORA";
                                              isDriverAvailable = true;
                                            });
                                          } else {
                                            //go offline
                                            goOfflineNow();

                                            Navigator.pop(context);

                                            setState(() {
                                              colorToShow = Colors.green;
                                              titleToShow = "CONECTARSE AHORA";
                                              isDriverAvailable = false;
                                            });
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: (titleToShow == "CONECTARSE AHORA")
                                              ? Colors.green
                                              : Colors.pink,
                                        ),
                                        child: const Text("CONFIRMAR"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorToShow,
                  ),
                  child: Text(
                    titleToShow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
