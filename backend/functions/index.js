// index.js
const {
  onDocumentUpdated,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const Mailjet = require("node-mailjet");
const axios = require("axios");
const { onRequest } = require("firebase-functions/v2/https");

// --- IMPORTACIÓN DE ENUMS GLOBALES CONGELADOS ---
const {
  PropertyStatusEnum,
  ContractStatus,
  UserRole,
  PaymentStatusEnum,
} = require("./utils/enum"); // Ajusta la ruta si moviste el archivo de constantes

const {
  createSignatureSet,
  getSetSummary,
  getSetStatus,
} = require("./viafirma");

admin.initializeApp();

const mailjet = Mailjet.apiConnect(
  "1b20fafd9a90479c4070e5062bd2c7b9",
  "0464b12dec02ccc232a3ba37ff757670",
);

// ==========================================
// --- FUNCIONES HELPERS Y UTILIDADES ---
// ==========================================

async function getAdminIds() {
  const db = getFirestore();
  const adminIds = [];

  try {
    const snapshot = await db
      .collection("users")
      .where("role", "==", UserRole.admin)
      .get();

    if (!snapshot.empty) {
      snapshot.forEach((doc) => {
        adminIds.push(doc.id);
      });
    }
  } catch (error) {
    console.error(
      "Error al consultar los administradores en la base de datos:",
      error,
    );
  }
  return adminIds;
}

async function getUserContactData(userId) {
  if (!userId) return null;
  const db = getFirestore();

  try {
    const userDoc = await db.collection("users").doc(userId).get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      return {
        email: userData.email || "",
        name: userData.name || userData.nombre || "Usuario",
      };
    }
    console.log(
      `El usuario con ID ${userId} no existe en la colección 'users'.`,
    );
  } catch (error) {
    console.error(`Error al consultar los datos del usuario ${userId}:`, error);
  }
  return null;
}

async function sendEmail(
  userEmail,
  userName,
  subject,
  content,
  templateId = 8020915,
) {
  try {
    await mailjet.post("send", { version: "v3.1" }).request({
      Messages: [
        {
          From: {
            Email: "davidbarrera@humanbionics.com.co",
            Name: "Inmobiliaria Armando Marin",
          },
          To: [
            {
              Email: userEmail,
              Name: userName,
            },
          ],
          TemplateID: templateId,
          TemplateLanguage: true,
          Subject: subject,
          Variables: {
            user_name: userName,
            message_content: content,
          },
        },
      ],
    });
    console.log("Email con Template enviado con éxito:");
  } catch (error) {
    console.error(
      "Error al enviar email con template:",
      error.statusCode,
      error.message,
    );
  }
}

async function sendEmailWithPdfAttachment(
  userEmail,
  userName,
  subject,
  content,
  pdfUrl,
  templateId = 8020915,
) {
  try {
    let attachmentsBlock = [];

    if (pdfUrl && pdfUrl.trim() !== "") {
      console.log(`Descargando PDF para adjuntar desde: ${pdfUrl}`);

      const response = await axios.get(pdfUrl, { responseType: "arraybuffer" });
      const base64Pdf = Buffer.from(response.data, "binary").toString("base64");

      attachmentsBlock = [
        {
          ContentType: "application/pdf",
          Filename: "Contrato_Arrendamiento_Firmado.pdf",
          Base64Content: base64Pdf,
        },
      ];
    }

    await mailjet.post("send", { version: "v3.1" }).request({
      Messages: [
        {
          From: {
            Email: "davidbarrera@humanbionics.com.co",
            Name: "Inmobiliaria Armando Marin",
          },
          To: [
            {
              Email: userEmail,
              Name: userName,
            },
          ],
          TemplateID: templateId,
          TemplateLanguage: true,
          Subject: subject,
          Variables: {
            user_name: userName,
            message_content: content,
          },
          Attachments: attachmentsBlock,
        },
      ],
    });

    console.log(`Email con PDF adjunto enviado con éxito a: ${userEmail}`);
  } catch (error) {
    console.error(
      "Error crítico al enviar email con PDF adjunto:",
      error.response ? error.response.status : error.statusCode,
      error.message,
    );
  }
}

async function sendPush(userId, title, body, type = "general") {
  const db = getFirestore();

  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const token = userData?.fcmToken;

    await db.collection("users").doc(userId).collection("notifications").add({
      title: title,
      body: body,
      type: type,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(
      `[Historial] Notificación guardada en la base de datos para el usuario: ${userId}`,
    );

    if (token && token.trim() !== "") {
      const message = {
        notification: {
          title: title,
          body: body,
        },
        token: token,
      };

      const response = await admin.messaging().send(message);
      console.log(
        `[FCM PUSH] Push enviado con éxito al token. ID: ${response}`,
      );
    } else {
      console.log(
        `[FCM PUSH AVISO] El usuario ${userId} no tiene un token FCM registrado. Solo se guardó en el historial.`,
      );
    }
  } catch (error) {
    console.error(
      `🚨 Error en el proceso de sendPush para el usuario ${userId}:`,
      error,
    );
  }
}

// ==========================================
// --- DISPARADORES DE FIRESTORE (TRIGGERS) ---
// ==========================================

// --- EVENTO 1: CREACION DE PROPIEDAD---
exports.onPropertyCreate = onDocumentCreated(
  "properties/{propertyId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const propertyData = snapshot.data();

    try {
      const ownerId = propertyData.ownerId;
      const address = propertyData.address || "Nueva Propiedad";
      const titleProperty = propertyData.title || "Inmueble";

      const pushNotifications = [];

      if (ownerId) {
        pushNotifications.push(
          sendPush(
            ownerId,
            "🏠 Propiedad Registrada",
            `Tu propiedad ubicada en ${address} ha sido creada con éxito y está pendiente de revisión.`,
          ),
        );
      }

      const adminIds = await getAdminIds();
      if (adminIds.length > 0) {
        adminIds.forEach((adminId) => {
          pushNotifications.push(
            sendPush(
              adminId,
              "🔔 Nuevo inmueble Creado",
              `Se ha registrado una nueva propiedad en la dirección: ${address}. Requiere revisión administrativa.`,
            ),
          );
        });
      } else {
        console.warn(
          "Alerta: No se encontraron usuarios con el rol 'admin' en el sistema.",
        );
      }

      const topicMessage = {
        notification: {
          title: "✨ ¡Nueva Propiedad Disponible!",
          body: `Se ha publicado una nueva oportunidad: ${titleProperty} en ${address}. ¡Mírala antes de que se arriende!`,
        },
        topic: "nuevos_inmuebles",
      };

      const topicPushPromise = admin
        .messaging()
        .send(topicMessage)
        .then((response) => {
          console.log(
            `🚀 [FCM TOPIC] Mensaje masivo enviado con éxito. ID de tracking: ${response}`,
          );
          return response;
        })
        .catch((error) => {
          console.error(`🚨 [FCM TOPIC ERROR] El envío al Topic falló:`, error);
          throw error;
        });

      pushNotifications.push(topicPushPromise);
      if (pushNotifications.length > 0) {
        await Promise.all(pushNotifications);
        console.log(
          `¡Flujo completado! Notificaciones Push enviadas al dueño, administradores y masivamente a los inquilinos.`,
        );
      }
    } catch (error) {
      console.error(
        "Error crítico en la ejecución del flujo onPropertyCreate:",
        error,
      );
    }
  },
);

