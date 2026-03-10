part of 'addresses_cubit.dart';

abstract class AddressesState extends Equatable {
  const AddressesState();

  @override
  List<Object?> get props => [];
}

class AddressesInitial extends AddressesState {
  const AddressesInitial();
}

class AddressesLoading extends AddressesState {
  const AddressesLoading();
}

class AddressesLoaded extends AddressesState {
  final List<AddressModel> addresses;

  const AddressesLoaded({required this.addresses});

  AddressModel? get defaultAddress {
    try {
      return addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return addresses.isNotEmpty ? addresses.first : null;
    }
  }

  @override
  List<Object?> get props => [addresses];
}

class AddressesError extends AddressesState {
  final String message;

  const AddressesError({required this.message});

  @override
  List<Object?> get props => [message];
}
