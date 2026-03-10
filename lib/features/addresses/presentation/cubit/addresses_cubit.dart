import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/address_model.dart';

part 'addresses_state.dart';

class AddressesCubit extends Cubit<AddressesState> {
  static const String _storageKey = 'saved_addresses';

  AddressesCubit() : super(const AddressesInitial());

  /// Load addresses from local storage
  Future<void> loadAddresses() async {
    emit(const AddressesLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        final addresses = jsonList
            .map((j) => AddressModel.fromJson(j))
            .toList();
        emit(AddressesLoaded(addresses: addresses));
      } else {
        emit(const AddressesLoaded(addresses: []));
      }
    } catch (e) {
      emit(AddressesError(message: 'فشل تحميل العناوين: $e'));
    }
  }

  /// Add a new address
  Future<void> addAddress(AddressModel address) async {
    try {
      final currentAddresses = _getCurrentAddresses();

      // If this is the first address or marked as default, update others
      List<AddressModel> updatedList;
      if (currentAddresses.isEmpty || address.isDefault) {
        updatedList = currentAddresses
            .map((a) => a.copyWith(isDefault: false))
            .toList();
        updatedList.add(address.copyWith(isDefault: true));
      } else {
        updatedList = [...currentAddresses, address];
      }

      await _saveAndEmit(updatedList);
    } catch (e) {
      emit(AddressesError(message: 'فشل إضافة العنوان: $e'));
    }
  }

  /// Update an existing address
  Future<void> updateAddress(AddressModel updatedAddress) async {
    try {
      var currentAddresses = _getCurrentAddresses();

      // If updated address is default, clear other defaults
      if (updatedAddress.isDefault) {
        currentAddresses = currentAddresses
            .map((a) => a.copyWith(isDefault: false))
            .toList();
      }

      final updatedList = currentAddresses.map((a) {
        if (a.id == updatedAddress.id) return updatedAddress;
        return a;
      }).toList();

      await _saveAndEmit(updatedList);
    } catch (e) {
      emit(AddressesError(message: 'فشل تحديث العنوان: $e'));
    }
  }

  /// Delete an address
  Future<void> deleteAddress(String addressId) async {
    try {
      final currentAddresses = _getCurrentAddresses();
      final updatedList = currentAddresses
          .where((a) => a.id != addressId)
          .toList();

      // If we deleted the default and there are remaining addresses, make first one default
      if (updatedList.isNotEmpty && !updatedList.any((a) => a.isDefault)) {
        updatedList[0] = updatedList[0].copyWith(isDefault: true);
      }

      await _saveAndEmit(updatedList);
    } catch (e) {
      emit(AddressesError(message: 'فشل حذف العنوان: $e'));
    }
  }

  /// Set an address as default
  Future<void> setDefault(String addressId) async {
    try {
      final currentAddresses = _getCurrentAddresses();
      final updatedList = currentAddresses.map((a) {
        return a.copyWith(isDefault: a.id == addressId);
      }).toList();

      await _saveAndEmit(updatedList);
    } catch (e) {
      emit(AddressesError(message: 'فشل تحديث العنوان الافتراضي: $e'));
    }
  }

  List<AddressModel> _getCurrentAddresses() {
    if (state is AddressesLoaded) {
      return List.from((state as AddressesLoaded).addresses);
    }
    return [];
  }

  Future<void> _saveAndEmit(List<AddressModel> addresses) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = addresses.map((a) => a.toJson()).toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
    emit(AddressesLoaded(addresses: addresses));
  }
}