// --- EVENTO 2: NOTIFICACION PARA PAGOS PROPIETARIO DEL INMUEBLE ---
exports.onPropertyUpdate = onDocumentUpdated(
  "properties/{propertyId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log("Faltan datos del evento para procesar la actualización.");
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      if (
        newData.status === PropertyStatusEnum.approvedPendingPayment &&
        oldData.status === PropertyStatusEnum.pendingReview
      ) {
        const ownerId = newData.ownerId;
        const address = newData.address || "Tu propiedad";

        console.log(
          `Propiedad ${event.params.propertyId} aprobada. Notificando al propietario: ${ownerId}`,
        );

        if (ownerId) {
          await sendPush(
            ownerId,
            "✅ Propiedad Aprobada",
            `Tu propiedad en ${address} ha sido aprobada. Ya puedes proceder con el pago para activarla en el sistema.`,
          );
          console.log(
            "Notificación de aprobación enviada con éxito al propietario.",
          );
        } else {
          console.warn(
            "No se pudo enviar el push porque la propiedad no tiene un 'ownerId' válido.",
          );
        }
      }
    } catch (error) {
      console.error("Error en la ejecución del flujo onPropertyUpdate:", error);
    }
  },
);

// --- EVENTO 3: PROPIEDAD PAGADA (NOTIFICAR A PROPIETARIO Y ADMINS) ---
exports.onPropertyPaidReview = onDocumentUpdated(
  "properties/{propertyId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log(
        "Faltan datos del evento para procesar la actualización de pago.",
      );
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      if (
        newData.status === PropertyStatusEnum.paidPendingReview &&
        oldData.status === PropertyStatusEnum.approvedPendingPayment
      ) {
        const ownerId = newData.ownerId;
        const address = newData.address || "Tu propiedad";

        console.log(
          `Pago recibido para la propiedad ${event.params.propertyId}. Procesando notificaciones...`,
        );

        const notifications = [];

        if (ownerId) {
          notifications.push(
            sendPush(
              ownerId,
              "💰 ¡Pago Exitoso!",
              `El pago para activar tu propiedad en ${address} ha sido procesado. Un administrador verificará el soporte pronto.`,
            ),
          );
        }

        const adminIds = await getAdminIds();
        if (adminIds.length > 0) {
          adminIds.forEach((adminId) => {
            notifications.push(
              sendPush(
                adminId,
                "🔔 Pago por Verificar",
                `El propietario de ${address} ha realizado el pago. Requiere revisión del comprobante.`,
              ),
            );
          });
        } else {
          console.warn(
            "No se encontraron administradores para notificar sobre el pago.",
          );
        }

        if (notifications.length > 0) {
          await Promise.all(notifications);
          console.log(`Flujo de notificaciones de pago completado con éxito.`);
        }
      }
    } catch (error) {
      console.error(
        "Error en la ejecución del flujo onPropertyPaidReview:",
        error,
      );
    }
  },
);

// --- EVENTO 4: CONTROL DE PAGO APROBADO O RECHAZADO ---
exports.onPropertyPaymentDecision = onDocumentUpdated(
  "properties/{propertyId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log("Faltan datos del evento para procesar la decisión de pago.");
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    const ownerId = newData.ownerId;
    const address = newData.address || "Tu propiedad";

    try {
      if (
        newData.status === PropertyStatusEnum.waitingContract &&
        oldData.status === PropertyStatusEnum.paidPendingReview &&
        newData.paymentStatus === PaymentStatusEnum.approved &&
        oldData.paymentStatus !== PaymentStatusEnum.approved
      ) {
        console.log(
          `Pago APROBADO para propiedad ${event.params.propertyId}. Notificando al propietario...`,
        );

        if (ownerId) {
          await sendPush(
            ownerId,
            "🎉 ¡Pago Verificado y Aprobado!",
            `El soporte de pago para ${address} ha sido legalizado. El abogado procederá a redactar el contrato.`,
          );
        }
        return;
      }

      if (
        newData.status === PropertyStatusEnum.approvedPendingPayment &&
        oldData.status === PropertyStatusEnum.paidPendingReview &&
        newData.paymentStatus === PaymentStatusEnum.rejected &&
        oldData.paymentStatus !== PaymentStatusEnum.rejected
      ) {
        console.log(
          `Pago RECHAZADO para propiedad ${event.params.propertyId}. Notificando al propietario...`,
        );

        if (ownerId) {
          await sendPush(
            ownerId,
            "❌ Comprobante de Pago Rechazado",
            `El soporte enviado para la propiedad en ${address} no pudo ser verificado. Por favor, sube un comprobante válido.`,
          );
        }
        return;
      }
    } catch (error) {
      console.error(
        "Error en la ejecución del flujo onPropertyPaymentDecision:",
        error,
      );
    }
  },
);

// --- EVENTO 5: SOLICITUD DE CITA EXITOSA (DATOS REALES FIRESTORE) ---
exports.onAppointmentCreated = onDocumentCreated(
  "appointments/{appointmentId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const appointmentData = snapshot.data();

    try {
      const tenantId = appointmentData.tenantId;
      const tenantName = appointmentData.tenantName || "Usuario";
      const address =
        appointmentData.propertyAddress || "la propiedad seleccionada";

      let dateText = "la hora acordada";
      if (appointmentData.appointmentDate) {
        const dateObject = appointmentData.appointmentDate.toDate();
        dateText = dateObject.toLocaleString("es-CO", {
          timeZone: "America/Bogota",
        });
      }

      console.log(
        `Nueva cita detectada en estado '${appointmentData.status}' con ID: ${event.params.appointmentId}`,
      );

      const notifications = [];

      if (tenantId) {
        notifications.push(
          sendPush(
            tenantId,
            "🗓️ Cita Agendada",
            `Hola ${tenantName}, tu espacio ha sido reservado con éxito para visitar la propiedad en ${address} el día: ${dateText}.`,
          ),
        );
      }

      const adminIds = await getAdminIds();
      if (adminIds.length > 0) {
        adminIds.forEach((adminId) => {
          notifications.push(
            sendPush(
              adminId,
              "🔔 Nueva Cita Solicitada",
              `${tenantName} ha agendado una cita para visitar la propiedad en ${address} para el día: ${dateText}.`,
            ),
          );
        });
      } else {
        console.warn(
          "Alerta: No se encontraron administradores para alertar sobre la nueva cita.",
        );
      }

      if (notifications.length > 0) {
        await Promise.all(notifications);
        console.log(
          "Flujo de notificaciones de citas ejecutado sin errores de compatibilidad.",
        );
      }
    } catch (error) {
      console.error(
        "Error en la ejecución del flujo onAppointmentCreated:",
        error,
      );
    }
  },
);

