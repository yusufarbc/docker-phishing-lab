# PhishBox-Spoofer

Yetkili güvenlik farkındalık testleri için, Gophish + yerel SMTP relay (Postfix) tabanlı, izole Docker mimarisi.

## 1) Teknik Mimari Özeti

Trafik akışı:

`Gophish -> Yerel Postfix Relay -> Hedef Kurum Mail Gateway -> Hedef Kullanıcı`

- **Gophish**: Kampanya yönetimi, şablon, takip ve raporlama.
- **Postfix Relay**: Gophish'ten gelen SMTP trafiğini kurumsal gateway'e iletme.
- **Özel Docker ağı**: Gophish ve Postfix sadece kendi izole ağında haberleşir.
- **Port tasarımı**:
  - Admin panel: `3333`
	- Landing/listener dış erişim: `60888` (sunucudaki 80 portu çakışmasını önler)
- **Kalıcılık (persistency)**: Gophish verisi (`gophish.db` dahil) named volume üzerinde tutulur.

## 2) Ön Koşullar

- Docker Engine + Docker Compose plugin
- Sunucu üzerinde aşağıdaki portlara kontrollü erişim:
  - `3333/tcp` (sadece yönetim IP'leri)
	- `60888/tcp` (test senaryosuna göre)
- Yazılı yetki, kapsam dokümanı ve onaylı test penceresi (change window)

## 3) Kurulum ve Ayağa Kaldırma

1. Proje dizinine geçin.
2. Servisleri başlatın:

```bash
docker compose up -d
```

3. Durumu doğrulayın:

```bash
docker compose ps
docker compose logs -f gophish
docker compose logs -f postfix
```

4. Erişim:
	- Gophish Admin: `https://SUNUCU_IP:3333` (self-signed sertifika nedeniyle tarayıcı uyarısı görebilirsiniz)
	- Landing/listener: `http://SUNUCU_IP:60888`

## 4) Gophish Sending Profile Ayarları

Gophish panelinde `Sending Profiles` oluştururken:

- **Name**: `Local-Postfix-Relay`
- **From**: Test senaryosunda onaylı gönderici adresi
- **Host**: `postfix-relay:25`  
  (alternatif ifade: Postfix konteyner IP'si `172.29.0.20:25`)
- **Username / Password**: Relay politikasına göre boş veya kimlik doğrulamalı
- **Ignore Certificate Errors**: TLS topolojisine göre değerlendirin

Not: Bu kurulumda Postfix yalnızca Gophish konteynerinden (`172.29.0.10`) gelen SMTP trafiğini kabul edecek şekilde sınırlandırılmıştır.

## 5) Kurumsal Teknik Ekip Yönergesi (Kontrollü İstisna Yönetimi)

Bu bölüm, yalnızca **onaylı simülasyon penceresi** için geçici ve izlenebilir istisna (exception) tanımlarını kapsar.

### 5.1 E-posta Geçidi (Exchange / M365 / SEG)

Teknik ekipten aşağıdaki kontrollü istisnaları isteyin:

1. **Kaynak IP Allowlist (Scoped)**
	- Sadece simülasyon sunucusunun sabit çıkış IP'si
	- Sadece onaylı tarih/saat aralığı
	- Sadece onaylı alıcı grupları

2. **Spoofing Koruma İstisnası (Scoped Exception)**
	- Tam bypass yerine, yalnızca test kampanyası kapsamındaki:
	  - belirli gönderen pattern'leri,
	  - belirli hedef grup,
	  - belirli zaman penceresi
	- Tüm eşleşmeler SIEM'e loglanmalı ve change kaydı ile ilişkilendirilmeli

3. **Anti-Phishing / Anti-Spam Politika İstisnası (Minimum Scope)**
	- Genel politika kapatma yapılmaz
	- Sadece kampanya göstergelerine özel kural uygulanır

### 5.2 Web Güvenlik Geçidi / URL Filtreleme

1. **Landing URL İstisnası (Minimum Scope)**
	- Sadece onaylı simülasyon URL/FQDN/port (`:60888`) için
	- Sadece hedef kullanıcı grubu için
	- Süreli (auto-expire) kural

2. **TLS Inspection / Sandbox Davranışı**
	- Simülasyon URL'sinde yanlış pozitifleri azaltacak scoped kural
	- Test bitiminde otomatik geri alma

3. **Doğrulama ve Geri Dönüş Planı**
	- Kural öncesi/sonrası test kanıtı
	- Rollback komutu/prosedürü
	- Kural sahibi, bitiş zamanı ve kapatma onayı

## 6) Operasyonel Güvenlik (Best Practices)

- `3333` portunu internete açık bırakmayın; IP kısıtı/VPN arkasında tutun.
- Admin parolalarını ilk girişte değiştirin; mümkünse MFA veya bastion erişimi kullanın.
- Container image güncellemelerini kontrollü geçirin (`docker compose pull`).
- Logları merkezi sisteme (SIEM) aktarın ve kampanya sonunda kanıt arşivleyin.
- Test sonrası tüm geçici istisnaları kaldırın ve kapanış raporu üretin.

## 7) Yasal Uyarı (Disclaimer)

Bu proje ve içerdiği yapılandırmalar yalnızca **yazılı olarak yetkilendirilmiş** sızma testi, kırmızı takım ve güvenlik farkındalık simülasyonlarında kullanılabilir. Yetkisiz kullanım, kimlik avı saldırısı, aldatma amaçlı e-posta gönderimi veya üçüncü taraf sistemlerde izinsiz test faaliyetleri hukuka aykırıdır ve kullanıcı/uygulayıcı sorumluluğundadır.

## 8) Referans

- Gophish Docker image: https://hub.docker.com/r/gophish/gophish/