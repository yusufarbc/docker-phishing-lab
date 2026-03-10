# Phishing Lab (Gophish + Postfix + Caddy)

Yetkili guvenlik testleri icin tek bir Docker stack: `Gophish + Postfix relay + Caddy reverse proxy`.

Bu yapi ile tum paneller Caddy arkasinda yayinlanir. HTTPS standart `443` yerine `8443` uzerinden acilir; dis dunyada sadece `80` ve `8443` acik kalir.

## 1) Mimari

- `Caddy`: TLS/SSL terminasyonu, domain routing, otomatik Let's Encrypt sertifikasi.
- `Gophish`: Phishing kampanya yonetimi.
- `Postfix relay`: Gophish'ten gelen SMTP trafigini kurumsal gateway'e relay eder.

Dis erisim akisi:

- `https://GOPHISH_ADMIN_DOMAIN:8443 -> caddy -> gophish:3333` (Yönetim Paneli)
- `https://GOPHISH_LANDING_DOMAIN:8443 -> caddy -> gophish:80` (Landing Page)

## 2) On Kosullar

- Docker Engine + Docker Compose plugin
- DNS A/AAAA kayitlari sunucuya yonlenmis olmali:
  - `GOPHISH_ADMIN_DOMAIN`
  - `GOPHISH_LANDING_DOMAIN`
- Sunucuda sadece su portlar acik olmali:
  - `80/tcp` (ACME/HTTP challenge)
  - `8443/tcp` (HTTPS panel erisimi)

## 3) Kurulum

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
- Image'larin cekilmesi
- Gophish `config.json` dosyasinin reverse proxy moduna gore guncellenmesi (TLS off, trusted origins set)
- Stack'in ayağa kaldirilmasi

## 4) Erişim

- Gophish Admin: `https://GOPHISH_ADMIN_DOMAIN:8443`
- Gophish Landing: `https://GOPHISH_LANDING_DOMAIN:8443`

Notlar:

- Caddy sertifikayi ilk isteklerde alacagi icin DNS ve port yonlendirmesi dogru olmalidir.
- Gophish ilk calistiginda olusturulan admin parolasi terminale basilir veya `docker compose logs gophish` ile gorulebilir.

## 5) Gophish Sending Profile

Gophish panelinde `Sending Profiles` olustururken:

- Name: `Local-Postfix-Relay`
- Host: `postfix:25`
- Username/Password: (Bos birakilabilir veya relay politikaniza gore)

Guvenlik notu: Postfix varsayilan olarak sadece Gophish konteynerinden (`172.30.0.10`) SMTP kabul edecek sekilde sinirlandirilmistir.

## 6) Operasyonel Guvenlik

- Caddy disinda panel portlari host'a publish edilmez (3333 kapali).
- Tum paneller Caddy arkasinda oldugu icin dis dunyaya sadece `80` ve `8443` acik kalir.
- Yonetim domainleri icin ek olarak IP allowlist/WAF tavsiye edilir.
- Admin hesaplarinda guclu parola ve mumkunse MFA kullanin.
- Test bitince gecici allowlist/exception kurallarini kaldirin.

## 7) Yasal Uyari

Bu proje yalnizca yazili olarak yetkilendirilmis guvenlik testleri icin kullanilmalidir. Yetkisiz kullanim hukuka aykiridir ve tum sorumluluk uygulayiciya aittir.