// --- EVENTO 6: NUEVA POSTULACIÓN (NOTIFICAR A CANDIDATO Y ADMINS) ---
exports.onNewCandidateApplication = onDocumentUpdated(
  "applications/{applicationId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log("Faltan datos del evento para procesar la postulación.");
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      const newCandidates = newData.candidates || [];
      const oldCandidates = oldData.candidates || [];

      if (newCandidates.length > oldCandidates.length) {
        const newestCandidate = newCandidates[newCandidates.length - 1];

        if (!newestCandidate) return;

        const tenantId = newestCandidate.uid;
        const tenantName = newestCandidate.nombre || "Usuario";
        const propertyAddress = newData.address || "la propiedad seleccionada";

        console.log(
          `Nuevo postulante detectado (${tenantName}) en la aplicación: ${event.params.applicationId}`,
        );

        const notifications = [];

        if (tenantId) {
          notifications.push(
            sendPush(
              tenantId,
              "📋 Postulación Recibida",
              `Hola ${tenantName}, te has postulado exitosamente para el inmueble en ${propertyAddress}. Tu perfil entró en estado de revisión.`,
            ),
          );
        }

        const adminIds = await getAdminIds();
        if (adminIds.length > 0) {
          adminIds.forEach((adminId) => {
            notifications.push(
              sendPush(
                adminId,
                "🔔 Nuevo Postulante",
                `${tenantName} se ha postulado como candidato para la propiedad en ${propertyAddress}.`,
              ),
            );
          });
        } else {
          console.warn(
            "No se encontraron administradores para alertar sobre la postulación.",
          );
        }

        if (notifications.length > 0) {
          await Promise.all(notifications);
          console.log(
            "Flujo de notificaciones de nuevos postulantes completado.",
          );
        }
      }
    } catch (error) {
      console.error(
        "Error en la ejecución del flujo onNewCandidateApplication:",
        error,
      );
    }
  },
);

// --- EVENTO 7: DECISIÓN DE POSTULACIÓN (APROBACIÓN O RECHAZO DE CANDIDATOS) ---
exports.onCandidateStatusDecision = onDocumentUpdated(
  "applications/{applicationId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log(
        "Faltan datos del evento para procesar la decisión del candidato.",
      );
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      const newCandidates = newData.candidates || [];
      const oldCandidates = oldData.candidates || [];
      const propertyAddress = newData.address || "la propiedad seleccionada";

      if (newCandidates.length !== oldCandidates.length) return;

      let approvedCandidate = null;
      let singleRejectedCandidate = null;

      for (let i = 0; i < newCandidates.length; i++) {
        const current = newCandidates[i];
        const previous = oldCandidates[i];

        if (
          current.status === "approved" &&
          previous.status === "pending_review"
        ) {
          approvedCandidate = current;
          break;
        }

        if (
          current.status === "rejected" &&
          previous.status === "pending_review"
        ) {
          singleRejectedCandidate = current;
        }
      }

      const notifications = [];

      if (approvedCandidate) {
        console.log(
          `Candidato APROBADO detectado: ${approvedCandidate.uid}. Procesando notificación masiva...`,
        );

        newCandidates.forEach((candidate) => {
          if (candidate.uid === approvedCandidate.uid) {
            notifications.push(
              sendPush(
                candidate.uid,
                "🎉 ¡Postulación Aprobada!",
                `Felicitaciones ${candidate.nombre}, tu perfil ha sido seleccionado y aprobado para el inmueble en ${propertyAddress}. El abogado iniciará el borrador del contrato.`,
              ),
            );
          } else {
            notifications.push(
              sendPush(
                candidate.uid,
                "📋 Proceso de Postulación Cerrado",
                `Hola ${candidate.nombre}, te informamos que la propiedad en ${propertyAddress} ya ha sido asignada a otro postulante. ¡Agradecemos tu interés!`,
              ),
            );
          }
        });
      } else if (singleRejectedCandidate) {
        console.log(
          `Candidato RECHAZADO individualmente detectado: ${singleRejectedCandidate.uid}`,
        );

        notifications.push(
          sendPush(
            singleRejectedCandidate.uid,
            "❌ Postulación Rechazada",
            `Hola ${singleRejectedCandidate.nombre}, tu solicitud para la propiedad en ${propertyAddress} ha sido revisada y no cumple con los requisitos del estudio de seguridad.`,
          ),
        );
      }

      if (notifications.length > 0) {
        await Promise.all(notifications);
        console.log(
          `Flujo de decisiones de candidatos ejecutado correctamente. Notificaciones enviadas: ${notifications.length}`,
        );
      }
    } catch (error) {
      console.error(
        "Error en la ejecución del flujo onCandidateStatusDecision:",
        error,
      );
    }
  },
);

