import 'package:inmobiliariaapp/models/property_model.dart';

abstract class FavoritesState {}

class FavoritesInitial extends FavoritesState {}
class FavoritesLoading extends FavoritesState {}
class FavoritesLoaded extends FavoritesState {
  final List<PropertyModel> favoriteProperties;
  final Set<String> favoriteIds; // Para búsqueda rápida (O(1)) en los botones
  FavoritesLoaded(this.favoriteProperties, this.favoriteIds);
}
class FavoritesError extends FavoritesState {
  final String message;
  FavoritesError(this.message);
}