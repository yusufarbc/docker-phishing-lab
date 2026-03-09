# Cyber Lab (Gophish + OpenVAS + Caddy)

Yetkili guvenlik testleri icin tek bir Docker stack: `Gophish + Postfix relay + OpenVAS (Greenbone CE) + Caddy reverse proxy`.

Bu yapi ile tum paneller Caddy arkasinda yayinlanir. HTTPS standart `443` yerine `8443` uzerinden acilir; dis dunyada sadece `80` ve `8443` acik kalir.

## 1) Mimari

- `Caddy`: TLS/SSL terminasyonu, domain routing, otomatik Let's Encrypt sertifikasi.
- `Gophish`: Phishing kampanya yonetimi.
- `Postfix relay`: Gophish'ten gelen SMTP trafigini kurumsal gateway'e relay eder.
- `OpenVAS (Greenbone CE)`: Vulnerability scanning ve GSA web arayuzu.

Dis erisim akisi:

- `https://GOPHISH_ADMIN_DOMAIN -> caddy -> gophish:3333`
- `https://GOPHISH_LANDING_DOMAIN -> caddy -> gophish:80`
- `https://OPENVAS_DOMAIN -> caddy -> gsa:9392`

## 2) On Kosullar

- Docker Engine + Docker Compose plugin
- DNS A/AAAA kayitlari sunucuya yonlenmis olmali:
- `GOPHISH_ADMIN_DOMAIN`
- `GOPHISH_LANDING_DOMAIN`
- `OPENVAS_DOMAIN`
- Sunucuda sadece su portlar acik olmali:
- `80/tcp` (ACME/HTTP challenge)
- `8443/tcp` (HTTPS panel erisimi)

## 3) Kurulum (Tek Script)

1. Ortam dosyasini hazirlayin:

```bash
cp .env.example .env
```

2. `.env` dosyasini gercek degerlerle guncelleyin.

3. Tek komutla stack'i kaldirin:

```bash
bash deploy-lab.sh
```

Script su adimlari otomatik yapar:

- Docker ve compose kontrolu
- `docker compose config` ile dogrulama
- Tum image'larin cekilmesi
- Tum stack'in ayağa kaldirilmasi

OpenVAS'siz alternatif:

- Ayrica `no-openvas/` klasoru altinda sadece `Caddy + Gophish + Postfix` iceren ayri compose yapisi bulunur.
- Kullanmak icin `no-openvas/` klasorune gecip `.env.example` dosyasini `.env` olarak kopyalayin.
- Baslatma komutu: `bash deploy-lite.sh`

## 4) Erişim

- Gophish Admin: `https://GOPHISH_ADMIN_DOMAIN:8443`
- Gophish Landing: `https://GOPHISH_LANDING_DOMAIN:8443`
- OpenVAS GSA: `https://OPENVAS_DOMAIN:8443`

Notlar:

- OpenVAS ilk acilista feed sync nedeniyle uzun sure baslangicta kalabilir.
- Caddy sertifikayi ilk isteklerde alacagi icin DNS ve port yonlendirmesi dogru olmalidir.

## 5) Gophish Sending Profile

Gophish panelinde `Sending Profiles` olustururken:

- Name: `Local-Postfix-Relay`
- Host: `postfix-relay:25`
- Username/Password: Relay politikaniza gore

Guvenlik notu: Postfix varsayilan olarak sadece Gophish konteynerinden (`172.29.0.10`) SMTP kabul edecek sekilde sinirlandirilmistir.

## 6) Operasyonel Guvenlik

- Caddy disinda panel portlari host'a publish edilmez (3333/9392 kapali).
- Tum paneller Caddy arkasinda oldugu icin dis dunyaya sadece `80` ve `8443` acik kalir.
- Yonetim domainleri icin ek olarak IP allowlist/WAF tavsiye edilir.
- Admin hesaplarinda guclu parola ve mumkunse MFA kullanin.
- Test bitince gecici allowlist/exception kurallarini kaldirin.

## 7) Yasal Uyari

Bu proje yalnizca yazili olarak yetkilendirilmis guvenlik testleri icin kullanilmalidir. Yetkisiz kullanim hukuka aykiridir ve tum sorumluluk uygulayiciya aittir.