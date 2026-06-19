// ui/screens/tenant_flow/tenant_contract_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_bloc.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_event.dart';
import 'package:inmobiliariaapp/bloc/signatureBloc/signature_bloc_state.dart';

import 'package:inmobiliariaapp/ui/components/info_box_widget.dart';
import 'package:inmobiliariaapp/models/contract_model.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';

class TenantContractDetailsScreen extends StatefulWidget {
  final ContractModel contract;

  const TenantContractDetailsScreen({
    super.key,
    required this.contract,
  });

  @override
  State<TenantContractDetailsScreen> createState() =>
      _TenantContractDetailsScreenState();
}

class _TenantContractDetailsScreenState
    extends State<TenantContractDetailsScreen> {
  final ContractService _contractService = ContractService();

  // Se conserva por compatibilidad con tu estructura anterior.
  // La escucha principal ahora se hace con SignatureBloc.
  late final Stream<ContractModel?> _contractStream;

  late final String _contractId;

  @override
  void initState() {
    super.initState();

    _contractStream = _contractService.watchContractByProperty(
      widget.contract.propertyId,
    );

    _contractId = _resolveContractId();
  }

  /// Intenta tomar el ID real del contrato.
  /// Lo ideal es que ContractModel tenga un campo id o contractId.
  /// Si tu modelo usa otro nombre, ajusta aquí.
  String _resolveContractId() {
    try {
      final dynamic contractDynamic = widget.contract;

      final dynamic idValue =
          contractDynamic.id ?? contractDynamic.contractId ?? contractDynamic.uid;

      if (idValue != null && idValue.toString().trim().isNotEmpty) {
        return idValue.toString();
      }
    } catch (_) {
      // Si el modelo no tiene id, contractId o uid, cae al fallback.
    }

    // Fallback.
    // OJO: esto solo sirve si el documentId del contrato es igual al propertyId.
    return widget.contract.propertyId;
  }

  /// Abre la pasarela de Viafirma pasando el link correcto a la pantalla espejo.
  /// Al cerrarse el WebView, la pantalla puede refrescar el estado contra el backend.
  Future<void> _openInAppWebView(String directUrl) async {
    debugPrint("🛰️ [VIAFIRMA UI] Abriendo pasarela integrada: $directUrl");

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignatureWebViewScreen(initialUrl: directUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SignatureBloc()
        ..add(
          WatchContractSignatureRequested(_contractId),
        ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Finalizar Contrato"),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: BlocBuilder<SignatureBloc, SignatureState>(
          builder: (context, signatureState) {
            final currentContract = widget.contract;
            final String tenantUid = currentContract.tenant?.uid ?? '';

            String? mySignLink;
            String mySignatureStatus = 'PENDING';
            String tenantSignatureStatus = 'PENDING';
            String ownerSignatureStatus = 'WAITING';

            if (signatureState.signature != null && tenantUid.isNotEmpty) {
              final signature = signatureState.signature!;

              mySignatureStatus = signature.statusForUser(tenantUid);
              mySignLink = signature.signLinkForUser(tenantUid);

              tenantSignatureStatus = signature.tenantSignatureStatus;
              ownerSignatureStatus = signature.ownerSignatureStatus;
            } else {
              // Fallback por si todavía no llega el Bloc pero el contrato ya trae tracking.
              if (currentContract.signaturesTracking != null &&
                  tenantUid.isNotEmpty) {
                final tracking = currentContract.signaturesTracking!;

                if (tracking.containsKey(tenantUid)) {
                  final tenantData = tracking[tenantUid]!;
                  mySignatureStatus = tenantData.status;

                  try {
                    final rawTrackingMap = (currentContract as dynamic)
                        .toMap()['signaturesTracking']?[tenantUid] as Map?;

                    if (rawTrackingMap != null &&
                        rawTrackingMap.containsKey('signLink')) {
                      mySignLink = rawTrackingMap['signLink']?.toString();
                    }
                  } catch (_) {
                    // Si el modelo no tiene toMap o el mapa no existe, no rompe la pantalla.
                  }
                }
              }
            }

            final bool alreadySigned = mySignatureStatus == 'SIGNED' ||
                mySignatureStatus == 'COMPLETED';

            final bool isRejected = mySignatureStatus == 'REJECTED';

            final bool isLoadingSignature =
                signatureState.status == SignatureStatus.initial ||
                    signatureState.status == SignatureStatus.loading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Revisión y Firma Digital",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    alreadySigned
                        ? "¡Excelente! Has completado tu firma digital de manera exitosa. El documento está en validación por el propietario y administración."
                        : "A continuación, podrás previsualizar el borrador de tu contrato de arrendamiento legal y proceder a estampar tu firma digital autorizada mediante Viafirma.",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 30),

                  _sectionTitle("1. Previsualizar borrador de contrato"),

                  if (currentContract.baseContractPdfUrl != null)
                    _buildBorradorCard(currentContract.baseContractPdfUrl!)
                  else
                    buildInfoBox(
                      "⏳ Generando archivo borrador legal... Por favor espera un momento.",
                      Colors.orange[800]!,
                    ),

                  const SizedBox(height: 35),

                  _sectionTitle("2. Pasarela de Firma Autorizada"),

                  if (isLoadingSignature)
                    buildInfoBox(
                      "⏳ Consultando estado de firma digital...",
                      Colors.blueGrey,
                    ),

                  if (signatureState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: buildInfoBox(
                        "⚠️ ${signatureState.errorMessage}",
                        Colors.redAccent,
                      ),
                    ),

                  if (isRejected) _buildRejectAlert(),

                  const SizedBox(height: 10),

                  _buildSignatureStatusBox(
                    mySignatureStatus: mySignatureStatus,
                    tenantStatus: tenantSignatureStatus,
                    ownerStatus: ownerSignatureStatus,
                  ),

                  const SizedBox(height: 16),

                  if (alreadySigned)
                    _buildStatusInfoBox(
                      "✅ YA FIRMASTE ESTE CONTRATO",
                      "Tu firma digital ha sido registrada en los servidores de la inmobiliaria. Te notificaremos cuando el inmueble se active.",
                      Colors.green,
                      Icons.verified_user_rounded,
                    )
                  else if (mySignLink != null && mySignLink.isNotEmpty)
                    _buildActionButton(
                      label: isRejected
                          ? "REINTENTAR FIRMA DIGITAL"
                          : "IR A FIRMAR CONTRATO",
                      color: isRejected
                          ? Colors.redAccent
                          : const Color(0xFF2E7D32),
                      icon: Icons.assignment_turned_in_rounded,
                      onTap: () async {
                        await _openInAppWebView(mySignLink!);

                        if (!context.mounted) return;

                        context.read<SignatureBloc>().add(
                              RefreshSignatureStatusRequested(_contractId),
                            );
                      },
                    )
                  else
                    buildInfoBox(
                      "⏳ Esperando que el servidor genere el enlace seguro con Viafirma...",
                      Colors.blueGrey,
                    ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: signatureState.isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text("Actualizar estado de firma"),
                      onPressed: signatureState.isRefreshing
                          ? null
                          : () {
                              context.read<SignatureBloc>().add(
                                    RefreshSignatureStatusRequested(
                                      _contractId,
                                    ),
                                  );
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildBorradorCard(String pdfUrl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1A237E).withOpacity(0.15),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: const Icon(
          Icons.picture_as_pdf_rounded,
          color: Color(0xFF1A237E),
          size: 28,
        ),
        title: const Text(
          "Borrador de Contrato Oficial",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          "Documento listo para lectura",
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewScreen(
                path: pdfUrl,
                title: "Borrador de Contrato",
              ),
            ),
          ),
          child: const Text(
            "LEER",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamily: 'Inter',
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusInfoBox(
    String title,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureStatusBox({
    required String mySignatureStatus,
    required String tenantStatus,
    required String ownerStatus,
  }) {
    String label(String status) {
      switch (status) {
        case 'PENDING':
          return 'Pendiente por firmar';
        case 'WAITING':
          return 'Esperando turno';
        case 'SIGNED':
        case 'COMPLETED':
          return 'Firmado';
        case 'REJECTED':
          return 'Rechazado';
        case 'RECEIVED':
          return 'Recibido por Viafirma';
        case 'FINISHED':
          return 'Finalizado';
        case 'ERROR':
          return 'Error';
        default:
          return status;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1A237E).withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Estado del proceso",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 8),
          Text("Mi firma: ${label(mySignatureStatus)}"),
          Text("Inquilino: ${label(tenantStatus)}"),
          Text("Propietario: ${label(ownerStatus)}"),
        ],
      ),
    );
  }

  Widget _buildRejectAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: const Text(
        "❌ Tu firma anterior fue rechazada por inconsistencias o errores en el estudio de seguridad. Por favor, lee detenidamente el documento y vuelve a firmar a través del enlace.",
        style: TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

// --- SUB-PANTALLA ESPEJO (Misma estructura funcional que usas en Propietario) ---
class SignatureWebViewScreen extends StatefulWidget {
  final String initialUrl;

  const SignatureWebViewScreen({
    super.key,
    required this.initialUrl,
  });

  @override
  State<SignatureWebViewScreen> createState() => _SignatureWebViewScreenState();
}

class _SignatureWebViewScreenState extends State<SignatureWebViewScreen> {
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pasarela de Firma",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.initialUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    transparentBackground: false,
                    userAgent:
                        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36",
                  ),
                  onWebViewCreated: (controller) {},
                  onLoadStart: (controller, url) {
                    setState(() => _isLoading = true);
                  },
                  onLoadStop: (controller, url) {
                    setState(() => _isLoading = false);
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    var uri = navigationAction.request.url;

                    if (uri != null &&
                        (uri.toString().contains("success") ||
                            uri.toString().contains("complete"))) {
                      debugPrint(
                        "🎯 ¡Contrato firmado detectado en la URL!: $uri",
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "¡Proceso completado en el portal de firma!",
                          ),
                        ),
                      );

                      Navigator.pop(context);
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                ),
              ),
            ],
          ),
          if (_isLoading || _progress < 1.0)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: const Color(0xFF2E7D32),
              backgroundColor: Colors.white.withOpacity(0.5),
              minHeight: 4,
            ),
        ],
      ),
    );
  }
}