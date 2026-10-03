/**
 * firestore.rules ve storage.rules testleri — emülatörde, sahte bir projeyle
 * ("demo-" önekli projeler hiçbir zaman gerçek Firebase'e gitmez).
 *
 *   cd functions && npm run rules
 *
 * Sorgular uygulamadakilerle birebir aynı kuruldu: kurallar filtre olmadığı
 * için asıl soru "bu ekranın sorgusu geçiyor mu?".
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import { getMetadata, ref, uploadBytes } from "firebase/storage";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

/** lib/models/incident_model.dart → publicIncidentStatuses */
const PUBLIC_STATUSES = ["Açık", "Acik", "Çözüldü", "Cozuldu"];

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-smart-campus",
    firestore: { rules: readFileSync(resolve("..", "firestore.rules"), "utf8") },
    storage: { rules: readFileSync(resolve("..", "storage.rules"), "utf8") },
  });
});

afterAll(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();

  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users/admin"), { uid: "admin", role: "admin", name: "Yönetici", followedIncidents: [] });
    await setDoc(doc(db, "users/alice"), { uid: "alice", role: "user", name: "Alice", email: "alice@example.com", followedIncidents: [] });
    await setDoc(doc(db, "users/bob"), { uid: "bob", role: "user", name: "Bob", email: "bob@example.com", followedIncidents: [] });

    const incident = {
      description: "Açıklama",
      type: "Teknik",
      latitude: 39.9,
      longitude: 41.24,
      imageUrl: null,
      createdAt: Timestamp.now(),
      userId: "bob",
    };
    await setDoc(doc(db, "incidents/open"), { ...incident, title: "Kırık lamba", status: "Açık" });
    await setDoc(doc(db, "incidents/solved"), { ...incident, title: "Su sızıntısı", status: "Çözüldü" });
    await setDoc(doc(db, "incidents/review"), { ...incident, title: "Şüpheli paket", status: "İnceleniyor" });
  });
});

const db = (uid: string) => env.authenticatedContext(uid).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();

/** create_incident_screen.dart'ın yazdığı belge. */
function newIncident(userId: string, overrides: Record<string, unknown> = {}) {
  return {
    title: "Yeni bildirim",
    description: "Koridordaki lamba yanmıyor",
    type: "Genel",
    status: "İnceleniyor",
    latitude: 39.9,
    longitude: 41.24,
    imageUrl: null,
    createdAt: serverTimestamp(),
    userId,
    ...overrides,
  };
}

describe("olaylar — okuma", () => {
  it("herkese açık bir olayı giriş yapmış herkes okur", async () => {
    await assertSucceeds(getDoc(doc(db("alice"), "incidents/open")));
  });

  it("onay bekleyen bir olayı başkası okuyamaz", async () => {
    await assertFails(getDoc(doc(db("alice"), "incidents/review")));
  });

  it("onay bekleyen olayı bildiren kişi okur", async () => {
    await assertSucceeds(getDoc(doc(db("bob"), "incidents/review")));
  });

  it("admin onay bekleyen olayı okur", async () => {
    await assertSucceeds(getDoc(doc(db("admin"), "incidents/review")));
  });

  it("giriş yapmamış biri hiçbir olayı okuyamaz", async () => {
    await assertFails(getDoc(doc(anonymous(), "incidents/open")));
  });

  it("ana sayfa sorgusu (durum süzgeci + tarih sırası) geçer ve onay bekleyeni getirmez", async () => {
    const snapshot = await assertSucceeds(
      getDocs(query(collection(db("alice"), "incidents"), where("status", "in", PUBLIC_STATUSES), orderBy("createdAt", "desc"))),
    );
    expect(snapshot.docs.map((d) => d.id).sort()).toEqual(["open", "solved"]);
  });

  it("harita ve profil sorgusu (yalnız durum süzgeci) geçer", async () => {
    await assertSucceeds(getDocs(query(collection(db("alice"), "incidents"), where("status", "in", PUBLIC_STATUSES))));
  });

  it("süzgeçsiz sorgu reddedilir — eski uygulama sürümü onay bekleyenleri artık indiremez", async () => {
    await assertFails(getDocs(collection(db("alice"), "incidents")));
  });

  it("admin panelinin süzgeçsiz sorgusu geçer", async () => {
    const snapshot = await assertSucceeds(getDocs(query(collection(db("admin"), "incidents"), orderBy("createdAt", "desc"))));
    expect(snapshot.size).toBe(3);
  });
});