// --- EVENTO 8: FLUJO DE FIRMAS Y AVANCES DEL CONTRATO LEGAL ---
exports.onContractProgressDecision = onDocumentUpdated(
  "contracts/{contractId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log(
        "Faltan datos del evento para procesar el avance del contrato.",
      );
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    const ownerId = newData.ownerId;
    const tenantId = newData.tenantId;
    const propertyAddress =
      newData.propertyAddress || "el inmueble seleccionado";

    try {
      const notifications = [];

      if (newData.baseContractPdfUrl && !oldData.baseContractPdfUrl) {
        console.log(
          `Borrador de contrato disponible para ${event.params.contractId}. Notificando al inquilino...`,
        );

        if (tenantId) {
          notifications.push(
            sendPush(
              tenantId,
              "✍️ Contrato Listo para Firma",
              `El abogado ha subido el borrador legal para la propiedad en ${propertyAddress}. Por favor, revísalo y realiza tu firma digital.`,
            ),
          );
        }
      }

      if (newData.ownerSignedPdfUrl && !oldData.ownerSignedPdfUrl) {
        console.log(
          `El inquilino firmó el contrato ${event.params.contractId}. Notificando a propietario y admins...`,
        );

        if (ownerId) {
          notifications.push(
            sendPush(
              ownerId,
              "✍️ Contrato Pendiente de tu Firma",
              `El inquilino ya ha firmado el contrato de arrendamiento para ${propertyAddress}. Es tu turno de ingresar and firmar el documento.`,
            ),
          );
        }

        const adminIds = await getAdminIds();
        if (adminIds.length > 0) {
          adminIds.forEach((adminId) => {
            notifications.push(
              sendPush(
                adminId,
                "🔔 Propietario Firmó Contrato",
                `El propietario de la propiedad en ${propertyAddress} ha estampado su firma en el documento legal.`,
              ),
            );
          });
        }
      }

      if (newData.tenantSignedPdfUrl && !oldData.tenantSignedPdfUrl) {
        console.log(
          `El inquilino firmó el contrato ${event.params.contractId}. Notificando a propietario y admins...`,
        );

        if (ownerId) {
          notifications.push(
            sendPush(
              ownerId,
              "📄 Inquilino Firmó el Contrato",
              `El arrendatario ha completado la firma digital del contrato para ${propertyAddress}. El proceso pasa a revisión final.`,
            ),
          );
        }

        const adminIds = await getAdminIds();
        if (adminIds.length > 0) {
          adminIds.forEach((adminId) => {
            notifications.push(
              sendPush(
                adminId,
                "🔔 Firmas Completadas - Contrato Listo",
                `El inquilino ha firmado el contrato de ${propertyAddress}. Todas las firmas están listas para tu validación final.`,
              ),
            );
          });
        }
      }

      if (notifications.length > 0) {
        await Promise.all(notifications);
        console.log(
          `Flujo de notificaciones de contratos finalizado con éxito.`,
        );
      }
    } catch (error) {
      console.error(
        "Error en la ejecución del flujo onContractProgressDecision:",
        error,
      );
    }
  },
);

// --- EVENTO 9: LEGALIZACIÓN Y ACTIVACIÓN FINAL DEL CONTRATO (NOTIFICAR A AMBAS PARTES) ---
exports.onContractActivatedFinal = onDocumentUpdated(
  "contracts/{contractId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log(
        "Faltan datos del evento para procesar la activación del contrato.",
      );
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      if (
        newData.status === ContractStatus.active &&
        oldData.status === ContractStatus.signedPendingReview
      ) {
        const ownerId = newData.ownerId;
        const tenantId = newData.tenant?.uid;
        const propertyAddress =
          newData.propertyAddress || "el inmueble seleccionado";

        const finalContractPdf = newData.ownerSignedPdfUrl;

        if (!finalContractPdf) {
          console.error(
            `Error: No se encontró la URL 'ownerSignedPdfUrl' en el contrato ${event.params.contractId}.`,
          );
          return;
        }

        const tenantNameEmbed =
          newData.tenant && newData.tenant.nombre
            ? newData.tenant.nombre
            : "tu inquilino";

        console.log(
          `¡CONTRATO LEGALIZADO! Documento: ${event.params.contractId}. Extrayendo información de contacto de las partes...`,
        );

        const [ownerContact, tenantContact] = await Promise.all([
          getUserContactData(ownerId),
          getUserContactData(tenantId),
        ]);

        const notifications = [];
        const subjectGeneral = `🏠 Contrato Legalizado - ${propertyAddress}`;

        if (ownerId) {
          const contentOwner = `¡Buenas noticias! El proceso de firmas ha sido validado y aprobado por el área legal. Tu propiedad en ${propertyAddress} se encuentra activa y arrendada legalmente a ${tenantNameEmbed}. Adjunto encontrarás el contrato firmado por todas las partes.`;

          notifications.push(
            sendPush(ownerId, "🏠 ¡Inmueble Arrendado!", contentOwner),
          );

          if (ownerContact && ownerContact.email) {
            notifications.push(
              sendEmailWithPdfAttachment(
                ownerContact.email,
                ownerContact.name,
                subjectGeneral,
                contentOwner,
                finalContractPdf,
              ),
            );
          }
        }

        if (tenantId) {
          const contentTenant = `¡Felicidades! Tu contrato de arrendamiento para la propiedad en ${propertyAddress} ha sido aprobado. El proceso legal ha terminado con éxito. Ya puedes coordinar la entrega de llaves. Adjunto encuentras tu copia digital legalizada.`;

          notifications.push(
            sendPush(tenantId, "🔑 ¡Proceso Completado!", contentTenant),
          );

          if (tenantContact && tenantContact.email) {
            notifications.push(
              sendEmailWithPdfAttachment(
                tenantContact.email,
                tenantContact.name,
                subjectGeneral,
                contentTenant,
                finalContractPdf,
              ),
            );
          }
        }

        const lawyerEmail = "davidbarrera@humanbionics.com.co";
        const lawyerName = "Área Jurídica Armando Marín";

        const contentLawyer = `Se ha formalizado y activado con éxito el contrato de arrendamiento correspondiente al inmueble en ${propertyAddress}. Inquilino: ${tenantNameEmbed}. Adjuntamos el documento firmado mediante la plataforma para el archivo del historial jurídico de la inmobiliaria.`;

        if (lawyerEmail) {
          notifications.push(
            sendEmailWithPdfAttachment(
              lawyerEmail,
              lawyerName,
              `⚖️ [Archivo Jurídico] Contrato Activado - ${propertyAddress}`,
              contentLawyer,
              finalContractPdf,
            ),
          );
        }

        if (notifications.length > 0) {
          await Promise.all(notifications);
          console.log(
            `Flujo onContractActivatedFinal finalizado. Correos masivos con PDF enviado a Inquilino, Propietario y Abogado.`,
          );
        }
      }
    } catch (error) {
      console.error(
        "Error crítico en la ejecución del flujo onContractActivatedFinal:",
        error,
      );
    }
  },
);

