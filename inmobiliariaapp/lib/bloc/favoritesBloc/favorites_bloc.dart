import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_event.dart';
import 'package:inmobiliariaapp/bloc/favoritesBloc/favorites_state.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/user_service.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final UserService _userService = UserService();
  FavoritesBloc() : super(FavoritesInitial()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<ToggleFavorite>(_onToggleFavorite);
  }

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(FavoritesLoading());
    try {
      //  Así queda tu línea reemplazada de forma limpia:
      final snapshot = await _userService.getUserFavoritesSnapshot(
        event.userId,
      );
      final favoriteProperties = snapshot.docs
          .map((doc) => PropertyModel.fromSnapshot(doc))
          .toList();

      final favoriteIds = favoriteProperties.map((p) => p.id!).toSet();

      emit(FavoritesLoaded(favoriteProperties, favoriteIds));
    } catch (e) {
      emit(FavoritesError(e.toString()));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    final currentState = state;
    if (currentState is FavoritesLoaded) {
      final userId = event.userId;
      final propertyId = event.property.id!;
      final docRef = _userService.getFavoriteDocRef(
        userId: userId,
        propertyId: propertyId,
      );
      try {
        final newIds = Set<String>.from(currentState.favoriteIds);
        final newList = List<PropertyModel>.from(
          currentState.favoriteProperties,
        );

        if (newIds.contains(propertyId)) {
          newIds.remove(propertyId);
          newList.removeWhere((p) => p.id == propertyId);
          await docRef.delete();
        } else {
          newIds.add(propertyId);
          newList.add(event.property);
          await docRef.set(
            event.property.toMap(),
          ); // Guarda el objeto completo para offline
        }
        emit(FavoritesLoaded(newList, newIds));
      } catch (e) {
        emit(FavoritesError("Error al actualizar favoritos"));
      }
    }
  }
}
