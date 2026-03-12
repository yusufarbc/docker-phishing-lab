# Postfix ile Gophish Bağlama Rehberi

Gophish'in e-posta fırlatabilmesi için onu Docker ortamında çalışan arka plandaki Postfix ("postfix-relay-lab") servisine bağlamamız gerekiyor. Mimaride Postfix servisi, Gophish (172.30.0.10) adresinden gelen mailleri parola sormadan kabul edecek (`permit_mynetworks`) şekilde ayarlanmıştır.

## "New Sending Profile" Ayarları

Gophish admin paneline giriş yaptıktan sonra "Sending Profiles" menüsünden "New Profile" butonuna tıklayarak aşağıdaki şekilde ayarlarınızı yapabilirsiniz:

- **Name:** Özel bir ad verebilirsiniz. Örnek: `Simulasyon Postfix`
- **Interface Type:** `SMTP`
- **SMTP From:** Simülasyon sırasında gönderici (From) olarak görünecek e-posta adresi. Örnek: `support@arnnabilisim.com.tr`
- **Host:** İki farklı şekilde yazabilirsiniz:
  - `postfix-relay-lab:25` (Docker'ın kendi iç DNS'ini kullanarak)
  - `172.30.0.20:25` (Yönlendirici servisine statik IP üzerinden)
- **Username:** *[Boş bırakın]* (Docker ağı içinde kimlik doğrulamaya gerek yoktur)
- **Password:** *[Boş bırakın]* (Gizli kalmalı)
- **Ignore Certificate Errors:** `[x]` (İşaretli olsun, iç ağda TLS hatalarını göz ardı etmek iyi pratiktir)
- **Email Headers (İsteğe bağlı):** Anti-spam ürünlerini atlatmak için burada ek header'lar belirtebilirsiniz.

### Test Aşaması (Send Test Email)
Girilen değerlerin doğruluğundan emin olmak için sol alttaki **Send Test Email** butonuna tıklayın ve kendi test (örn. kişisel gmail/şirket) e-postanızı girin. 

**E-posta gelmiyorsa veya hata veriyorsa:**
1. Postfix konteynırının çalıştığını kontrol edin:
   `docker logs postfix-relay-lab`
2. `POSTFIX_relayhost` ayarında yer alan harici sunucunun (örneğin 159.253.46.182:587) aktif olup olmadığını kontrol edin.

## Notlar
- Gophish, Postfix'e maili **port 25** (iç ağ, şifresiz) üzerinden iletir. Daha sonra Postfix, bu maili internete kendi üzerinde tanımlı relayhost (`159.253.46.182:587`) üzerinden yollar.

---

### Gophish Başlangıç Parolası Sıfırlama (Eğer parolayı unuttuysanız)
Gophish, ilk kurulduğunda parolayı loglarına yazdırır. Ancak siz persist olarak (`gophish_data` volume'una) önceki kurulumlarınızı sakladığınız için loglarda yeni bir parola çıkmaz. 
Eski veritabanınızı **tamamen sıfırlamak (yeni parola verdirtmek)** isterseniz, terminalde şu komutları girebilirsiniz:
```bash
docker-compose -f docker-compose.cloudflare.yml down -v
docker-compose -f docker-compose.cloudflare.yml up -d
docker logs gophish-lab
```
*Uyarı: `down -v` parametresi Gophish içindeki tüm geçmiş kampanya verilerinizi ve şablonlarınızı da siler.*