import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  // Method to check if there is an active internet connection
  Future<bool> isConnected() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    switch (connectivityResult) {
      case ConnectivityResult.ethernet:
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
        return true;
      case ConnectivityResult.none:
      default:
        return false;
    }
  }
}
