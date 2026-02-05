import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/colors.dart';
import '../widgets/custom_button.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late GoogleMapController _mapController;
  LatLng _currentPosition = const LatLng(24.7136, 46.6753); // Default: Riyadh
  bool _isLoading = true;
  String _address = 'جاري تحديد الموقع...';
  String? _city;
  String? _region;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _currentPosition = widget.initialLocation!;
      _isLoading = false;
      _getAddressFromLatLng(_currentPosition);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _address = 'خدمة الموقع غير مفعلة';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _address = 'تم رفض إذن الموقع';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoading = false;
        _address = 'إذن الموقع مرفوض بشكل دائم';
      });
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 15),
        ),
      );

      _getAddressFromLatLng(_currentPosition);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _address = 'تعذر تحديد الموقع الحالي';
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _city = place.locality ?? place.subAdministrativeArea;
          _region = place.administrativeArea;
          _address = '${place.street}, ${place.subLocality}, ${place.locality}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _address = 'تعذر تحديد العنوان';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onCameraMove: (position) {
              _currentPosition = position.target;
            },
            onCameraIdle: () {
              _getAddressFromLatLng(_currentPosition);
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _currentPosition,
              ),
            },
          ),

          // Center Marker Indicator (Fixed in center)
          const Center(
            child: Icon(Icons.location_on, size: 40, color: Colors.red),
          ),

          // Bottom Sheet for Address & Confirm
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'الموقع المحدد',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _address,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 20.h),
                  CustomButton(
                    text: 'تأكيد الموقع',
                    isLoading: _isLoading,
                    onPressed: () {
                      Navigator.pop(context, {
                        'lat': _currentPosition.latitude,
                        'lng': _currentPosition.longitude,
                        'address': _address,
                        'city': _city,
                        'region': _region,
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 50.h,
            right: 20.w,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
