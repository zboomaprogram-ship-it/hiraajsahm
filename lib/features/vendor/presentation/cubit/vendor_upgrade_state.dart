import 'package:equatable/equatable.dart';

abstract class VendorUpgradeState extends Equatable {
  const VendorUpgradeState();

  @override
  List<Object> get props => [];
}

class VendorUpgradeInitial extends VendorUpgradeState {}

class VendorUpgradeLoading extends VendorUpgradeState {}

class VendorUpgradeSuccess extends VendorUpgradeState {
  final String message;

  const VendorUpgradeSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

class VendorUpgradeFailure extends VendorUpgradeState {
  final String message;

  const VendorUpgradeFailure({required this.message});

  @override
  List<Object> get props => [message];
}
