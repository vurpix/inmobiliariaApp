// ui/components/admin/candidate_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:inmobiliariaapp/models/application_model.dart';
import 'package:inmobiliariaapp/models/candidate_model.dart';
import 'package:inmobiliariaapp/services/application_service.dart';
import 'package:inmobiliariaapp/services/contract_service.dart';
import 'package:inmobiliariaapp/ui/components/admin/candidate_profile_header.dart';
import 'package:inmobiliariaapp/ui/components/pdf/Pdf_view_screen.dart';
import 'package:inmobiliariaapp/utils/themes.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text.dart';
import 'package:inmobiliariaapp/ui/components/global/custom_text_button.dart';

class CandidateDetailScreen extends StatefulWidget {
  final CandidateModel candidate;
  final String propertyId;

  const CandidateDetailScreen({
    super.key,
    required this.candidate,
    required this.propertyId,
  });

  @override
  State<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen> {
  late String _currentStatus;
  String? _decisionNote;
  final ApplicationService _applicationService = ApplicationService();
  final ContractService _contractService = ContractService();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.candidate.status;
    _decisionNote = widget.candidate.note;
  }

  String _getDisplayStatus(String? status) {
    switch (status) {
      case 'pending_review':
        return '🔍 En Revisión';
      case 'approved':
        return '✅ Aprobado';
      case 'rejected':
        return '❌ Rechazado';
      default:
        return '❓ Desconocido';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green[700]!;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFree = widget.candidate.isFreePromotion;

    return Scaffold(
      backgroundColor: context.surfaceColor.withOpacity(0.96),
      appBar: AppBar(
        title: CustomText(
          "Expediente del Candidato",
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        backgroundColor: context.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation:
            0, // Evita alteraciones de color en la barra superior
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            CandidateProfileHeader(
              candidate: widget.candidate,
              currentStatus: _currentStatus,
              getDisplayStatus: _getDisplayStatus,
              getStatusColor: _getStatusColor,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStatus != 'pending_review') _buildNoteBanner(),

                  _buildSectionTitle("📑 Documentación de Soporte"),
                  _buildDocumentCard(
                    context: context,
                    title: "Extractos Bancarios",
                    subtitle: "Documento de solvencia económica",
                    url: widget.candidate.extractPdfUrl,
                    icon: Icons.picture_as_pdf_rounded,
                    color: Colors.redAccent,
                    isPdf: true,
                  ),
                  const SizedBox(height: 14),
                  _buildDocumentCard(
                    context: context,
                    title: "Comprobante de Pago",
                    subtitle: isFree
                        ? "Membresía Gratis (Promoción 90 días)"
                        : "Soporte del estudio de seguridad",
                    url: widget.candidate.paymentImgUrl,
                    icon: isFree
                        ? Icons.card_membership_rounded
                        : Icons.receipt_long_rounded,
                    color: isFree ? Colors.purple : Colors.blueAccent,
                    isPdf: false,
                    isFree: isFree,
                  ),
                  const SizedBox(height: 30),

                  _buildSectionTitle("⚙️ Gestión de Postulación"),
                  _currentStatus == 'pending_review'
                      ? _buildActionButtons(context)
                      : _buildFinalStatusIndicator(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteBanner() {
    final Color statusColor = _getStatusColor(_currentStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.18), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            _currentStatus == 'approved'
                ? "MOTIVO DE SELECCIÓN"
                : "MOTIVO DE RECHAZO",
            baseFontSize: 11,
            fontWeight: FontWeight.w900,
            color: statusColor,
          ),
          const SizedBox(height: 6),
          CustomText(
            _decisionNote ?? "Sin nota adjunta.",
            baseFontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textColor.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalStatusIndicator() {
    final Color statusColor = _getStatusColor(_currentStatus);
    final bool isApproved = _currentStatus == 'approved';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: statusColor.withOpacity(0.08),
            child: Icon(
              isApproved ? Icons.verified_rounded : Icons.block_rounded,
              color: statusColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          CustomText.title(
            "GESTIÓN FINALIZADA",
            baseFontSize: 14,
            fontWeight: FontWeight.w900,
            color: context.textSecondaryColor.withOpacity(0.4),
          ),
          const SizedBox(height: 4),
          CustomText(
            "Este candidato ha sido ${isApproved ? 'seleccionado' : 'descartado'}.",
            baseFontSize: 13,
            color: context.textSecondaryColor.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text("RECHAZAR"),
            onPressed: () => _showDecisionDialog(context, 'rejected'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text("APROBAR"),
            onPressed: () => _showDecisionDialog(context, 'approved'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              elevation: 0,
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDecisionDialog(BuildContext context, String status) {
    final TextEditingController noteController = TextEditingController();
    String selectedQuickNote = "";

    final List<String> quickNotes = status == 'approved'
        ? [
            "Excelente perfil financiero",
            "Documentación completa",
            "Garantías sólidas",
            "Cumple todos los requisitos",
          ]
        : [
            "Ingresos insuficientes",
            "Documentación inconsistente",
            "Reportes negativos",
            "Perfil no apto para el riesgo",
          ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isApproval = status == 'approved';

          return AlertDialog(
            backgroundColor: context.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Icon(
                  isApproval
                      ? Icons.check_circle_rounded
                      : Icons.highlight_off_rounded,
                  color: _getStatusColor(status),
                  size: 24,
                ),
                const SizedBox(width: 10),
                CustomText.title(
                  isApproval ? "Aprobar Inquilino" : "Rechazar Candidato",
                  baseFontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isApproval)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber[900],
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomText(
                              "Al aprobar este candidato, los demás postulantes serán rechazados automáticamente.",
                              baseFontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  CustomText(
                    "Etiquetas de respuesta rápida:",
                    baseFontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.textSecondaryColor.withOpacity(0.7),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickNotes.map((note) {
                      bool isSelected = selectedQuickNote == note;
                      return ChoiceChip(
                        label: Text(note),
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : context.textColor,
                        ),
                        selected: isSelected,
                        selectedColor: _getStatusColor(status),
                        backgroundColor: context.textColor.withOpacity(0.03),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : context.textColor.withOpacity(0.05),
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (val) {
                          setDialogState(() {
                            selectedQuickNote = val ? note : "";
                            noteController.text = selectedQuickNote;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje personalizado...",
                      hintStyle: TextStyle(
                        color: context.textSecondaryColor.withOpacity(0.35),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: context.textColor.withOpacity(0.01),
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: context.textColor.withOpacity(0.06),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: _getStatusColor(status),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            actions: [
              CustomTextButton.muted(
                "CANCELAR",
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateStatus(status, noteController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getStatusColor(status),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("CONFIRMAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(String newStatus, String note) async {
    try {
      final ApplicationModel? application = await _applicationService
          .watchApplicationByProperty(widget.propertyId)
          .first;
      if (application == null) return;

      final List<CandidateModel> updatedCandidates = application.candidates.map(
        (c) {
          if (c.uid == widget.candidate.uid) {
            return c.copyWith(status: newStatus, note: note);
          }
          return c;
        },
      ).toList();

      await _contractService.approveCandidateProcess(
        propertyId: widget.propertyId,
        candidateUid: widget.candidate.uid,
        candidateName: widget.candidate.nombre,
        applicationDocId: widget.propertyId,
        updatedCandidates: updatedCandidates,
      );

      if (mounted) {
        setState(() {
          _currentStatus = newStatus;
          _decisionNote = note;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText(
              newStatus == 'approved'
                  ? "Candidato aprobado e hilo contractual creado"
                  : "Candidato descartado",
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: _getStatusColor(newStatus),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: CustomText("Error: $e", color: Colors.white),
            backgroundColor: context.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 2),
      child: CustomText.title(
        title,
        baseFontSize: 15,
        fontWeight: FontWeight.w900,
        color: context.primaryColor,
      ),
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String? url,
    required IconData icon,
    required Color color,
    required bool isPdf,
    bool isFree = false,
  }) {
    bool hasFile = url != null && url.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.textColor.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A365D).withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: CustomText(title, baseFontSize: 14, fontWeight: FontWeight.bold),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CustomText(
            subtitle,
            baseFontSize: 12,
            color: isFree
                ? Colors.purple[700]
                : context.textSecondaryColor.withOpacity(0.6),
          ),
        ),
        trailing: isFree
            ? const Icon(Icons.star_rounded, color: Colors.purple, size: 22)
            : hasFile
            ? Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.textSecondaryColor.withOpacity(0.4),
              )
            : const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 20,
              ),
        onTap: () {
          if (isFree || !hasFile) return;
          if (isPdf) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PdfViewScreen(path: url)),
            );
          } else {
            _showImagePreview(context, url);
          }
        },
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
