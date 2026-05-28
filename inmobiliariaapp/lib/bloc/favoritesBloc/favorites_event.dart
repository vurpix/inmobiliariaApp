import 'package:inmobiliariaapp/models/property_model.dart';

abstract class FavoritesEvent {}

class LoadFavorites extends FavoritesEvent {
  final String userId;
  LoadFavorites(this.userId);
}

class ToggleFavorite extends FavoritesEvent {
  final String userId;
  final PropertyModel property;
  ToggleFavorite(this.userId, this.property);
}