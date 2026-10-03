import { describe, expect, it } from "vitest";
import { announcementMessage, statusChangeMessage } from "./notifications";

describe("statusChangeMessage", () => {
  it("durum değişince olayın takipçilerine gider", () => {
    const message = statusChangeMessage(
      "abc123",
      { title: "Kırık lamba", status: "İnceleniyor" },
      { title: "Kırık lamba", status: "Açık" },
    );

    expect(message).toEqual({
      topic: "incident_abc123",
      notification: {
        title: "Durum Güncellemesi",
        body: "'Kırık lamba' olayının durumu 'Açık' olarak değiştirildi.",
      },
      data: { click_action: "FLUTTER_NOTIFICATION_CLICK", incidentId: "abc123", status: "Açık" },
    });
  });

  it("durum aynı kaldıysa bildirim yok — açıklama düzenlemek kimseyi rahatsız etmez", () => {
    expect(
      statusChangeMessage("abc123", { title: "A", status: "Açık" }, { title: "B", status: "Açık" }),
    ).toBeNull();
  });

  it("durumu olmayan bir kayıt için bildirim yok", () => {
    expect(statusChangeMessage("abc123", { status: "Açık" }, { title: "A" })).toBeNull();
  });

  it("başlık yoksa genel bir ad kullanır", () => {
    const message = statusChangeMessage("x", { status: "Açık" }, { title: "  ", status: "Çözüldü" });
    expect(message?.notification?.body).toBe("'Bildirim' olayının durumu 'Çözüldü' olarak değiştirildi.");
  });
});

describe("announcementMessage", () => {
  it("tüm kampüse ('all' konusu) gider, boşlukları kırpar", () => {
    expect(announcementMessage({ title: " Yangın tatbikatı ", body: " Saat 14.00'te. " })).toEqual({
      topic: "all",
      notification: { title: "Yangın tatbikatı", body: "Saat 14.00'te." },
      data: { click_action: "FLUTTER_NOTIFICATION_CLICK", type: "announcement" },
    });
  });

  it("başlık ya da metin boşsa gönderilmez", () => {
    expect(announcementMessage({ title: "Başlık", body: "   " })).toBeNull();
    expect(announcementMessage({ title: "", body: "Metin" })).toBeNull();
    expect(announcementMessage({ title: 42, body: "Metin" })).toBeNull();
  });
});