// --- EVENTO 10: CÁLCULO DE PROMEDIO DE REVIEWS Y NOTIFICACIÓN DE REPUTACIÓN ---
exports.onNewUserReview = onDocumentCreated(
  "users/{userId}/reviews/{reviewId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No se encontraron datos en el evento de review.");
      return;
    }

    const db = getFirestore();
    const userId = event.params.userId;
    const reviewData = snapshot.data();

    try {
      console.log(
        `Nueva calificación detectada para el usuario: ${userId}. Calculando promedio...`,
      );

      const reviewsRef = db
        .collection("users")
        .doc(userId)
        .collection("reviews");
      const reviewsSnapshot = await reviewsRef.get();

      let totalStars = 0;
      const totalReviews = reviewsSnapshot.size;

      if (totalReviews === 0) {
        console.log(`El usuario ${userId} no tiene reseñas registradas.`);
        return;
      }

      reviewsSnapshot.forEach((doc) => {
        const data = doc.data();
        const score = Number(data.rating);
        if (!isNaN(score) && score >= 1 && score <= 5) {
          totalStars += score;
        }
      });

      const averageRating = totalStars / totalReviews;

      console.log(
        `[MÉTRICAS] Usuario: ${userId} | Total Reseñas: ${totalReviews} | Nuevo Promedio: ${averageRating.toFixed(2)}`,
      );

      await db
        .collection("users")
        .doc(userId)
        .update({
          rating: parseFloat(averageRating.toFixed(2)),
          reviewCount: totalReviews,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(
        `Perfil del usuario ${userId} actualizado en Firestore usando el campo 'rating'.`,
      );

      const fromName = reviewData.fromName || "Un usuario";
      const fromRole =
        reviewData.fromRole === "landlord" ? "propietario" : "inquilino";
      const ratingStars = reviewData.rating || 5;

      const starsVisual = "⭐".repeat(ratingStars);

      const titlePush = "📝 ¡Te han calificado!";
      const bodyPush = `${fromName} (${fromRole}) te ha dejado una calificación de ${starsVisual}. Recuerda calificarlo tú también para cerrar el ciclo legal del contrato.`;

      console.log(`Enviando notificación push de reseña a usuario: ${userId}`);

      await sendPush(userId, titlePush, bodyPush);

      console.log(
        `Flujo de notificación y métricas de reseñas completado con éxito.`,
      );
    } catch (error) {
      console.error(
        "Error crítico al calcular el promedio o notificar en onNewUserReview:",
        error,
      );
    }
  },
);

exports.onPaymentCreated = onDocumentCreated(
  "payments/{paymentId}",
  async (event) => {
    const payment = event.data.data();

    await sendPush(
      payment.tenantId,
      "💰 Pago Recibido",
      "Tu pago ha sido procesado exitosamente.",
    );
  },
);

