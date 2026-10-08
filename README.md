# safari-mcp

Claude Code'un Safari'yi sürmesini sağlayan yerel bir MCP sunucusu. Tek bir Swift ikili dosyası; bağımlılığı, arka plan servisi ve tarayıcı eklentisi yok. Safari'yi Apple Events üzerinden, senin açık oturumlarınla kullanır.

Claude in Chrome yalnızca Chromium tarayıcılarda çalıştığı için yazıldı. Anthropic ile bağlantısı olmayan bağımsız bir projedir; resmi eklentinin kodunu, oturum token'ını ya da bulut köprüsünü kullanmaz.

## Ne zaman kullanılır

| | safari-mcp | Playwright |
|---|---|---|
| Tarayıcı | Senin açık Safari'n, kendi oturumlarınla | Kendi başlattığı ayrı tarayıcı |
| Girdi | Varsayılan sayfa içi olaylar; istenirse gerçek fare/klavye | Tarayıcı düzeyinde gerçek olaylar |
| iframe, iletişim kutusu, dosya yükleme, ağ müdahalesi | Yok | Var |
| Platform | macOS 14+ | macOS, Windows, Linux |

Giriş yapmış olduğun sitelerde okuma, arama, form doldurma ve gezinme gibi günlük işler için uygundur. Web uygulaması testi, CI ve tekrarlanabilir otomasyon için Playwright daha doğru araçtır.

## Kurulum

macOS 14 ya da üstü gerekir. Xcode gerekmez; Command Line Tools yeterlidir.

```bash
git clone https://github.com/sadopc/safari-mcp.git
```

```bash
cd safari-mcp && swift build -c release
```

```bash
claude mcp add --scope user safari -- "$PWD/.build/release/safari-mcp"
```

Kayıt ikilinin tam yolunu saklar; klasörü taşırsan komutu yeniden çalıştır. Yeniden derledikten sonra açık Claude Code oturumları eski sürümü çalıştırmaya devam eder; yeni sürüm yeni oturumda geçerli olur.

## İzinler

| İzin | Ne için | Zorunlu mu |
|---|---|---|
| Safari'yi denetleme (Otomasyon) | Her şey | Evet, ilk kullanımda sorulur |
| Safari > Ayarlar > Geliştirici > "Allow JavaScript from Apple Events" | `tabs` dışındaki bütün araçlar | Evet |
| Ekran Kaydı | `screenshot` | Hayır |
| Erişilebilirlik | `act` içinde `os: true`; ekran görüntüsünün tam kırpılması | Hayır |

Geliştirici sekmesi görünmüyorsa önce Ayarlar > Gelişmiş > "Web geliştiricileri için özellikleri göster" seçeneğini aç.

"Allow JavaScript from Apple Events" ayarı, Safari'yi denetleme izni olan her uygulamanın sayfalarda JavaScript çalıştırmasına izin verir. İzinler sunucuyu başlatan uygulamaya (Claude ya da terminal) yazılır.

## Kullanım

Kurulumdan sonra Claude Code'a doğrudan iş söylemek yeterlidir:

- "Safari'de açık sekmelerimi listele."
- "Wikipedia'da Boğaziçi Köprüsü'nü ara, açılış yılını söyle."
- "Şu sayfadaki formu şu bilgilerle doldur ama gönderme."

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

Varsayılan yol sayfa içi olaylardır: Safari arka planda kalır, imleç sende kalır.

`os: true` gerçek fare ve klavye olayı gönderir. Sayfa içi olayları yok sayan siteler ve üzerine gelince (CSS `:hover`) beliren denetimler için gerekir. Erişilebilirlik izni ister, Safari'yi öne getirir ve çalışırken imleci kullanır; tıklamadan sonra imleci eski yerine koyar, `hover` sonrasında öğenin üzerinde bırakır. Çağrı başına yaklaşık bir saniye sürer.

## Ekran görüntüsü

macOS yalnızca o an görünen masaüstündeki pencereleri çizer. Safari başka bir masaüstündeyse ya da tam ekrandaysa sunucu onu yaklaşık bir saniyeliğine öne getirir, görüntüyü alır ve önceki uygulamaya döner. Safari görünür durumdaysa geçiş olmaz.

Yakalama ayrı, kısa ömürlü bir yardımcı süreçte yapılır; 6 saniyede bitmezse sonlandırılır.

## Kaynak kullanımı

Tek bir Mac'te ölçülen değerler:

| | |
|---|---|
| Araç şemaları | Yaklaşık 730 token |
| Varsayılan `read` çıktısı | Wikipedia ana sayfasında yaklaşık 500, Hacker News'te yaklaşık 1.100 token |
| Çağrı süresi | `read` 7-60 ms, `js` 20-45 ms, `act` 170-470 ms, `screenshot` 0,9-2,1 sn |
| Bellek | Safari kullanılmadan 9 MB, kullanıldıktan sonra yaklaşık 34 MB |
| Boşta CPU | 0 |
| İkili dosya | Yaklaşık 360 KB |

## Sınanma durumu

Sunucu, küçük bir modelin (Claude Haiku) araçları yalnızca açıklamalarından kullanarak gerçek sitelerde görev yaptığı beş turla sınandı: Wikipedia, Hacker News, MDN, GitHub, DuckDuckGo, W3Schools, httpbin formları ve TodoMVC (React ve Vue). Son regresyon turunda sayfayı değiştiren 28 çağrının hepsinde bildirilen sayfa ile ardından okunan sayfa aynıydı.

Bu, bir günde ve tek bir makinede yapılmış bir sınamadır; geniş bir site yelpazesinde denenmedi.

## Sınırlar

- Bir sekme bu oturumun dışında başka bir siteye giderse ve aynı anda pencerede sekme açılıp kapanırsa sunucu o sekmeyi kaybedebilir. Bu durumda hata döner; `tabs` ile yeni kimlik alınır.
- Sayfa içi olaylar CSS `:hover` stilini tetikleyemez ve bazı siteler bu olayları yok sayar; bu durumlarda `os: true` gerekir.
- Erişilebilirlik izni yokken ekran görüntüsü kırpması, kenar çubuğunun solda, araç çubuğunun üstte olduğunu ve sayfa yakınlaştırmasının %100 olduğunu varsayar.
- Konsol ve ağ kayıtları ilk `logs` çağrısından sonrasını kapsar. İlk ağ çağrısı o ana kadar yüklenmiş kaynakları durum kodu olmadan listeler.
- iframe içerikleri ve kapalı shadow DOM okunmaz.
- Sayfa `alert` gibi bir iletişim kutusu gösterirken çağrılar zaman aşımına uğrar.
- HTTP durum kodu (404 gibi) bildirilmez; Safari'nin hiç açamadığı adresler hata döner.
- Dosya yükleme yoktur.

## Test

```bash
Tests/smoke.sh
```

Protokol düzeyinde bir duman testidir; Safari izni gerektirmez.
