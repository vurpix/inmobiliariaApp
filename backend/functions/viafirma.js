// viafirma_service.js
const axios = require("axios");
require("dotenv").config();

const VIAFIRMA_BASE_URL = "https://sandbox.viafirma.com/documents";
const VIAFIRMA_GROUP_CODE = "demo_humanbionics";

/**
 * Obtiene de manera privada las credenciales desde las variables de entorno
 * @returns {{username: String, password: String}}
 */
function getViafirmaAuth() {
  // En producción lee las llaves directas; en local lee las del .env con sufijo _LOCAL
  const username = process.env.VIAFIRMA_USER || process.env.VIAFIRMA_USER_LOCAL;
  const password =
    process.env.VIAFIRMA_API_KEY || process.env.VIAFIRMA_API_KEY_LOCAL;

  return { username, password };
}

/**
 * Crea un flujo de firmas digital (Signature Set) para un contrato en la API v3 de Viafirma
 */

// Tiempo disponible para firmar el SET.
// Cambia este número cuando quieras: 1, 3, 7, 15, 30, etc.
const VIAFIRMA_SIGNATURE_EXPIRATION_DAYS = 1;

function getViafirmaExpirationTimestamp(
  days = VIAFIRMA_SIGNATURE_EXPIRATION_DAYS,
) {
  return Date.now() + 1000 * 60 * 60 * 24 * days;
}

async function createSignatureSet({
  title,
  description,
  userCode,
  tenantEmail,
  tenantName,
  ownerEmail,
  ownerName,
  pdfUrl,

  // Opcional: si algún día quieres mandar otro valor desde el backend.
  expirationDays = VIAFIRMA_SIGNATURE_EXPIRATION_DAYS,
}) {
  console.log(
    `🛰️ [VIAFIRMA SERVICE] Preparando payload para el contrato: "${title}"`,
  );

  const authData = getViafirmaAuth();
  if (!authData.username || !authData.password) {
    throw new Error(
      "❌ Error de configuración: VIAFIRMA_USER o VIAFIRMA_API_KEY no están definidos en el archivo .env",
    );
  }

  const expires = getViafirmaExpirationTimestamp(expirationDays);

  console.log(
    `⏰ [VIAFIRMA SERVICE] Tiempo para firmar: ${expirationDays} días | expires: ${expires}`,
  );

  const body = {
    groupCode: VIAFIRMA_GROUP_CODE,
    title,
    description,
    userCode,
    expires,

    notification: {
      text: `${title}.pdf`,
      detail: `${title}.pdf`,
    },
    recipients: [
      {
        key: "firmante_1",
        mail: tenantEmail,
        name: tenantName,
        notificationType: "MAIL",
        order: 1,
        presential: true,
        callbackType: "NONE",
      },
      {
        key: "firmante_2",
        mail: ownerEmail,
        name: ownerName,
        notificationType: "MAIL",
        order: 2,
        presential: true,
        callbackType: "NONE",
      },
    ],
    messages: [
      {
        document: {
          templateType: "url",
          templateReference: pdfUrl,
          filename: `${title}.pdf`,
          watermarkText: "Entorno de prueba",
        },
        policies: [
          {
            evidences: [
              {
                type: "SIGNATURE",
                enabled: true,
                visible: true,
                helpText: `Firma de ${tenantName}`,
                positions: [
                  {
                    rectangle: {
                      x: 120,
                      y: 156,
                      width: 125,
                      height: 62,
                    },
                    page: 1,
                  },
                ],
                recipientKey: "firmante_1",
              },
              {
                type: "SIGNATURE",
                enabled: true,
                visible: true,
                helpText: `Firma de ${ownerName}`,
                positions: [
                  {
                    rectangle: {
                      x: 108,
                      y: 23,
                      width: 125,
                      height: 62,
                    },
                    page: 1,
                  },
                ],
                recipientKey: "firmante_2",
              },
            ],
            signatures: [
              {
                type: "SERVER",
                helpText: "Sello del documento",
                stampers: [
                  {
                    type: "DEFAULT",
                    rotation: "ROTATE_90",
                    width: 34,
                    height: 792,
                    xAxis: 0,
                    yAxis: 0,
                    page: 1,
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  };

  try {
    console.log(
      "🚀 [VIAFIRMA SERVICE] Enviando solicitud POST asíncrona a Viafirma...",
    );

    const response = await axios.post(`${VIAFIRMA_BASE_URL}/api/v3/set`, body, {
      auth: authData,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    });

    console.log(
      "✅ [VIAFIRMA SERVICE] Conjunto de firmas enviado de manera exitosa.",
    );

    return response.data;
  } catch (error) {
    console.error(
      "💥 [VIAFIRMA SERVICE] Error fatal al crear el Signature Set:",
      {
        status: error.response?.status,
        errorData: error.response?.data || error.message,
      },
    );
    throw error;
  }
}

/**
 * Consulta el estado resumido actual de un flujo de firmas mediante su código único (setCode)
 */
async function getSetSummary(setCode) {
  if (!setCode) {
    throw new Error(
      "❌ Se requiere un 'setCode' válido para consultar el resumen en Viafirma.",
    );
  }

  const authData = getViafirmaAuth();

  try {
    console.log(
      `🔍 [VIAFIRMA SERVICE] Consultando estado del setCode: ${setCode}`,
    );
    const response = await axios.get(
      `${VIAFIRMA_BASE_URL}/api/v3/set/summary/${setCode}`,
      {
        auth: authData,
        headers: {
          Accept: "application/json",
        },
      },
    );

    return response.data;
  } catch (error) {
    console.error(
      `💥 [VIAFIRMA SERVICE] Error al consultar el resumen del set ${setCode}:`,
      {
        status: error.response?.status,
        errorData: error.response?.data || error.message,
      },
    );
    throw error;
  }
}

async function getSetStatus(setCode) {
  const response = await axios.get(
    `${VIAFIRMA_BASE_URL}/api/v3/set/status/${setCode}`,
    {
      auth: getViafirmaAuth(),
      headers: {
        Accept: "application/json",
      },
    },
  );

  return response.data;
}

module.exports = {
  createSignatureSet,
  getSetSummary,
  getSetStatus,
};