// --- VINCULACIÓN DEL EVENTO DEL PDF EN FIRESTORE DE VIAFIRMA ---
exports.onContractPdfReadyCreateSignature = onDocumentUpdated(
  "contracts/{contractId}",
  async (event) => {
    if (!event.data || !event.data.after || !event.data.before) {
      console.log(
        "❌ [VIAFIRMA TRIGGER] Estructura del evento inválida o incompleta.",
      );
      return;
    }

    const db = getFirestore();
    const contractId = event.params.contractId;
    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    if (!newData.baseContractPdfUrl) {
      console.log(
        "⚠️ [VIAFIRMA TRIGGER] Abortando: 'baseContractPdfUrl' está vacío en el documento.",
      );
      return;
    }

    if (oldData && oldData.baseContractPdfUrl === newData.baseContractPdfUrl) {
      console.log(
        "ℹ [VIAFIRMA TRIGGER] Abortando: El PDF no ha cambiado. Evitando ejecuciones duplicadas.",
      );
      return;
    }

    try {
      console.log(
        "🔍 [VIAFIRMA TRIGGER] Paso 1: Extrayendo identificadores de usuarios...",
      );

      const ownerId = newData.ownerId || newData.owner?.uid;
      const tenantId = newData.tenantId || newData.tenant?.uid;

      if (!ownerId || !tenantId) {
        console.error(
          "❌ [VIAFIRMA TRIGGER] Error Fatal: Falta el ownerId o el tenantId en el payload.",
        );
        return;
      }

      console.log(
        "📞 [VIAFIRMA TRIGGER] Paso 2: Consultando información de contacto en bases de datos...",
      );

      const [ownerContact, tenantContact] = await Promise.all([
        getUserContactData(ownerId),
        getUserContactData(tenantId),
      ]);

      console.log(
        `📩 [VIAFIRMA TRIGGER] Datos recuperados -> Propietario: ${ownerContact?.email} | Inquilino: ${tenantContact?.email}`,
      );

      if (!ownerContact?.email || !tenantContact?.email) {
        console.error(
          "❌ [VIAFIRMA TRIGGER] Error: Uno o ambos correos electrónicos no están definidos.",
        );
        return;
      }

      const propertyAddress =
        newData.propertyAddress || "Contrato de arrendamiento";

      console.log(
        "🛰 [VIAFIRMA TRIGGER] Paso 3: Enviando payload de documento a la API de Viafirma...",
      );

      const viafirmaResponse = await createSignatureSet({
        title: `Contrato ${propertyAddress}`,
        description: "Contrato de arrendamiento creado desde backend",
        userCode: "davidbarrera@humanbionics.com.co",
        tenantEmail: tenantContact.email,
        tenantName: tenantContact.name,
        ownerEmail: ownerContact.email,
        ownerName: ownerContact.name,
        pdfUrl: newData.baseContractPdfUrl,
      });

      const setCode = viafirmaResponse.code || viafirmaResponse.setCode || null;

      const messageCode =
        viafirmaResponse.messages?.[0]?.code ||
        viafirmaResponse.messageCode ||
        null;

      const tenantLinkData =
        viafirmaResponse.links?.find((item) => item.key === "firmante_1") ||
        null;

      const ownerLinkData =
        viafirmaResponse.links?.find((item) => item.key === "firmante_2") ||
        null;

      const tenantSignLink = tenantLinkData?.link || null;
      const ownerSignLink = ownerLinkData?.link || null;

      const tenantSignToken = tenantLinkData?.token || null;
      const ownerSignToken = ownerLinkData?.token || null;

      console.log(`🔗 [VIAFIRMA TRIGGER] Link inquilino: ${tenantSignLink}`);
      console.log(`🔗 [VIAFIRMA TRIGGER] Link propietario: ${ownerSignLink}`);

      if (!tenantSignLink) {
        console.warn(
          "⚠️ [VIAFIRMA TRIGGER] No llegó link para firmante_1. Revisa que presential=true y notificationType=NONE.",
        );
      }

      if (!ownerSignLink) {
        console.warn(
          "⚠️ [VIAFIRMA TRIGGER] No llegó link para firmante_2. Revisa que presential=true y notificationType=NONE.",
        );
      }

      console.log(
        "💾 [VIAFIRMA TRIGGER] Paso 5: Creando documento histórico en la colección 'signatures'...",
      );

      const initialPartyTracking = {
        globalStatus: "RESPONSES_WAITING",
        lastCheckedAt: new Date().toISOString(),

        [tenantId]: {
          uid: tenantId,
          role: "tenant",
          key: "firmante_1",
          email: tenantContact.email,
          name: tenantContact.name || "Inquilino",
          status: "PENDING",
          signLink: tenantSignLink,
          signToken: tenantSignToken,
        },

        [ownerId]: {
          uid: ownerId,
          role: "owner",
          key: "firmante_2",
          email: ownerContact.email,
          name: ownerContact.name || "Propietario",
          status: "WAITING",
          signLink: ownerSignLink,
          signToken: ownerSignToken,
        },
      };

      const docSignRef = await db.collection("signatures").add({
        contractId,
        propertyId: newData.propertyId || null,

        ownerId,
        tenantId,

        ownerEmail: ownerContact.email,
        tenantEmail: tenantContact.email,

        ownerName: ownerContact.name || "Propietario",
        tenantName: tenantContact.name || "Inquilino",

        pdfUrl: newData.baseContractPdfUrl,

        viafirmaSetCode: setCode,
        viafirmaMessageCode: messageCode,

        status: "created",
        signatureStatus: "created",

        tenantSignLink,
        ownerSignLink,

        tenantSignToken,
        ownerSignToken,

        signaturesTracking: initialPartyTracking,

        recipients: [
          {
            role: "tenant",
            key: "firmante_1",
            uid: tenantId,
            email: tenantContact.email,
            name: tenantContact.name || "Inquilino",
            status: "PENDING",
            signLink: tenantSignLink,
            signToken: tenantSignToken,
          },
          {
            role: "owner",
            key: "firmante_2",
            uid: ownerId,
            email: ownerContact.email,
            name: ownerContact.name || "Propietario",
            status: "WAITING",
            signLink: ownerSignLink,
            signToken: ownerSignToken,
          },
        ],

        rawCreateResponse: viafirmaResponse,

        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        "📝 [VIAFIRMA TRIGGER] Paso 6: Actualizando metadatos de firma en el documento del contrato...",
      );

      await db.collection("contracts").doc(contractId).update({
        viafirmaSetCode: setCode,
        viafirmaMessageCode: messageCode,
        viafirmaSignatureDocId: docSignRef.id,

        signatureStatus: "created",

        signaturesTracking: initialPartyTracking,

        tenantSignatureStatus: "PENDING",
        ownerSignatureStatus: "WAITING",

        tenantSignLink,
        ownerSignLink,

        tenantSignToken,
        ownerSignToken,

        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        "🔔 [VIAFIRMA TRIGGER] Paso 7: Enviando notificación push al dispositivo del inquilino...",
      );

      await sendPush(
        tenantId,
        "✍ Contrato listo para firma",
        `Ya puedes firmar el contrato de ${propertyAddress}.`,
        "contract_signature",
      );

      console.log(
        "🏁 [VIAFIRMA TRIGGER] Proceso completado exitosamente y cerrado sin anomalías.",
      );
    } catch (error) {
      console.error(
        "💥 [VIAFIRMA TRIGGER] CRASH - Error en el bloque catch principal:",
        {
          message: error.message,
          data: error.response?.data,
        },
      );

      await db
        .collection("contracts")
        .doc(contractId)
        .update({
          signatureStatus: "error",
          signatureError: error.response?.data || error.message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
  },
);

// ==========================================
// --- ENDPOINTS HTTP (ONREQUEST) ---
// ==========================================

// ==========================================
// --- ENDPOINTS HTTP (ONREQUEST) ---
// ==========================================

function normalizeViafirmaStatus(status) {
  if (!status) return "PENDING";

  const value = status.toString().toUpperCase();

  if (["SIGNED", "COMPLETED", "FINISHED", "RESPONSED"].includes(value)) {
    return "SIGNED";
  }

  if (["REJECTED", "REFUSED", "CANCELED", "CANCELLED"].includes(value)) {
    return "REJECTED";
  }

  if (
    [
      "WAITING",
      "PENDING",
      "RECEIVED",
      "RESPONSES_WAITING",
      "PROCESSING",
    ].includes(value)
  ) {
    return "PENDING";
  }

  return value;
}

function extractEvidencesFromViafirma(data) {
  const evidences = [];

  if (!data) return evidences;

  const messages = data.messages || [];

  messages.forEach((message) => {
    const policies = message.policies || [];

    policies.forEach((policy) => {
      const policyEvidences = policy.evidences || [];
      evidences.push(...policyEvidences);
    });

    if (Array.isArray(message.evidences)) {
      evidences.push(...message.evidences);
    }

    if (Array.isArray(message.recipients)) {
      message.recipients.forEach((recipient) => {
        evidences.push({
          recipientKey: recipient.key || recipient.recipientKey,
          status: recipient.status,
          mail: recipient.mail || recipient.email,
        });
      });
    }
  });

  if (Array.isArray(data.evidences)) {
    evidences.push(...data.evidences);
  }

  if (Array.isArray(data.recipients)) {
    data.recipients.forEach((recipient) => {
      evidences.push({
        recipientKey: recipient.key || recipient.recipientKey,
        status: recipient.status,
        mail: recipient.mail || recipient.email,
      });
    });
  }

  if (Array.isArray(data.signers)) {
    data.signers.forEach((signer) => {
      evidences.push({
        recipientKey: signer.key || signer.recipientKey,
        status: signer.status,
        mail: signer.mail || signer.email,
      });
    });
  }

  return evidences;
}

function parseViafirmaSignatureState(viafirmaData, signatureData) {
  const evidences = extractEvidencesFromViafirma(viafirmaData);

  let tenantSignatureStatus = "PENDING";
  let ownerSignatureStatus = "WAITING";

  const tenantEmail = (signatureData.tenantEmail || "").toLowerCase();
  const ownerEmail = (signatureData.ownerEmail || "").toLowerCase();

  evidences.forEach((evidence) => {
    const recipientKey =
      evidence.recipientKey ||
      evidence.key ||
      evidence.recipient?.key ||
      evidence.signerKey ||
      null;

    const email =
      (
        evidence.mail ||
        evidence.email ||
        evidence.recipient?.mail ||
        evidence.recipient?.email ||
        ""
      ).toLowerCase();

    const normalizedStatus = normalizeViafirmaStatus(evidence.status);

    if (recipientKey === "firmante_1" || email === tenantEmail) {
      tenantSignatureStatus = normalizedStatus;
    }

    if (recipientKey === "firmante_2" || email === ownerEmail) {
      ownerSignatureStatus = normalizedStatus;
    }
  });

  const globalStatus = normalizeViafirmaStatus(
    viafirmaData.status ||
      viafirmaData.setStatus ||
      viafirmaData.workflow?.current ||
      viafirmaData.summary?.status,
  );

  if (globalStatus === "SIGNED" || globalStatus === "FINISHED") {
    tenantSignatureStatus = "SIGNED";
    ownerSignatureStatus = "SIGNED";
  }

  const tenantId = signatureData.tenantId;
  const ownerId = signatureData.ownerId;

  const signaturesTracking = {
    globalStatus,
    lastCheckedAt: new Date().toISOString(),

    [tenantId]: {
      uid: tenantId,
      role: "tenant",
      key: "firmante_1",
      email: signatureData.tenantEmail || "",
      name: signatureData.tenantName || "Inquilino",
      status: tenantSignatureStatus,
      signLink: signatureData.tenantSignLink || null,
      signToken: signatureData.tenantSignToken || null,
    },

    [ownerId]: {
      uid: ownerId,
      role: "owner",
      key: "firmante_2",
      email: signatureData.ownerEmail || "",
      name: signatureData.ownerName || "Propietario",
      status: ownerSignatureStatus,
      signLink: signatureData.ownerSignLink || null,
      signToken: signatureData.ownerSignToken || null,
    },
  };

  const recipients = [
    {
      role: "tenant",
      key: "firmante_1",
      uid: tenantId,
      email: signatureData.tenantEmail || "",
      name: signatureData.tenantName || "Inquilino",
      status: tenantSignatureStatus,
      signLink: signatureData.tenantSignLink || null,
      signToken: signatureData.tenantSignToken || null,
    },
    {
      role: "owner",
      key: "firmante_2",
      uid: ownerId,
      email: signatureData.ownerEmail || "",
      name: signatureData.ownerName || "Propietario",
      status: ownerSignatureStatus,
      signLink: signatureData.ownerSignLink || null,
      signToken: signatureData.ownerSignToken || null,
    },
  ];

  let appContractStatus = "signatureInProgress";

  if (tenantSignatureStatus === "SIGNED" && ownerSignatureStatus !== "SIGNED") {
    appContractStatus = "waitingOwnerSignature";
  }

  if (ownerSignatureStatus === "SIGNED" && tenantSignatureStatus !== "SIGNED") {
    appContractStatus = "waitingTenantSignature";
  }

  if (tenantSignatureStatus === "SIGNED" && ownerSignatureStatus === "SIGNED") {
    appContractStatus = ContractStatus.signedPendingReview;
  }

  if (
    tenantSignatureStatus === "REJECTED" ||
    ownerSignatureStatus === "REJECTED"
  ) {
    appContractStatus = "signatureRejected";
  }

  if (globalStatus === "ERROR") {
    appContractStatus = "signatureError";
  }

  return {
    globalStatus,
    tenantSignatureStatus,
    ownerSignatureStatus,
    signaturesTracking,
    recipients,
    appContractStatus,
    evidences,
  };
}

function mergeViafirmaResponses(statusResponse, summaryResponse) {
  if (!statusResponse && !summaryResponse) return null;
  if (!statusResponse) return summaryResponse;
  if (!summaryResponse) return statusResponse;

  return {
    ...statusResponse,
    ...summaryResponse,

    status:
      summaryResponse.status ||
      statusResponse.status ||
      summaryResponse.setStatus ||
      statusResponse.setStatus,

    setStatus:
      summaryResponse.setStatus ||
      statusResponse.setStatus ||
      summaryResponse.status ||
      statusResponse.status,

    messages:
      summaryResponse.messages ||
      statusResponse.messages ||
      [],

    evidences: [
      ...(Array.isArray(statusResponse.evidences)
        ? statusResponse.evidences
        : []),
      ...(Array.isArray(summaryResponse.evidences)
        ? summaryResponse.evidences
        : []),
    ],

    recipients: [
      ...(Array.isArray(statusResponse.recipients)
        ? statusResponse.recipients
        : []),
      ...(Array.isArray(summaryResponse.recipients)
        ? summaryResponse.recipients
        : []),
    ],

    signers: [
      ...(Array.isArray(statusResponse.signers)
        ? statusResponse.signers
        : []),
      ...(Array.isArray(summaryResponse.signers)
        ? summaryResponse.signers
        : []),
    ],
  };
}

// --- HTTP ENDPOINT 1: CONSULTAR VIAFIRMA Y ACTUALIZAR FIRESTORE ---
exports.refreshViafirmaStatus = onRequest(
  {
    secrets: ["VIAFIRMA_USER", "VIAFIRMA_API_KEY"],
    cors: true,
  },
  async (req, res) => {
    const db = getFirestore();

    try {
      const signatureId = req.query.signatureId || req.body.signatureId;
      const contractId = req.query.contractId || req.body.contractId;

      let finalSignatureId = signatureId;

      console.log(
        `🔄 [REFRESH VIAFIRMA] Inicio -> signatureId: ${signatureId} | contractId: ${contractId}`,
      );

      if (!finalSignatureId && contractId) {
        const contractDoc = await db
          .collection("contracts")
          .doc(contractId)
          .get();

        if (contractDoc.exists) {
          finalSignatureId = contractDoc.data().viafirmaSignatureDocId;
        }
      }

      if (!finalSignatureId) {
        return res.status(400).json({
          ok: false,
          message: "Falta signatureId o contractId válido",
        });
      }

      const signatureRef = db.collection("signatures").doc(finalSignatureId);
      const signatureDoc = await signatureRef.get();

      if (!signatureDoc.exists) {
        return res.status(404).json({
          ok: false,
          message: "No existe el documento signatures",
        });
      }

      const signatureData = signatureDoc.data();

      if (!signatureData.viafirmaSetCode) {
        return res.status(400).json({
          ok: false,
          message: "La firma no tiene viafirmaSetCode",
        });
      }

      const setCode = signatureData.viafirmaSetCode;

      console.log(
        `🛰 [REFRESH VIAFIRMA] Consultando API Viafirma set/status y set/summary: ${setCode}`,
      );

      let statusResponse = null;
      let summaryResponse = null;

      try {
        statusResponse = await getSetStatus(setCode);

        console.log(
          "📦 [REFRESH VIAFIRMA] Status recibido:",
          JSON.stringify(statusResponse, null, 2),
        );
      } catch (statusError) {
        console.warn("⚠️ [REFRESH VIAFIRMA] Falló getSetStatus:", {
          message: statusError.message,
          data: statusError.response?.data,
        });
      }

      try {
        summaryResponse = await getSetSummary(setCode);

        console.log(
          "📦 [REFRESH VIAFIRMA] Summary recibido:",
          JSON.stringify(summaryResponse, null, 2),
        );
      } catch (summaryError) {
        console.warn("⚠️ [REFRESH VIAFIRMA] Falló getSetSummary:", {
          message: summaryError.message,
          data: summaryError.response?.data,
        });
      }

      if (!statusResponse && !summaryResponse) {
        return res.status(502).json({
          ok: false,
          message: "No fue posible consultar Viafirma",
        });
      }

      const viafirmaData = mergeViafirmaResponses(
        statusResponse,
        summaryResponse,
      );

      console.log(
        "📦 [REFRESH VIAFIRMA] Data combinada:",
        JSON.stringify(viafirmaData, null, 2),
      );

      const parsed = parseViafirmaSignatureState(
        viafirmaData,
        signatureData,
      );

      console.log("🧩 [REFRESH VIAFIRMA] Estado interpretado:", {
        globalStatus: parsed.globalStatus,
        tenantSignatureStatus: parsed.tenantSignatureStatus,
        ownerSignatureStatus: parsed.ownerSignatureStatus,
        appContractStatus: parsed.appContractStatus,
      });

      await signatureRef.update({
        status: parsed.globalStatus,
        signatureStatus: parsed.globalStatus,

        tenantSignatureStatus: parsed.tenantSignatureStatus,
        ownerSignatureStatus: parsed.ownerSignatureStatus,

        recipients: parsed.recipients,
        signaturesTracking: parsed.signaturesTracking,

        rawViafirmaStatus: statusResponse || null,
        rawViafirmaSummary: summaryResponse || null,
        rawViafirmaMerged: viafirmaData,
        rawEvidences: parsed.evidences,

        lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (signatureData.contractId) {
        const contractUpdate = {
          signatureStatus: parsed.globalStatus,

          tenantSignatureStatus: parsed.tenantSignatureStatus,
          ownerSignatureStatus: parsed.ownerSignatureStatus,

          signaturesTracking: parsed.signaturesTracking,

          status: parsed.appContractStatus,

          viafirmaLastStatus: statusResponse || null,
          viafirmaLastSummary: summaryResponse || null,
          viafirmaLastMerged: viafirmaData,

          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        console.log(
          "💾 [REFRESH VIAFIRMA] Actualizando contrato:",
          signatureData.contractId,
          contractUpdate,
        );

        await db
          .collection("contracts")
          .doc(signatureData.contractId)
          .update(contractUpdate);
      }

      return res.json({
        ok: true,
        signatureId: finalSignatureId,
        contractId: signatureData.contractId || null,
        viafirmaSetCode: setCode,

        globalStatus: parsed.globalStatus,
        tenantSignatureStatus: parsed.tenantSignatureStatus,
        ownerSignatureStatus: parsed.ownerSignatureStatus,
        appContractStatus: parsed.appContractStatus,

        evidences: parsed.evidences,
        raw: viafirmaData,
      });
    } catch (error) {
      console.error("💥 [REFRESH VIAFIRMA] Error:", {
        message: error.message,
        data: error.response?.data,
      });

      return res.status(500).json({
        ok: false,
        message: error.message,
        detail: error.response?.data || null,
      });
    }
  },
);

// --- HTTP ENDPOINT 2: WEBHOOK LISTENER ACTIVO PARA VIAFIRMA ---
exports.viafirmaWebhookListener = onRequest(
  {
    cors: true,
    secrets: ["VIAFIRMA_USER", "VIAFIRMA_API_KEY"],
  },
  async (req, res) => {
    const db = getFirestore();

    try {
      console.log(
        "📥 [WEBHOOK VIAFIRMA] Payload recibido:",
        JSON.stringify(req.body, null, 2),
      );

      const payload = req.body || {};

      const setCode =
        payload.setCode ||
        payload.code ||
        payload.set?.code ||
        payload.set?.setCode ||
        payload.message?.setCode ||
        null;

      const messageCode =
        payload.messageCode ||
        payload.message?.code ||
        payload.codeMessage ||
        null;

      let signatureQuery = db.collection("signatures");

      if (setCode) {
        signatureQuery = signatureQuery.where("viafirmaSetCode", "==", setCode);
      } else if (messageCode) {
        signatureQuery = signatureQuery.where(
          "viafirmaMessageCode",
          "==",
          messageCode,
        );
      } else {
        console.warn(
          "⚠️ [WEBHOOK VIAFIRMA] Callback sin setCode ni messageCode",
          payload,
        );

        return res.status(400).json({
          ok: false,
          message: "Callback sin setCode ni messageCode",
          payload,
        });
      }

      const snapshot = await signatureQuery.limit(1).get();

      if (snapshot.empty) {
        console.warn("⚠️ [WEBHOOK VIAFIRMA] No encontré firma local:", {
          setCode,
          messageCode,
        });

        return res.status(200).json({
          ok: true,
          message: "Webhook recibido, pero no hay firma local asociada",
        });
      }

      const signatureDoc = snapshot.docs[0];
      const signatureData = signatureDoc.data();

      const realSetCode = signatureData.viafirmaSetCode || setCode;

      console.log(
        `🛰 [WEBHOOK VIAFIRMA] Consultando estado real en Viafirma: ${realSetCode}`,
      );

      let statusResponse = null;
      let summaryResponse = null;

      try {
        statusResponse = await getSetStatus(realSetCode);
      } catch (statusError) {
        console.warn(
          "⚠️ [WEBHOOK VIAFIRMA] Falló getSetStatus, usando summary:",
          {
            message: statusError.message,
            data: statusError.response?.data,
          },
        );

        summaryResponse = await getSetSummary(realSetCode);
      }

      const viafirmaData = statusResponse || summaryResponse;

      const parsed = parseViafirmaSignatureState(viafirmaData, signatureData);

      await signatureDoc.ref.update({
        status: parsed.globalStatus,
        signatureStatus: parsed.globalStatus,

        tenantSignatureStatus: parsed.tenantSignatureStatus,
        ownerSignatureStatus: parsed.ownerSignatureStatus,

        recipients: parsed.recipients,
        signaturesTracking: parsed.signaturesTracking,

        rawWebhookPayload: payload,
        rawViafirmaStatus: statusResponse || null,
        rawViafirmaSummary: summaryResponse || null,
        rawEvidences: parsed.evidences,

        lastCallbackAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (signatureData.contractId) {
        await db
          .collection("contracts")
          .doc(signatureData.contractId)
          .update({
            signatureStatus: parsed.globalStatus,

            tenantSignatureStatus: parsed.tenantSignatureStatus,
            ownerSignatureStatus: parsed.ownerSignatureStatus,

            signaturesTracking: parsed.signaturesTracking,

            status: parsed.appContractStatus,

            viafirmaLastWebhook: payload,
            viafirmaLastStatus: statusResponse || null,
            viafirmaLastSummary: summaryResponse || null,

            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }

      return res.status(200).json({
        ok: true,
        globalStatus: parsed.globalStatus,
        tenantSignatureStatus: parsed.tenantSignatureStatus,
        ownerSignatureStatus: parsed.ownerSignatureStatus,
      });
    } catch (error) {
      console.error("💥 [WEBHOOK VIAFIRMA] Error:", {
        message: error.message,
        data: error.response?.data,
      });

      return res.status(500).json({
        ok: false,
        message: error.message,
        detail: error.response?.data || null,
      });
    }
  },
);
