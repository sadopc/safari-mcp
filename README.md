# safari-mcp

Claude Code ve Claude masaüstü uygulamasının Safari'yi sürmesini sağlayan yerel bir MCP sunucusu. Tek bir Swift ikili dosyası; bağımlılığı, arka plan servisi ve tarayıcı eklentisi yok. Safari'yi Apple Events üzerinden, senin açık oturumlarınla kullanır.

Anthropic ile bağlantısı olmayan bağımsız bir projedir.

## Kurulum

macOS 14 ya da üstü gerekir. Xcode gerekmez; Command Line Tools yeterlidir.

```bash
swift build -c release
```

```bash
claude mcp add --scope user safari -- "$PWD/.build/release/safari-mcp"
```

Yeniden derledikten sonra açık Claude Code oturumları eski sürümü çalıştırmaya devam eder; yeni sürüm yeni oturumda geçerli olur.

## İzinler

| İzin | Ne için | Zorunlu mu |
|---|---|---|
| Safari'yi denetleme (Otomasyon) | Her şey | Evet, ilk kullanımda sorulur |
| Safari > Ayarlar > Geliştirici > "Allow JavaScript from Apple Events" | `tabs` dışındaki bütün araçlar | Evet |
| Ekran Kaydı | `screenshot` | Hayır |
| Erişilebilirlik | `act` içinde `os: true`; ekran görüntüsünün tam kırpılması | Hayır |

Geliştirici sekmesi görünmüyorsa önce Ayarlar > Gelişmiş > "Web geliştiricileri için özellikleri göster" seçeneğini aç.

"Allow JavaScript from Apple Events" ayarı, Safari'yi denetleme izni olan her uygulamanın sayfalarda JavaScript çalıştırmasına izin verir. İzinler sunucuyu başlatan uygulamaya (Claude ya da terminal) yazılır.

## Araçlar

| Araç | İş |
|---|---|
| `tabs` | Sekmeleri listeler, açar, kapatır, seçer |
| `navigate` | URL'ye gider ya da `back` / `forward` / `reload`; yüklenmeyi bekler |
| `read` | Sayfayı okur: etkileşimli öğeler (varsayılan), `all`, `text`; `query` ile öğe ve metin arar |
| `act` | `click`, `dblclick`, `hover`, `type`, `fill`, `select`, `key`, `scroll` |
| `js` | Sayfada JavaScript çalıştırır (async işlev gövdesi, `return` ile değer döner, 15 sn sınırı) |
| `screenshot` | Görünüm alanının, bir öğenin ya da bölgenin JPEG görüntüsü |
| `logs` | Konsol ve ağ kayıtları |
| `batch` | Birden çok çağrıyı tek turda çalıştırır |

`read` her öğeye `e12` gibi bir ref verir; `act` bu ref'le ya da `x,y` ile çalışır. Sayfa değişince ref'ler geçersiz olur.

Sayfayı değiştiren çağrılar (`act`, `navigate`, yönlendiren `js`) yeni sayfanın yüklenmesini bekler ve sonucu `→ başlık | adres` olarak bildirir. Bir tıklama ya da tuş hiçbir şeyi değiştirmediyse sonuçta `(no change on the page yet)` yazar.

## Sekmeler

Sekme kimlikleri `t3` biçimindedir ve sekme açık kaldıkça değişmez; sen sekme açıp kapatsan ya da taşısan da aynı sekmeyi gösterir. Safari her çağrıda, işlemi yapmadan önce o konumdaki sekmenin beklenen sekme olduğunu doğrular; tutmuyorsa sunucu sekmeyi yeniden bulur ya da hata döner. Yanlış sekmede işlem yapmaz.

Sekme verilmeyen çağrılar son kullanılan sekmede çalışır. O sekme kapanırsa sunucu başka bir sekmeye geçmez, sekme kimliği ister. Hiç sekme kullanılmamışsa ilk çağrı öndeki pencerenin görünen sekmesini kullanır.

Sunucunun açtığı sekmeler arka planda açılır.

## Tıklama ve yazma

Varsayılan yol sayfa içi olaylardır: Safari arka planda kalır, imleç sende kalır. `os: true` gerçek fare ve klavye olayı gönderir; Erişilebilirlik izni ister ve Safari'yi öne getirir. Sayfa içi olayları yok sayan siteler için düşünülmüştür.

## Ekran görüntüsü

macOS yalnızca o an görünen masaüstündeki pencereleri çizer. Safari başka bir masaüstündeyse ya da tam ekrandaysa sunucu onu yaklaşık bir saniyeliğine öne getirir, görüntüyü alır ve önceki uygulamaya döner. Safari görünür durumdaysa geçiş olmaz.

Yakalama ayrı, kısa ömürlü bir yardımcı süreçte yapılır; 6 saniyede bitmezse sonlandırılır.

## Sınırlar

- Bir sekme bu oturumun dışında başka bir siteye giderse ve aynı anda pencerede sekme açılıp kapanırsa sunucu o sekmeyi kaybedebilir. Bu durumda hata döner; `tabs` ile yeni kimlik alınır.
- Erişilebilirlik izni yokken ekran görüntüsü kırpması, kenar çubuğunun solda, araç çubuğunun üstte olduğunu ve sayfa yakınlaştırmasının %100 olduğunu varsayar.
- Konsol ve ağ kayıtları ilk `logs` çağrısından sonrasını kapsar. İlk ağ çağrısı o ana kadar yüklenmiş kaynakları durum kodu olmadan listeler.
- iframe içerikleri ve kapalı shadow DOM okunmaz.
- Sayfa `alert` gibi bir iletişim kutusu gösterirken çağrılar zaman aşımına uğrar.
- HTTP durum kodu (404 gibi) bildirilmez; Safari'nin hiç açamadığı adresler hata döner.
- `os: true` yolu gerçek kullanımda sınanmadı.

## Test

```bash
Tests/smoke.sh
```

Protokol düzeyinde bir duman testidir; Safari izni gerektirmez.
