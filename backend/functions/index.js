// index.js
const {
  onDocumentUpdated,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const Mailjet = require("node-mailjet");
const axios = require("axios");
// --- IMPORTACIÓN DE ENUMS GLOBALES CONGELADOS ---
const {
  PropertyStatusEnum,
  ContractStatus,
  UserRole,
  PaymentStatusEnum,
} = require("./utils/enum"); // Ajusta la ruta si moviste el archivo de constantes

admin.initializeApp();

const mailjet = Mailjet.apiConnect(
  "1b20fafd9a90479c4070e5062bd2c7b9",
  "0464b12dec02ccc232a3ba37ff757670",
);

// --- FUNCIÓN HELPER GLOBAL Y REUTILIZABLE ---
// Busca todos los usuarios con rol 'admin' y devuelve un array con sus IDs.
async function getAdminIds() {
  const db = getFirestore();
  const adminIds = [];

  try {
    // MODIFICADO: Uso de UserRole.admin en lugar de string plano
    const snapshot = await db
      .collection("users")
      .where("role", "==", UserRole.admin)
      .get();

    if (!snapshot.empty) {
      snapshot.forEach((doc) => {
        adminIds.push(doc.id); // El doc.id representa el UID del usuario admin
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
/// get user //

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
// exports.onContractUpdate = onDocumentUpdated(
//   "contracts/{contractId}",
//   async (event) => {
//     const newData = event.data.after.data();
//     const oldData = event.data.before.data();

//     // MODIFICADO: Uso de ContractStatus.signedPendingReview en lugar de string plano
//     if (
//       newData.status === ContractStatus.signedPendingReview &&
//       oldData.status !== ContractStatus.signedPendingReview
//     ) {
//       await sendPush(
//         newData.ownerId,
//         "📄 Contrato Firmado",
//         `El inquilino firmó el contrato de ${newData.propertyAddress}`,
//       );
//     }
//   },
// );

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

      // Arreglo para acumular los envíos de notificaciones en paralelo
      const pushNotifications = [];

      // =========================================================================
      // 1. NOTIFICAR AL PROPIETARIO
      // =========================================================================
      if (ownerId) {
        pushNotifications.push(
          sendPush(
            ownerId,
            "🏠 Propiedad Registrada",
            `Tu propiedad ubicada en ${address} ha sido creada con éxito y está pendiente de revisión.`,
          ),
        );
      }

      // =========================================================================
      // 2. NOTIFICAR A LOS ADMINISTRADORES
      // =========================================================================
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

      // =========================================================================
      // 3. NOTIFICACIÓN PUSH ULTRA MASIVA A TODOS LOS INQUILINOS (FCM Topic)
      // =========================================================================
      // Enviamos un único mensaje al "Topic". Firebase se encarga de repartirlo
      // de forma masiva a todos los dispositivos suscritos al instante.
      const topicMessage = {
        notification: {
          title: "✨ ¡Nueva Propiedad Disponible!",
          body: `Se ha publicado una nueva oportunidad: ${titleProperty} en ${address}. ¡Mírala antes de que se arriende!`,
        },
        topic: "nuevos_inmuebles",
      };

      // Almacenamos la promesa encapsulando su propio log de éxito
      const topicPushPromise = admin
        .messaging()
        .send(topicMessage)
        .then((response) => {
          // Si entra aquí, Google da fe de que el Topic recibió la orden de dispersión
          console.log(
            `🚀 [FCM TOPIC] Mensaje masivo enviado con éxito. ID de tracking: ${response}`,
          );
          return response;
        })
        .catch((error) => {
          console.error(`🚨 [FCM TOPIC ERROR] El envío al Topic falló:`, error);
          throw error; // Lanzamos el error para que el try-catch principal lo registre
        });

      pushNotifications.push(topicPushPromise);
      // Despachamos todos los envíos Push concurrentemente
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
    // Verificamos que existan datos tanto anteriores como nuevos
    if (!event.data || !event.data.after || !event.data.before) {
      console.log("Faltan datos del evento para procesar la actualización.");
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      // MODIFICADO: Uso de PropertyStatusEnum para evaluar los cambios de estado de forma segura
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
    // Verificamos que existan datos
    if (!event.data || !event.data.after || !event.data.before) {
      console.log(
        "Faltan datos del evento para procesar la actualización de pago.",
      );
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      // Condición estricta: El estado cambia de "approvedPendingPayment" a "paidPendingReview"
      if (
        newData.status === PropertyStatusEnum.paidPendingReview &&
        oldData.status === PropertyStatusEnum.approvedPendingPayment
      ) {
        const ownerId = newData.ownerId;
        const address = newData.address || "Tu propiedad";

        console.log(
          `Pago recibido para la propiedad ${event.params.propertyId}. Procesando notificaciones...`,
        );

        // Array para guardar todas las promesas y ejecutarlas en paralelo
        const notifications = [];

        // 1. Notificación de éxito al Propietario (quien envió el pago)
        if (ownerId) {
          notifications.push(
            sendPush(
              ownerId,
              "💰 ¡Pago Exitoso!",
              `El pago para activar tu propiedad en ${address} ha sido procesado. Un administrador verificará el soporte pronto.`,
            ),
          );
        }

        // 2. Notificación a los Administradores para que revisen el pago
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

        // Ejecutar todos los envíos (Push + Email) al mismo tiempo de forma eficiente
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

// --- EVENTO 3: PROPIEDAD PAGADA (NOTIFICAR A PROPIETARIO Y ADMINS) ---

exports.onPropertyPaidReview = onDocumentUpdated(
  "properties/{propertyId}",
  async (event) => {
    // Verificamos que existan datos
    if (!event.data || !event.data.after || !event.data.before) {
      console.log(
        "Faltan datos del evento para procesar la actualización de pago.",
      );
      return;
    }

    const newData = event.data.after.data();
    const oldData = event.data.before.data();

    try {
      // Condición estricta: El estado cambia de "approvedPendingPayment" a "paidPendingReview"
      if (
        newData.status === PropertyStatusEnum.paidPendingReview &&
        oldData.status === PropertyStatusEnum.approvedPendingPayment
      ) {
        const ownerId = newData.ownerId;
        const address = newData.address || "Tu propiedad";

        console.log(
          `Pago recibido para la propiedad ${event.params.propertyId}. Procesando notificaciones...`,
        );

        // Array para guardar todas las promesas y ejecutarlas en paralelo
        const notifications = [];

        // 1. Notificación de éxito al Propietario (quien envió el pago)
        if (ownerId) {
          notifications.push(
            sendPush(
              ownerId,
              "💰 ¡Pago Exitoso!",
              `El pago para activar tu propiedad en ${address} ha sido procesado. Un administrador verificará el soporte pronto.`,
            ),
          );
        }

        // 2. Notificación a los Administradores para que revisen el pago
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

        // Ejecutar todos los envíos (Push + Email) al mismo tiempo de forma eficiente
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
      // ==========================================
      // CAMINO A: EL PAGO FUE APROBADO por el Admin
      // De: paidPendingReview ➔ waitingContract (status)
      // El paymentStatus cambia a "approved" (string)
      // ==========================================
      if (
        newData.status === PropertyStatusEnum.waitingContract &&
        oldData.status === PropertyStatusEnum.paidPendingReview &&
        newData.paymentStatus === PaymentStatusEnum.approved && // Validado como string
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
        return; // Terminamos la ejecución si entró en este camino
      }

      // ==========================================
      // CAMINO B: EL PAGO FUE RECHAZADO por el Admin
      // Regresa a: approvedPendingPayment (status)
      // El paymentStatus cambia a "rejected" (string)
      // ==========================================
      if (
        newData.status === PropertyStatusEnum.approvedPendingPayment &&
        oldData.status === PropertyStatusEnum.paidPendingReview &&
        newData.paymentStatus === PaymentStatusEnum.rejected && // Validado como string
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
      // 1. Mapeo exacto de variables según tu captura de pantalla
      const tenantId = appointmentData.tenantId;
      const tenantName = appointmentData.tenantName || "Usuario";
      const address =
        appointmentData.propertyAddress || "la propiedad seleccionada";

      // Convertimos el Timestamp de Firestore a un formato de texto legible para el Push/Email
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

      // 2. Notificación push de confirmación al Arrendatario (Tenant)
      if (tenantId) {
        notifications.push(
          sendPush(
            tenantId,
            "🗓️ Cita Agendada",
            `Hola ${tenantName}, tu espacio ha sido reservado con éxito para visitar la propiedad en ${address} el día: ${dateText}.`,
          ),
        );
      }

      // 3. Obtener los IDs de los administradores y avisarles del nuevo agendamiento
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

      // 4. Ejecutar todas las llamadas asíncronas en paralelo
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

      // Validamos si la lista de candidatos creció (se agregó alguien nuevo)
      if (newCandidates.length > oldCandidates.length) {
        // 1. Extraemos de forma atómica el ÚLTIMO candidato agregado a la lista
        const newestCandidate = newCandidates[newCandidates.length - 1];

        if (!newestCandidate) return;

        // Mapeo de datos según la imagen de tu base de datos
        const tenantId = newestCandidate.uid;
        const tenantName = newestCandidate.nombre || "Usuario";
        const propertyAddress = newData.address || "la propiedad seleccionada";

        console.log(
          `Nuevo postulante detectado (${tenantName}) en la aplicación: ${event.params.applicationId}`,
        );

        const notifications = [];

        // 2. Notificación push al inquilino confirmando que se postuló con éxito
        if (tenantId) {
          notifications.push(
            sendPush(
              tenantId,
              "📋 Postulación Recibida",
              `Hola ${tenantName}, te has postulado exitosamente para el inmueble en ${propertyAddress}. Tu perfil entró en estado de revisión.`,
            ),
          );
        }

        // 3. Notificación a los Administradores alertando de la nueva postulación
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

        // 4. Disparar todos los envíos en paralelo
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

      // Aseguramos que ambas listas tengan la misma cantidad de elementos para poder comparar uno a uno
      if (newCandidates.length !== oldCandidates.length) return;

      let approvedCandidate = null;
      let singleRejectedCandidate = null;

      // 1. Identificar qué cambió revisando posición por posición
      for (let i = 0; i < newCandidates.length; i++) {
        const current = newCandidates[i];
        const previous = oldCandidates[i];

        // Detectar si alguien pasó de pending_review a approved
        if (
          current.status === "approved" &&
          previous.status === "pending_review"
        ) {
          approvedCandidate = current;
          break; // Si hay una aprobación, el flujo cambia para todos, salimos del ciclo
        }

        // Detectar si alguien pasó de pending_review a rejected
        if (
          current.status === "rejected" &&
          previous.status === "pending_review"
        ) {
          singleRejectedCandidate = current;
        }
      }

      const notifications = [];

      // ==========================================
      // CASO 1: SE APROBÓ A ALGUIEN (Notificación cruzada)
      // ==========================================
      if (approvedCandidate) {
        console.log(
          `Candidato APROBADO detectado: ${approvedCandidate.uid}. Procesando notificación masiva...`,
        );

        newCandidates.forEach((candidate) => {
          if (candidate.uid === approvedCandidate.uid) {
            // Notificación al ganador del cupo
            notifications.push(
              sendPush(
                candidate.uid,
                "🎉 ¡Postulación Aprobada!",
                `Felicitaciones ${candidate.nombre}, tu perfil ha sido seleccionado y aprobado para el inmueble en ${propertyAddress}. El abogado iniciará el borrador del contrato.`,
              ),
            );
          } else {
            // Notificación de descarte a todos los demás participantes
            notifications.push(
              sendPush(
                candidate.uid,
                "📋 Proceso de Postulación Cerrado",
                `Hola ${candidate.nombre}, te informamos que la propiedad en ${propertyAddress} ya ha sido asignada a otro postulante. ¡Agradecemos tu interés!`,
              ),
            );
          }
        });
      }
      // ==========================================
      // CASO 2: SÓLO SE RECHAZÓ A UNA PERSONA INDIVIDUAL
      // ==========================================
      else if (singleRejectedCandidate) {
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

      // 2. Despachar todas las notificaciones push en paralelo si se generó alguna
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

    // Mapeo de datos del documento de contrato
    const ownerId = newData.ownerId;
    const tenantId = newData.tenantId;
    const propertyAddress =
      newData.propertyAddress || "el inmueble seleccionado";

    try {
      const notifications = [];

      // =========================================================================
      // CASO 1: EL ABOGADO SUBIÓ EL BORRADOR (baseContractPdfUrl pasa de null a URL)
      // Notificación exclusiva: Al Inquilino (Tenant) para que firme
      // =========================================================================
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

      // =========================================================================
      // CASO 2: EL INQUILINO FIRMÓ EL DOCUMENTO (ownerSignedPdfUrl pasa de null a URL)
      // Notificaciones: Al Propietario (Landlord) para que firme y a los Administradores (Admin/Abogado)
      // =========================================================================
      if (newData.ownerSignedPdfUrl && !oldData.ownerSignedPdfUrl) {
        console.log(
          `El inquilino firmó el contrato ${event.params.contractId}. Notificando a propietario y admins...`,
        );

        // Notificación al propietario para que proceda a firmar su parte
        if (ownerId) {
          notifications.push(
            sendPush(
              ownerId,
              "✍️ Contrato Pendiente de tu Firma",
              `El inquilino ya ha firmado el contrato de arrendamiento para ${propertyAddress}. Es tu turno de ingresar y firmar el documento.`,
            ),
          );
        }

        // Notificación a la mesa de administración / abogados
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

      // =========================================================================
      // CASO 3: EL INQUILINO FIRMÓ EL DOCUMENTO (tenantSignedPdfUrl pasa de null a URL)
      // Notificaciones: Al Propietario (Landlord) y a los Administradores (Abogados)
      // =========================================================================
      if (newData.tenantSignedPdfUrl && !oldData.tenantSignedPdfUrl) {
        console.log(
          `El inquilino firmó el contrato ${event.params.contractId}. Notificando a propietario y admins...`,
        );

        // Notificación al propietario avisando que el proceso de firmas del inquilino terminó
        if (ownerId) {
          notifications.push(
            sendPush(
              ownerId,
              "📄 Inquilino Firmó el Contrato",
              `El arrendatario ha completado la firma digital del contrato para ${propertyAddress}. El proceso pasa a revisión final.`,
            ),
          );
        }

        // Notificación al abogado/admin para que valide las firmas finales y legalice el documento
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

      // Despachar concurrentemente todas las promesas recolectadas según el caso que se haya activado
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
      // Condición estricta: El estado cambia de "signedPendingReview" a "active"
      if (
        newData.status === ContractStatus.active &&
        oldData.status === ContractStatus.signedPendingReview
      ) {
        const ownerId = newData.ownerId;
        const tenantId = newData.tenant?.uid;
        const propertyAddress =
          newData.propertyAddress || "el inmueble seleccionado";

        // REGLA: El PDF final definitivo que reciben las 3 partes
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

        // 1. Consultar datos de Propietario e Inquilino en paralelo desde la colección 'users'
        const [ownerContact, tenantContact] = await Promise.all([
          getUserContactData(ownerId),
          getUserContactData(tenantId),
        ]);

        const notifications = [];
        const subjectGeneral = `🏠 Contrato Legalizado - ${propertyAddress}`;

        // =========================================================================
        // A. ENVÍO AL PROPIETARIO (LANDLORD)
        // =========================================================================
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

        // =========================================================================
        // B. ENVÍO AL INQUILINO (TENANT)
        // =========================================================================
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

        // =========================================================================
        // C. ENVÍO AL ABOGADO / ÁREA LEGAL
        // =========================================================================
        // OPCIÓN 1: Si el abogado es un correo institucional fijo en la empresa
        const lawyerEmail = "davidbarrera@humanbionics.com.co"; // <--- Cambia por el correo real de tu abogado
        const lawyerName = "Área Jurídica Armando Marín";

        // OPCIÓN 2: Si el ID del abogado viene dentro del contrato (ej: newData.lawyerId),
        // puedes descomentar las líneas de abajo y usar getUserContactData(newData.lawyerId)

        const contentLawyer = `Se ha formalizado y activado con éxito el contrato de arrendamiento correspondiente al inmueble en ${propertyAddress}. Inquilino: ${tenantNameEmbed}. Adjuntamos el documento firmado mediante la plataforma para el archivo del historial jurídico de la inmobiliaria.`;

        if (lawyerEmail) {
          notifications.push(
            sendEmailWithPdfAttachment(
              lawyerEmail,
              lawyerName,
              `⚖️ [Archivo Jurídico] Contrato Activado - ${propertyAddress}`,
              contentLawyer,
              finalContractPdf, // Recibe exactamente el mismo archivo adjunto
            ),
          );
        }

        // =========================================================================
        // DESPACHO CONCURRENTE TOTAL
        // =========================================================================
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
    const userId = event.params.userId; // El usuario que RECIBE la calificación
    const reviewData = snapshot.data();

    try {
      console.log(
        `Nueva calificación detectada para el usuario: ${userId}. Calculando promedio...`,
      );

      // 1. Obtener todas las reseñas actuales para la matemática del promedio
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

      // 2. Actualizar el perfil raíz con la reputación consolidada
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

      // =========================================================================
      // --- NUEVO: DISPARAR NOTIFICACIÓN PUSH CRUZADA AL USUARIO CALIFICADO ---
      // =========================================================================
      const fromName = reviewData.fromName || "Un usuario";
      const fromRole =
        reviewData.fromRole === "landlord" ? "propietario" : "inquilino";
      const ratingStars = reviewData.rating || 5;

      // Estrellas visuales para el cuerpo de la notificación
      const starsVisual = "⭐".repeat(ratingStars);

      const titlePush = "📝 ¡Te han calificado!";
      const bodyPush = `${fromName} (${fromRole}) te ha dejado una calificación de ${starsVisual}. Recuerda calificarlo tú también para cerrar el ciclo legal del contrato.`;

      console.log(`Enviando notificación push de reseña a usuario: ${userId}`);

      // Llamada segura a tu helper global de mensajería asíncrona
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

// --- FUNCIÓN PARA ENVIAR EMAIL ---
async function sendEmail(
  userEmail,
  userName,
  subject,
  content,
  templateId = 8020915,
) {
  try {
    const request = await mailjet.post("send", { version: "v3.1" }).request({
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

/**
 * Envía un correo electrónico utilizando una plantilla de Mailjet e incluyendo un PDF adjunto.
 * @param {string} userEmail - Correo del destinatario
 * @param {string} userName - Nombre del destinatario
 * @param {string} subject - Asunto del correo
 * @param {string} content - Contenido del mensaje
 * @param {string} pdfUrl - URL pública de Firebase Storage donde está el PDF
 * @param {number} templateId - ID de la plantilla de Mailjet
 */
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

    // Si nos pasan una URL válida de PDF, la descargamos y la convertimos a Base64
    if (pdfUrl && pdfUrl.trim() !== "") {
      console.log(`Descargando PDF para adjuntar desde: ${pdfUrl}`);

      // Descargamos el archivo como un buffer de bytes
      const response = await axios.get(pdfUrl, { responseType: "arraybuffer" });
      const base64Pdf = Buffer.from(response.data, "binary").toString("base64");

      // Creamos la estructura de adjuntos estructurada por Mailjet
      attachmentsBlock = [
        {
          ContentType: "application/pdf",
          Filename: "Contrato_Arrendamiento_Firmado.pdf",
          Base64Content: base64Pdf,
        },
      ];
    }

    // Despachamos el esquema a la API de Mailjet
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
          // Inyectamos el archivo si se procesó correctamente, de lo contrario irá vacío
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
// --- FUNCIÓN PARA ENVIAR PUSH ---
/**
 * Envía una notificación Push a un usuario específico y registra el historial
 * dentro de una subcolección en su perfil de Firestore.
 * * @param {string} userId - El UID del usuario en la colección 'users'
 * @param {string} title - Título de la notificación
 * @param {string} body - Contenido del mensaje
 * @param {string} type - Tipo de notificación (ej: 'property_created', 'contract_active')
 */
async function sendPush(userId, title, body, type = "general") {
  const db = admin.firestore();

  try {
    // 1. Obtener los datos del usuario para verificar el Token FCM
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const token = userData?.fcmToken;

    // 2. CREAR E INYECTAR EL HISTORIAL EN LA SUBCOLECCIÓN
    // Al usar .collection().add(), Firestore genera un ID automático para la notificación
    await db.collection("users").doc(userId).collection("notifications").add({
      title: title,
      body: body,
      type: type,
      isRead: false, // Por defecto entra como no leída
      createdAt: admin.firestore.FieldValue.serverTimestamp(), // Hora exacta del servidor de Google
    });

    console.log(
      `[Historial] Notificación guardada en la base de datos para el usuario: ${userId}`,
    );

    // 3. ENVIAR EL PUSH FÍSICO AL DISPOSITIVO (Solo si el token existe)
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
