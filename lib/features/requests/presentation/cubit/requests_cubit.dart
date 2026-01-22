import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/request_model.dart';
import '../../data/services/requests_service.dart';

abstract class RequestsState extends Equatable {
  const RequestsState();

  @override
  List<Object> get props => [];
}

class RequestsInitial extends RequestsState {
  const RequestsInitial();
}

class RequestsLoading extends RequestsState {
  const RequestsLoading();
}

class RequestsSuccess extends RequestsState {
  const RequestsSuccess();
}

class RequestsError extends RequestsState {
  final String message;

  const RequestsError(this.message);

  @override
  List<Object> get props => [message];
}

class RequestsCubit extends Cubit<RequestsState> {
  final RequestsService _requestsService;

  RequestsCubit({required RequestsService requestsService})
    : _requestsService = requestsService,
      super(const RequestsInitial());

  Future<void> submitRequest(RequestModel request) async {
    emit(RequestsLoading());
    try {
      await _requestsService.submitRequest(request);
      emit(RequestsSuccess());
    } catch (e) {
      emit(RequestsError(e.toString()));
    }
  }
}
