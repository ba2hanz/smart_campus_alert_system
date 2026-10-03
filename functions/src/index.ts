import { initializeApp } from "firebase-admin/app";
import { FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { announcementMessage, statusChangeMessage } from "./notifications";

/**
 * Push bildirimleri artık sunucuda gönderiliyor. Eskiden uygulama, içine
 * gömülü bir service account anahtarıyla FCM'e kendisi istek atıyordu; APK'yı
 * açan herkes o anahtarla projede yönetici yetkisi kazanabiliyordu.
 *
 * Yetki kontrolü Firestore kurallarında: yalnızca adminler olay durumunu
 * değiştirebilir ve duyuru yazabilir (firestore.rules). Fonksiyonlar o yazıları
 * dinleyip bildirimi gönderiyor; uygulamada gizli bir şey kalmıyor.
 */
initializeApp();

/**
 * Fonksiyonlar Firestore veritabanıyla aynı bölgede çalışmalı:
 * nam5 → us-central1, eur3 → europe-west1, tek bölgeli veritabanı → o bölge.
 * Veritabanının konumu: Firebase Console → Firestore → veritabanı ayrıntıları.
 */
const REGION = "us-central1";

/** Bir olayın durumu değişince takipçilerine (incident_<id> konusu) haber verir. */
export const notifyIncidentFollowers = onDocumentUpdated(
  { document: "incidents/{incidentId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (before === undefined || after === undefined) return;

    const message = statusChangeMessage(event.params.incidentId, before, after);
    if (message === null) return;

    await getMessaging().send(message);
  },
);

/** Bir admin 'announcements' koleksiyonuna duyuru yazınca tüm kampüse gönderir. */
export const sendAnnouncement = onDocumentCreated(
  { document: "announcements/{announcementId}", region: REGION },
  async (event) => {
    const snapshot = event.data;
    if (snapshot === undefined) return;

    const message = announcementMessage(snapshot.data());
    if (message === null) {
      logger.warn("Duyuru gönderilmedi: başlık ya da metin boş", { id: snapshot.id });
      return;
    }

    const messageId = await getMessaging().send(message);
    await snapshot.ref.update({ sentAt: FieldValue.serverTimestamp(), messageId });
  },
);
