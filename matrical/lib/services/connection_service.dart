import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  static bool checkConnectionsForInternet(
      List<ConnectivityResult> connections) {
    return connections.any((connectionType) =>
        connectionType == ConnectivityResult.wifi ||
        connectionType == ConnectivityResult.mobile ||
        connectionType == ConnectivityResult.ethernet ||
        connectionType == ConnectivityResult.vpn);
  }

  static Future<bool> isConnectedToInternet() async {
    final connections = await (Connectivity().checkConnectivity());
    return checkConnectionsForInternet(connections);
  }
}
