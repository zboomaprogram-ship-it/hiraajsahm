import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/service_provider_model.dart';
import '../../data/services/service_provider_service.dart';

// States
abstract class ServiceProvidersState extends Equatable {
  const ServiceProvidersState();
  @override
  List<Object?> get props => [];
}

class ServiceProvidersInitial extends ServiceProvidersState {}

class ServiceProvidersLoading extends ServiceProvidersState {}

class ServiceProvidersLoaded extends ServiceProvidersState {
  final List<ServiceProviderModel> allProviders;
  final List<ServiceProviderModel> filteredProviders;
  final String? userCity;

  const ServiceProvidersLoaded({
    required this.allProviders,
    required this.filteredProviders,
    this.userCity,
  });

  @override
  List<Object?> get props => [allProviders, filteredProviders, userCity];
}

class ServiceProvidersError extends ServiceProvidersState {
  final String message;
  const ServiceProvidersError(this.message);
  @override
  List<Object?> get props => [message];
}

// Cubit
class ServiceProvidersCubit extends Cubit<ServiceProvidersState> {
  final ServiceProviderService _service;

  ServiceProvidersCubit(this._service) : super(ServiceProvidersInitial());

  Future<void> fetchServiceProviders({String? userCity}) async {
    emit(ServiceProvidersLoading());
    try {
      // Use the new service method that filters by city on the server
      final providers = await _service.getServiceProviders(userCity ?? '');

      emit(
        ServiceProvidersLoaded(
          allProviders: providers,
          filteredProviders: providers,
          userCity: userCity,
        ),
      );
    } catch (e) {
      // No mock data as per user's specific request for API implementation
      emit(ServiceProvidersError(e.toString()));
    }
  }
}
