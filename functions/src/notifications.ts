import type { Message } from "firebase-admin/messaging";

/**
 * Bildirim mesajlarını kuran saf fonksiyonlar. Firebase'e dokunmadıkları için
 * emülatör olmadan test edilebiliyorlar (notifications.test.ts).
 */

type IncidentData = { title?: unknown; status?: unknown };
type AnnouncementData = { title?: unknown; body?: unknown };

/** FCM'in Flutter tarafındaki varsayılan tıklama davranışı için. */
const CLICK_ACTION = "FLUTTER_NOTIFICATION_CLICK";

/**
 * Bir olayın durumu değiştiğinde o olayı takip edenlere gidecek mesaj.
 *
 * Durum değişmediyse null döner: açıklama düzenlemek ya da aynı durumu
 * yeniden kaydetmek takipçilere bildirim göndermez.
 */
export function statusChangeMessage(
  incidentId: string,
  before: IncidentData,
  after: IncidentData,
): Message | null {
  if (typeof after.status !== "string" || before.status === after.status) return null;

  const title = typeof after.title === "string" && after.title.trim() !== "" ? after.title.trim() : "Bildirim";

  return {
    topic: `incident_${incidentId}`,
    notification: {
      title: "Durum Güncellemesi",
      body: `'${title}' olayının durumu '${after.status}' olarak değiştirildi.`,
    },
    data: { click_action: CLICK_ACTION, incidentId, status: after.status },
  };
}

/**
 * Bir adminin yazdığı duyurunun 'all' konusuna abone herkese gidecek hali.
 * Başlığı ya da metni boş bir kayıt için null döner.
 */
export function announcementMessage(data: AnnouncementData): Message | null {
  const title = typeof data.title === "string" ? data.title.trim() : "";
  const body = typeof data.body === "string" ? data.body.trim() : "";
  if (title === "" || body === "") return null;

  return {
    topic: "all",
    notification: { title, body },
    data: { click_action: CLICK_ACTION, type: "announcement" },
  };
}
