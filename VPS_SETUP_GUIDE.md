# VPS Üzerinde Domain ile Gophish Phishing Lab Kurulum Rehberi

Bu rehber, projenizi bir VPS üzerinde gerçek domainlerle nasıl yayına alacağınızı adım adım açıklar.

## 1) Hazırlık ve Gereksinimler

- **VPS**: Ubuntu 22.04 veya 24.04 (Önerilen minimum 2 vCPU, 4GB RAM).
- **Domain**: İki adet subdomain (örneğin: `yonetim.domain.com` ve `kampanya.domain.com`).
- **A Kayıtları**: Domain panelinizden her iki subdomain'i de VPS'inizin **Public IP** adresine yönlendirin.

## 2) Sunucu Hazırlığı (VPS)

SSH ile sunucunuza bağlandıktan sonra gerekli araçları kurun:

```bash
# Paket listesini güncelle
sudo apt update && sudo apt upgrade -y

# Docker kurulumu
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Git kurun (yoksa)
sudo apt install git -y
```

## 3) Projeyi Klonlama ve Yapılandırma

```bash
# Repoyu çekin
git clone <repo-url-buraya> phishing-lab
cd phishing-lab

# .env dosyasını oluşturun
cp .env.example .env
```

`.env` dosyasını düzenleyin: `nano .env`

```env
ACME_EMAIL=sizin-email-adresiniz@gmail.com
GOPHISH_ADMIN_DOMAIN=yonetim.domain.com
GOPHISH_LANDING_DOMAIN=kampanya.domain.com
```

## 4) Port ve Güvenlik Duvarı Ayarları (Kritik)

Bu projenin Caddy yapılandırmasında standart HTTPS portu `443` kullanılmaktadır. VPS sağlayıcınızın panelinden (AWS, DigitalOcean, Hetzner, vb.) ve sunucu içinden şu portları açın:

- `80/tcp`: Caddy'nin SSL (ACME) sertifikası alabilmesi için şarttır.
- `443/tcp`: Panellere erişim için kullanılacak tek port.
- `22/tcp`: SSH erişimi.

Sunucu içinde (ufw kullanılıyorsa):
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

## 5) Kurulumu Başlatın

Hazırladığımız scripti çalıştırın:

```bash
bash deploy-lab.sh
```

Bu script şunları yapar:
1. Docker image'larını çeker.
2. Gophish'i `config.json` seviyesinde reverse proxy moduna alır (TLS kapatır, Caddy'ye güvenir).
3. Postfix relay'i yapılandırır.
4. Stack'i ayağa kaldırır.

## 6) Erişim ve İlk Şifre

Sistem ayağa kalktıktan sonra script sonunda size Gophish admin şifresini yazacaktır. Eğer kaçırırsanız şu komutla görebilirsiniz:

```bash
docker compose logs gophish | grep password
```

**Erişim Linkleri:**
- **Yönetim Paneli:** `https://yonetim.domain.com`
- **Landing (Kurban) Sayfası:** `https://kampanya.domain.com`

*Not: İlk girişte Caddy sertifika alırken bir kaç saniye gecikme olabilir. SSL hatası alırsanız biraz bekleyip sayfayı yenileyin.*

### Sorun Giderme: `Forbidden - referer invalid`

Bu hata genelde Gophish `trusted_origins` listesi ile giriş yaptığınız URL birebir eşleşmediğinde oluşur.

1. Sadece şu adresten giriş yapın:
`https://GOPHISH_ADMIN_DOMAIN`

2. VPS üzerinde `trusted_origins` değerini güncelleyin:

```bash
docker compose exec gophish sh -lc "sed -i -E 's#\"trusted_origins\": *\[[^]]*\]#\"trusted_origins\": [\"https://${GOPHISH_ADMIN_DOMAIN}:8443\",\"https://${GOPHISH_ADMIN_DOMAIN}\",\"http://${GOPHISH_ADMIN_DOMAIN}:8443\",\"http://${GOPHISH_ADMIN_DOMAIN}\",\"https://${GOPHISH_LANDING_DOMAIN}:8443\",\"https://${GOPHISH_LANDING_DOMAIN}\"]#' /opt/gophish/config.json"
docker compose exec gophish sh -lc "sed -i -E 's#\"trusted_origins\": *\[[^]]*\]#\"trusted_origins\": [\"https://${GOPHISH_ADMIN_DOMAIN}\",\"https://${GOPHISH_ADMIN_DOMAIN}:443\",\"http://${GOPHISH_ADMIN_DOMAIN}\",\"http://${GOPHISH_ADMIN_DOMAIN}:80\",\"https://${GOPHISH_LANDING_DOMAIN}\",\"https://${GOPHISH_LANDING_DOMAIN}:443\"]#' /opt/gophish/config.json"
docker compose restart gophish caddy
```

3. Tarayıcıda bu domain için cache/cookie temizleyip tekrar giriş yapın.

## 7) Gophish İçinde Gönderim Profili (SMTP)

Gophish paneline girdikten sonra `Sending Profiles` kısmında şu ayarı yapın:

- **Host**: `postfix:25`
- **From**: `bilgi@kampanya.domain.com` (veya istediğiniz bir adres)
- **Ignore Certificate Errors**: Seçili olsun (Konteyner içi bağlantı olduğu için).

Artık kampanyanızı başlatmaya hazırsınız!
