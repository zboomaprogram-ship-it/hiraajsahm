import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/di/injection_container.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileImageUpdated extends ProfileState {
  final String imageUrl;

  const ProfileImageUpdated(this.imageUrl);

  @override
  List<Object> get props => [imageUrl];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object> get props => [message];
}

class ProfileUpdating extends ProfileState {}

class ProfileUpdateSuccess extends ProfileState {
  final String message;
  const ProfileUpdateSuccess(this.message);
  @override
  List<Object> get props => [message];
}

class ProfileCubit extends Cubit<ProfileState> {
  final Dio _dio;

  ProfileCubit({Dio? dio}) : _dio = dio ?? sl<Dio>(), super(ProfileInitial());

  Future<void> uploadProfileImage(File imageFile) async {
    emit(ProfileLoading());
    try {
      // 1. Upload Media
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final mediaResponse = await _dio.post('/wp/v2/media', data: formData);
      // 2. Update user metadata with the image ID if needed
      // (This part depends on backend API, skipping for now if not used)
      String imageUrl = mediaResponse.data['source_url'];

      // 2. Update User Avatar
      // We will assume we save the URL in a meta field 'custom_avatar'.
      // If using WP User Avatar or similar, the field might differ.
      await _dio.post(
        '/wp/v2/users/me',
        data: {
          'meta_data': [
            {'key': 'custom_avatar', 'value': imageUrl},
          ],
        },
      );

      emit(ProfileImageUpdated(imageUrl));
    } catch (e) {
      // If 403, might need auth token which is handled by interceptor
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    emit(ProfileUpdating());
    try {
      final response = await _dio.post(
        '/wp/v2/users/me',
        data: {'first_name': firstName, 'last_name': lastName, 'email': email},
      );

      if (response.statusCode == 200) {
        emit(const ProfileUpdateSuccess('تم تحديث البيانات بنجاح'));
      } else {
        emit(
          ProfileError(
            'فشل التحديث: ${response.data['message'] ?? 'خطأ غير معروف'}',
          ),
        );
      }
    } catch (e) {
      String msg = e.toString();
      if (e is DioException &&
          e.response?.data != null &&
          e.response!.data is Map) {
        msg = e.response!.data['message'] ?? msg;
      }
      emit(ProfileError(msg));
    }
  }
}
