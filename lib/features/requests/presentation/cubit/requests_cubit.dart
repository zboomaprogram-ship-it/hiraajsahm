import 'dart:io';
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

  Future<void> submitRequest(RequestModel request, [File? imageFile]) async {
    emit(const RequestsLoading());
    try {
      RequestModel finalRequest = request;

      if (imageFile != null) {
        final imageUrl = await _requestsService.uploadImage(imageFile);

        // Re-create model since fields are final and no copyWith
        finalRequest = RequestModel(
          livestockType: request.livestockType,
          ownerPrice: request.ownerPrice,
          pricePerKg: request.pricePerKg,
          address: request.address,
          phone: request.phone,
          type: request.type,
          carrierName: request.carrierName,
          city: request.city,
          region: request.region,
          plateNumber: request.plateNumber,
          transferType: request.transferType,
          vehicleImage: imageUrl,
        );
      }

      await _requestsService.submitRequest(finalRequest);
      emit(const RequestsSuccess());
    } catch (e) {
      emit(RequestsError(e.toString()));
    }
  }
}