describe("olaylar — yazma", () => {
  it("kullanıcı kendi adına 'İnceleniyor' bildirimi açar", async () => {
    await assertSucceeds(addDoc(collection(db("alice"), "incidents"), newIncident("alice")));
  });

  it("fotoğraflı bildirim de açılır", async () => {
    await assertSucceeds(
      addDoc(collection(db("alice"), "incidents"), newIncident("alice", { imageUrl: "https://example.com/a.jpg" })),
    );
  });

  it("bildirim doğrudan 'Açık' olarak açılamaz — onayı atlayamaz", async () => {
    await assertFails(addDoc(collection(db("alice"), "incidents"), newIncident("alice", { status: "Açık" })));
  });

  it("başkası adına bildirim açılamaz", async () => {
    await assertFails(addDoc(collection(db("alice"), "incidents"), newIncident("bob")));
  });

  it("fazladan alan ve bilinmeyen tür reddedilir", async () => {
    await assertFails(addDoc(collection(db("alice"), "incidents"), newIncident("alice", { priority: "high" })));
    await assertFails(addDoc(collection(db("alice"), "incidents"), newIncident("alice", { type: "Diğer" })));
  });

  it("giriş yapmamış biri bildirim açamaz", async () => {
    await assertFails(addDoc(collection(anonymous(), "incidents"), newIncident("alice")));
  });

  it("kullanıcı durumu değiştiremez, açıklamayı düzenleyemez, silemez", async () => {
    await assertFails(updateDoc(doc(db("bob"), "incidents/open"), { status: "Çözüldü" }));
    await assertFails(updateDoc(doc(db("bob"), "incidents/open"), { description: "Düzeltildi" }));
    await assertFails(deleteDoc(doc(db("bob"), "incidents/open")));
  });

  it("admin durumu değiştirir, açıklamayı düzenler ve siler", async () => {
    await assertSucceeds(updateDoc(doc(db("admin"), "incidents/review"), { status: "Açık" }));
    await assertSucceeds(updateDoc(doc(db("admin"), "incidents/open"), { description: "Düzeltildi" }));
    await assertSucceeds(deleteDoc(doc(db("admin"), "incidents/solved")));
  });
});

describe("kullanıcılar", () => {
  it("kullanıcı takip listesini ve bildirim ayarlarını günceller", async () => {
    await assertSucceeds(
      updateDoc(doc(db("alice"), "users/alice"), {
        followedIncidents: arrayUnion("open"),
        notificationSettings: { genel: false, kayip: true },
      }),
    );
  });

  it("kullanıcı kendini admin yapamaz", async () => {
    await assertFails(updateDoc(doc(db("alice"), "users/alice"), { role: "admin" }));
  });

  it("kayıtta yalnızca 'user' rolü alınır", async () => {
    await assertFails(setDoc(doc(db("carol"), "users/carol"), { uid: "carol", role: "admin", followedIncidents: [] }));
    await assertSucceeds(setDoc(doc(db("carol"), "users/carol"), { uid: "carol", role: "user", followedIncidents: [] }));
  });

  it("başkasının kaydı okunamaz ve değiştirilemez", async () => {
    await assertFails(getDoc(doc(db("alice"), "users/bob")));
    await assertFails(updateDoc(doc(db("alice"), "users/bob"), { followedIncidents: [] }));
  });

  it("admin bir kullanıcıyı admin yapabilir", async () => {
    await assertSucceeds(updateDoc(doc(db("admin"), "users/alice"), { role: "admin" }));
  });
});

describe("duyurular", () => {
  const announcement = (createdBy: string) => ({
    title: "Yangın tatbikatı",
    body: "Bugün saat 14.00'te.",
    createdBy,
    createdAt: serverTimestamp(),
  });

  it("admin duyuru yazar", async () => {
    await assertSucceeds(addDoc(collection(db("admin"), "announcements"), announcement("admin")));
  });

  it("kullanıcı duyuru yazamaz", async () => {
    await assertFails(addDoc(collection(db("alice"), "announcements"), announcement("alice")));
  });

  it("admin başkası adına duyuru yazamaz", async () => {
    await assertFails(addDoc(collection(db("admin"), "announcements"), announcement("alice")));
  });

  it("yazılmış bir duyuru değiştirilemez", async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "announcements/a1"), { title: "A", body: "B", createdBy: "admin" });
    });
    await assertFails(updateDoc(doc(db("admin"), "announcements/a1"), { body: "Değişti" }));
  });
});

describe("depolama — bildirim fotoğrafları", () => {
  const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
  const storage = (uid?: string) =>
    uid === undefined ? env.unauthenticatedContext().storage() : env.authenticatedContext(uid).storage();

  it("giriş yapmış kullanıcı görsel yükler", async () => {
    await assertSucceeds(uploadBytes(ref(storage("alice"), "incident_images/1.jpg"), jpeg, { contentType: "image/jpeg" }));
  });

  it("giriş yapmamış biri yükleyemez", async () => {
    await assertFails(uploadBytes(ref(storage(), "incident_images/2.jpg"), jpeg, { contentType: "image/jpeg" }));
  });

  it("görsel olmayan ya da 10 MB'tan büyük dosya reddedilir", async () => {
    await assertFails(uploadBytes(ref(storage("alice"), "incident_images/3.jpg"), jpeg, { contentType: "text/plain" }));
    const big = new Uint8Array(10 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(storage("alice"), "incident_images/4.jpg"), big, { contentType: "image/jpeg" }));
  });

  it("var olan bir fotoğrafın üstüne yazılamaz", async () => {
    await assertSucceeds(uploadBytes(ref(storage("alice"), "incident_images/5.jpg"), jpeg, { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(storage("bob"), "incident_images/5.jpg"), jpeg, { contentType: "image/jpeg" }));
  });

  it("fotoğrafı giriş yapmış herkes okur, giriş yapmamış okuyamaz", async () => {
    await assertSucceeds(uploadBytes(ref(storage("alice"), "incident_images/6.jpg"), jpeg, { contentType: "image/jpeg" }));
    await assertSucceeds(getMetadata(ref(storage("bob"), "incident_images/6.jpg")));
    await assertFails(getMetadata(ref(storage(), "incident_images/6.jpg")));
  });

  it("başka bir klasöre hiçbir şey yazılamaz", async () => {
    await assertFails(uploadBytes(ref(storage("alice"), "profiles/alice.jpg"), jpeg, { contentType: "image/jpeg" }));
  });
});
