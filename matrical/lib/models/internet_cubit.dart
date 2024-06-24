import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:equatable/equatable.dart';
import 'package:matrical/services/connection_service.dart';

class InternetState extends Equatable {
  final bool? connected;

  const InternetState({required this.connected});

  InternetState copyWith({bool? connected}) {
    return InternetState(connected: connected ?? connected);
  }

  @override
  List<Object?> get props => [connected];
}

class InternetCubit extends Cubit<InternetState> {
  final Connectivity connectivity = Connectivity();
  StreamSubscription? _streamSubscription;

  InternetCubit() : super(const InternetState(connected: false)) {
    initialState();

    Connectivity().onConnectivityChanged.listen((result) {
      if (ConnectionService.checkConnectionsForInternet(result)) {
        emitConnected();
      } else {
        emitDisconnected();
      }
    }, onError: (e) {
      emitDisconnected();
    });
  }

  void emitConnected() => emit(state.copyWith(connected: true));

  void emitDisconnected() => emit(state.copyWith(connected: false));

  void initialState() async {
    if (await ConnectionService.isConnectedToInternet()) {
      emitConnected();
    } else {
      emitDisconnected();
    }
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    return super.close();
  }
}
