import 'products_cubit.dart';

/// A completely separate instance of [ProductsCubit] specifically for the 
/// Zabayeh (الذبائح) section to prevent its state from leaking and colliding 
/// with the generic Shop screen state.
class ZabayehProductsCubit extends ProductsCubit {
  ZabayehProductsCubit({required super.dio});
}
