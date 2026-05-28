import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_event.dart';
import 'package:inmobiliariaapp/bloc/propertyBloc/property_state.dart';
import 'package:inmobiliariaapp/cache/property_cache_service.dart';
import 'package:inmobiliariaapp/enum/payment_status.dart';
import 'package:inmobiliariaapp/enum/property_status.dart';
import 'package:inmobiliariaapp/models/property_model.dart';
import 'package:inmobiliariaapp/services/property_repository.dart';

class PropertyBloc extends Bloc<PropertyEvent, PropertyState> {
  final PropertyRepository _repository;

  PropertyBloc(this._repository)
    : super(
        PropertyState(
          isEditing: false,
          formData: {
            'id': null,
            'address': '',
            'description': '',
            'canon': 0.0,
            'area': '',
            'hasAdmin': false,
            'adminPrice': 0.0,
            'amenities': <String>[],
            'images': <String>[],
            'docs': <String>[],
            'video': null,
            'videoUrl': null,
            'city': 'Bucaramanga',
            'acceptTerms': false,
            'createdAt': null,
            // --- NUEVOS CAMPOS INICIALIZADOS ---
            'durationValue': '1',
            'durationUnit': 'Año',
          },
        ),
      ) {
    // --- 1. CARGAR CACHÉ ---
    on<LoadPropertyCacheRequested>((event, emit) async {
      if (state.isEditing) return;

      final cache = await PropertyCacheService.getProgress();
      if (cache != null) {
        final Map<String, dynamic> fixedData = Map<String, dynamic>.from(cache);
        fixedData['images'] = List<String>.from(cache['images'] ?? []);
        fixedData['docs'] = List<String>.from(cache['docs'] ?? []);
        fixedData['amenities'] = List<String>.from(cache['amenities'] ?? []);

        // Aseguramos que la duración persista en caché
        fixedData['durationValue'] = cache['durationValue'] ?? '1';
        fixedData['durationUnit'] = cache['durationUnit'] ?? 'Año';

        emit(state.copyWith(formData: fixedData));
      }
    });

    // --- 2. INICIAR EDICIÓN ---
    on<EditPropertyStarted>((event, emit) {
      final p = event.property;
      final Map<String, dynamic> editingData = {
        'id': p.id,
        'address': p.address,
        'description': p.description,
        'canon': p.canon,
        'area': p.area,
        'hasAdmin': p.hasAdmin,
        'adminPrice': p.adminPrice,
        'amenities': List<String>.from(p.amenities),
        'images': List<String>.from(p.imageUrls),
        'docs': List<String>.from(p.docUrls),
        'video': null,
        'videoUrl': p.videoUrl,
        'city': 'Bucaramanga',
        'acceptTerms': true,
        'createdAt': p.createdAt,
        // --- INYECTAR DURACIÓN DESDE EL MODELO ---
        'durationValue': p.durationValue,
        'durationUnit': p.durationUnit,
      };

      emit(
        state.copyWith(
          formData: editingData,
          isEditing: true,
          status: PropertyStatus.initial,
        ),
      );
    });

    // --- 3. ACTUALIZAR DATOS EN TIEMPO REAL ---
    on<UpdatePropertyData>((event, emit) {
      final newData = Map<String, dynamic>.from(state.formData);

      if (event.value is List) {
        newData[event.key] = List<String>.from(event.value);
      } else {
        newData[event.key] = event.value;
      }

      if (!state.isEditing) {
        PropertyCacheService.saveProgress(newData);
      }

      emit(state.copyWith(formData: newData));
    });

    // --- 4. LIMPIAR PROGRESO / RESET ---
    on<ClearPropertyCacheRequested>((event, emit) async {
      await PropertyCacheService.clearCache();
      emit(
        PropertyState(
          isEditing: false,
          formData: {
            'id': null,
            'address': '',
            'description': '',
            'canon': 0.0,
            'area': '',
            'hasAdmin': false,
            'adminPrice': 0.0,
            'amenities': <String>[],
            'images': <String>[],
            'docs': <String>[],
            'video': null,
            'videoUrl': null,
            'city': 'Bucaramanga',
            'acceptTerms': false,
            'createdAt': null,
            'durationValue': '1',
            'durationUnit': 'Año',
          },
          status: PropertyStatus.initial,
        ),
      );
    });

    // --- 5. ENVIAR A FIREBASE ---
    on<SubmitPropertyRequested>((event, emit) async {
      emit(state.copyWith(status: PropertyStatus.loading));
      try {
        final String? propertyId = state.formData['id'];
        String? localVideoPath = state.formData['video'];
        String? currentVideoUrl = state.formData['videoUrl'];
        String? finalVideoUrl = currentVideoUrl;

        final allImages = List<String>.from(state.formData['images'] ?? []);
        final localImages = allImages
            .where((path) => !path.startsWith('http'))
            .toList();
        final networkImages = allImages
            .where((path) => path.startsWith('http'))
            .toList();

        final allDocs = List<String>.from(state.formData['docs'] ?? []);
        final localDocs = allDocs
            .where((path) => !path.startsWith('http'))
            .toList();
        final networkDocs = allDocs
            .where((path) => path.startsWith('http'))
            .toList();

        final List<Future<dynamic>> uploadTasks = [];

        uploadTasks.add(
          _repository.uploadFiles(
            localImages,
            'properties/${event.userId}/images',
          ),
        );
        uploadTasks.add(
          _repository.uploadFiles(localDocs, 'properties/${event.userId}/docs'),
        );

        bool videoIsLocal =
            localVideoPath != null && !localVideoPath.startsWith('http');
        if (videoIsLocal) {
          uploadTasks.add(
            _repository.uploadFiles([
              localVideoPath,
            ], 'properties/${event.userId}/videos'),
          );
        }

        final results = await Future.wait(uploadTasks);

        final List<String> uploadedImages = List<String>.from(results[0]);
        final List<String> finalImageUrls = [
          ...networkImages,
          ...uploadedImages,
        ];

        final List<String> uploadedDocs = List<String>.from(results[1]);
        final List<String> finalDocUrls = [...networkDocs, ...uploadedDocs];

        if (videoIsLocal) {
          final List<String> videoResult = List<String>.from(results[2]);
          finalVideoUrl = videoResult.isNotEmpty
              ? videoResult.first
              : currentVideoUrl;
        }

        // --- CONSTRUCCIÓN DEL MODELO CON DURACIÓN ---
        final property = PropertyModel(
          id: propertyId,
          ownerId: event.userId,
          address: state.formData['address'],

          // --- NUEVOS CAMPOS GEOGRÁFICOS EXTRACTOS DEL FORM DATA ---
          state:
              state.formData['state'] ??
              '', // Fallback seguro por si viene nulo
          city:
              state.formData['city'] ?? '', // Fallback seguro por si viene nulo

          description: state.formData['description'],
          canon: (state.formData['canon'] as num).toDouble(),
          area: state.formData['area'],
          hasAdmin: state.formData['hasAdmin'],
          adminPrice: (state.formData['adminPrice'] as num).toDouble(),
          amenities: List<String>.from(state.formData['amenities']),
          imageUrls: finalImageUrls,
          docUrls: finalDocUrls,
          videoUrl: finalVideoUrl,
          // GUARDAMOS LA DURACIÓN SELECCIONADA EN EL STEP
          durationValue: state.formData['durationValue'] ?? '1',
          durationUnit: state.formData['durationUnit'] ?? 'Año',
          status: PropertyStatusEnum.waitingContract,
          paymentStatus: PaymentStatusEnum.pendingVerify,
          createdAt: state.isEditing
              ? (state.formData['createdAt'] as DateTime)
              : DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _repository.saveProperty(property);

        add(ClearPropertyCacheRequested());
        emit(state.copyWith(status: PropertyStatus.success));
      } catch (e) {
        emit(
          state.copyWith(
            status: PropertyStatus.failure,
            errorMessage: "Error en el proceso: ${e.toString()}",
          ),
        );
      }
    });

    add(LoadPropertyCacheRequested());
  }
}
