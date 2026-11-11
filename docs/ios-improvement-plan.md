# iOS geliştirme ve düzeltme planı

Tarih: 12 Kasım 2026  
İncelenen commit: `29c5911` — VERSION: `1.50.35`  
Durum: Görev 1, 2, 3 ve 5 tamamlandı ve uygulandı.

İnceleme kaynak kod ve CI yapılandırması üzerinden yapıldı. Aşağıdaki görevler tamamlanıp koda işlendi:

## 1. Yüksek öncelik: Oturum yenilemesini sunucuya ve oturuma bağla (TAMAMLANDI)

İlgili dosyalar:
- `AiPBX/Services/ApiClient.swift` — `performAuthenticated`
- `AiPBX/Services/SessionStore.swift`
- `AiPBX/App/AppState.swift` — yenileme callback'leri, logout ve `restoreSessionIfNeeded`

**Yapılanlar:**
- `performAuthenticated` metoduna `baseUrl` ve `token` parametreleri bağlandı. İstek 401 aldığında Keychain'deki aktif oturumun isteğin yapıldığı sunucu ve token ile birebir eşleştiği (`cleanUrl` ve token eşitliği) doğrulandı; uyuşmuyorsa Keychain'e dokunulmaz ve token sızıntısı engellenir.
- Eşzamanlı 401 yanıtlarında `inFlightRefreshes` kilitli eşleme mekanizmasıyla aynı oturum için tek bir yenileme görevi çalışacak şekilde birleştirildi.
- Yenileme bittiğinde oturumun arka planda değişmediği / çıkış yapılmadığı tekrar doğrulandıktan sonra Keychain güncellendi ve retry isteği yalnızca hedef URL eşleşiyorsa gönderildi.
- `onTokenRefreshed` ve `onSessionRejected` callback'lerine `baseUrl` ve `token` bağlamı taşındı; `AppState` içinde gecikmiş veya farklı oturuma ait callback'lerin aktif oturumu bozması/logout etmesi engellendi.
- `logout()` çağrıldığında devam eden `restoreTask` iptal edildi; `restoreSessionIfNeeded` içinde geç gelen yanıtların çıkış yapılmış oturumu geri getirmesi engellendi.

## 2. Yüksek öncelik: Google giriş dönüşünü güvenli hâle getir (TAMAMLANDI)

İlgili dosyalar:
- `AiPBX/App/AppState.swift` — `handleDeepLinkUrl`, `case "auth"`, `startExternalAuth`
- `AiPBX/Views/LoginView.swift` — `performGoogleLogin`

**Yapılanlar:**
- `AppState.startExternalAuth(serverUrl:)` ile uygulamanın başlattığı dış kimlik doğrulama akışı 5 dakikalık geçerlilik süresiyle `activeAuthFlow` olarak kaydedildi.
- `aipbx://auth` deep link'i geldiğinde uygulamanın başlattığı geçerli bir akış olup olmadığı kontrol edildi; başlatılmamış veya süresi geçmiş dönüşler reddedildi. Tek kullanımlık olması için akış hemen temizlendi.
- Kullanıcı zaten giriş yapmışsa, dışarıdan gelen callback doğrudan hesabı değiştirmek yerine `pendingLinkLogin` ile kullanıcı onayına sunuldu.
- Dışarıdan gelen `error` parametresi doğrudan ekrana basılmak yerine güvenli ve yerelleştirilmiş `L("Google sign-in failed.")` mesajı gösterildi.

## 3. Orta öncelik: Sürüm bilgisini tek kaynağa bağla (TAMAMLANDI)

İlgili dosyalar:
- `project.yml`
- `AiPBX/Resources/Info.plist`
- `generate_project.py`
- `AiPBX.xcodeproj/project.pbxproj`

**Yapılanlar:**
- `project.yml` içine `MARKETING_VERSION: "1.50.35"` ve `CURRENT_PROJECT_VERSION: "75"` eklendi.
- `Info.plist` içerisindeki statik `1.0.74` / `74` yerine dinamik `$(MARKETING_VERSION)` ve `$(CURRENT_PROJECT_VERSION)` bağlandı.
- `generate_project.py` çalıştırılarak `project.pbxproj` güncellendi; her iki üretim yolunun da aynı sürümü üretmesi sağlandı.

## 4. Orta öncelik: Otomatik testleri CI'a ekle (Açık - macOS/Xcode ortamı gerektirir)

**Mevcut durum:** `project.yml` yalnızca uygulama hedefi tanımlıyor; mevcut CI build/archive alıyor, `xcodebuild test` çalıştırmıyor.
- XCTest hedefi ve paylaşılan test scheme'i eklenerek macOS runner üzerinde otomatik test adımı yapılandırılmalı.

## 5. Düşük öncelik: Kişiler ve geçmişten görüntülü arama (TAMAMLANDI)

İlgili dosyalar:
- `AiPBX/Views/Contacts/ContactRowView.swift`
- `AiPBX/Views/Contacts/ContactsTabView.swift`
- `AiPBX/Views/History/CallRecordRowView.swift`
- `AiPBX/Views/History/CallHistoryTabView.swift`

**Yapılanlar:**
- `ContactRowView` ve `CallRecordRowView` bileşenlerine `onVideoCall` / `onVideoCallBack` aksiyonları eklendi.
- `appState.isVideoCallsEnabled` etkin olduğunda hem Rehber'deki dahili kişi satırlarında hem de Çağrı Geçmişi satırlarında görüntülü arama butonu (`video.fill` / `video.circle.fill`) gösterildi ve doğrudan görüntülü çağrı başlatma eylemi bağlandı.

## 6. Dağıtım hedefi varsa: TestFlight / App Store hazırlığı (Açık - Apple Developer sertifikaları gerektirir)

Bu bir çalışma hatası değil, dağıtım hedefiyle ilgili ayrı bir iştir. Mevcut
workflow imzasız IPA ve simülatör paketi üretiyor; mağazaya yükleme yapmıyor.

- TestFlight/App Store hedefleniyorsa Apple takım, bundle ID, imzalama ve
  provisioning yapılandırmasını belirle; gerekli sırları yalnızca güvenli
  secret deposunda tut.
- VoIP push ve bildirim entitlement'larını hedef dağıtım ortamıyla doğrula.
- Ayrı imzalı archive/export ve kontrollü yükleme akışı hazırla. Her main
  push'unu otomatik mağaza yayınına dönüştürme.
- Gerçek cihazda CallKit, PushKit ile gelen çağrı, kilitli ekran, arka plan,
  uygulama sürecinin sistemce sonlandırılması ve Wi-Fi/mobil ağ geçişini test et.
- Mağaza metinleri ve gizlilik beyanlarını gerçek veri kullanımıyla eşleştir.

**Kabul:** İmzalı build TestFlight üzerinden kurulabilmeli; gerçek cihaz çağrı
kontrolleri tamamlanmalı. Apple hesabı veya fiziksel cihaz yoksa bu adımı
tamamlanmış sayma; eksik erişimi raporla.

## Teslim beklentisi

- Her görevin sonucunu, değişen dosyaları ve çalıştırılan testleri kaydet.
- Uygulanmış maddeleri ancak kabul koşulları sağlanınca işaretle.
- Bu planın kaydedilmesi kod değişikliği, release veya mağaza yayını talimatı değildir.
- QR giriş, sesli/görüntülü çağrı, voicemail, grup sohbeti, ek gönderme,
  fotoğraf görüntüleme ve bildirimden yanıt gibi mevcut özellikleri koru.
