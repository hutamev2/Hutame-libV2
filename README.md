# Hutame UI v1.1

Referanstaki koyu hub arayüzünden esinlenen, Roblox istemcisinde çalışan Luau UI kütüphanesi. Harici paket gerektirmez. Avatar görseli Roblox üzerinden alınır.

Builder Sans / Medium / Bold font ailesi, minimum 12 px yardımcı yazılar ve daha belirgin ikincil metinler kullanılır. Pencere açılış/kapanışında fade + ölçek, sekme geçişlerinde fade + kayma, dropdown açılışında genişleme, butonlarda basma, input odak çizgisinde renk ve bildirimlerde giriş/çıkış animasyonları vardır.

## Madium — hemen çalıştır

`dist/Hutame.lua` tek dosyalık kütüphanedir ve çalıştırılınca `Hutame` tablosunu döndürür. `dist/DemoHub.lua` kütüphaneyi içerir ve demo arayüzü açar. `node scripts/build.mjs` ile ikisini kaynaklardan yeniden üretin.

Repo herkese açıktır. Başka bilgisayarlarda token veya yerel dosya gerektirmeden çalıştırın:

```lua
-- Tam demo:
loadstring(game:HttpGet("https://raw.githubusercontent.com/hutamev2/Hutame-libV2/main/dist/DemoHub.lua"))()

-- Kendi hub kodun için yalnızca kütüphane:
local Hutame = loadstring(game:HttpGet("https://raw.githubusercontent.com/hutamev2/Hutame-libV2/main/dist/Hutame.lua"))()
local Window = Hutame:CreateWindow({
    Title = "My Hub",
    Font = Enum.Font.BuilderSans,
    FontMedium = Enum.Font.BuilderSansMedium,
    FontBold = Enum.Font.BuilderSansBold,
    AnimationDuration = 0.24,
})
```

Madium'da `gethui()` geçerli Instance döndürürse arayüz oraya eklenir; aksi durumda PlayerGui kullanılır. `Parent` seçeneği bunu geçersiz kılar. Aynı demo tekrar çalıştırıldığında yalnızca önceki Hutame demosu temizlenir.

## GitHub dağıtımı

Repo: [hutamev2/Hutame-libV2](https://github.com/hutamev2/Hutame-libV2) — public. `dist/Hutame.lua` yalnız kütüphaneyi döndürür; pencereyi kendi hub kodunuzda `CreateWindow` ile oluşturun. `dist/DemoHub.lua` ise örnek arayüzü doğrudan açar.

`main` bağlantıları güncel sürümü indirir. Sabit sürüm isteyen hub'lar URL'deki `main` yerine test ettikleri commit SHA'sını kullanabilir. `examples/LoadPublic.lua` hata denetimli yükleme örneğidir. Eski `examples/LoadPrivate.lua` yalnız private fork'lar için arşivlenmiş alternatiftir; bu repo için kullanılmaz.

Madium API referansı: [loadstring, request ve gethui belgeleri](https://getmadium.net/docs/?page=README).

## Kurulum

Roblox Studio'da `ReplicatedStorage` içine `Hutame` adında bir ModuleScript oluşturun ve `src/init.lua` içeriğini yapıştırın. `examples/DemoHub.client.lua` içeriğini `StarterPlayer > StarterPlayerScripts` altındaki bir LocalScript'e ekleyip **Play** çalıştırın.

Rojo kullananlar `rojo build default.project.json -o build/DemoHub.rbxlx` ile örnek yeri oluşturabilir veya `rojo serve` ile Studio'ya bağlayabilir. Hazır `build/DemoHub.rbxlx` dosyasını Studio'da açıp Play'e basabilirsiniz. `build/Hutame.rbxmx` yalnızca kütüphanedir; ReplicatedStorage'a eklenebilir.

Kaynak ve örnekler Luau derleyicisiyle, Studio çıktıları Rojo ile kontrol edilir. Madium istemcisinde çalışan `tests/Smoke.lua`, değerleri, callback'leri, hızlı animasyon geçişlerini, bildirimlerin kaldırılmasını ve bağlantı temizliğini doğrular.

Standart Studio kullanımı `require` üzerindendir; Studio yolu Madium fonksiyonlarına bağımlı değildir.

## Kullanım

```lua
local Hutame = require(game:GetService("ReplicatedStorage"):WaitForChild("Hutame"))
local Window = Hutame:CreateWindow({
    Title = "My Hub", Subtitle = "Welcome", HubName = "Hutame Hub",
    ToggleKey = Enum.KeyCode.RightControl,
    Theme = { Accent = Color3.fromRGB(152, 204, 255) },
})
local Tab = Window:CreateTab({ Name = "Main" })
local Section = Tab:CreateSection("Actions")
Section:CreateButton({ Name = "Run", Callback = function() print("Clicked") end })
local Toggle = Section:CreateToggle({
    Name = "Enabled", Description = "Enable this option", Default = false,
    Flag = "Enabled", Callback = function(value) print(value) end,
})
Toggle:SetValue(true)
print(Window.Flags.Enabled)
```

## Kontroller

| Metot | Ayarlar |
| --- | --- |
| `CreateButton` | Name, Description?, Callback? |
| `CreateToggle` | Name, Description?, Default?, Flag?, Callback? |
| `CreateSlider` | Name, Description?, Min?, Max?, Increment?, Default?, Flag?, Callback? |
| `CreateDropdown` | Name, Description?, Options, Default?, Flag?, Callback? |
| `CreateInput` | Name, Description?, Placeholder?, Default?, Flag?, Callback? |
| `CreateLabel` | Name, Text? |
| `CreateDivider` | Ayar almaz |

Tüm kontroller `SetText`, `SetVisible`, `SetDisabled` ve `Destroy` döndürür. Değer taşıyan kontroller `SetValue` / `GetValue` destekler. Label için `SetText` başlığı, `SetValue` alt metni değiştirir. Dropdown ayrıca `SetOptions({"A", "B"})` destekler; seçenekler metin olmalıdır.

`SetValue(value, true)` callback çağırmadan günceller. Oluşturma sırasında callback çağrılmaz. Input callback'i odak kaybolduğunda ve değer değişmişse çalışır. Slider değişiklik boyunca callback üretir. Callback hataları uyarı olarak raporlanır. Uzun süren işlemlerin durdurulması hub kodunun sorumluluğundadır.

`Flag` bir pencere içinde benzersiz olmalıdır. Çoklu pencerelerde `Window.Flags` kullanın; `Hutame.Flags` tek pencere kolaylığı için ortak görünüm sağlar ve aynı isimli flag'ler birbirini etkiler. Kalıcı config kaydı ilk sürüme dahil değildir.

## Pencere

- `Window:CreateTab("Settings")` veya `{Name = "Settings"}`
- `Tab:CreateSection("General")`, `Tab:Select()`
- `Window:Show()`, `Hide()`, `Toggle()`, `Destroy()`
- `Window:SetStatus("Ready")`
- `Window:Notify({Title = "Hello", Content = "Ready", Duration = 4})`

Başlık alanı fare ve dokunma ile sürüklenebilir. Sarı simge gizler; kırmızı simge pencereyi ve bağlantılarını kaldırır. Alttaki buton veya RightControl tekrar açar. Ekran boyutuna göre otomatik ölçekleme ve yatay sekme kaydırması vardır. Dar telefon ekranlarında masaüstü düzeni küçülür; ayrı mobil düzen henüz yoktur.

Tema anahtarları: `Background`, `Sidebar`, `Surface`, `Hover`, `Border`, `Text`, `Muted`, `Accent`. Tema oluşturma sırasında verilir. Keybind bileşeni, color picker, ikon alanları, dinamik tema değiştirme ve kalıcı config sistemi sonraki sürüm kapsamındadır.

Örnek hub yalnızca arayüz davranışını gösterir; oyun otomasyonu veya sunucu değiştirme işlemi içermez. Bu işlemleri kendi callback'lerinize bağlayın.

## Studio kontrol listesi

Play modunda sekmeleri değiştirin; toggle, slider, dropdown ve input değerlerini kontrol edin. Açık dropdown ile sayfayı kaydırın. Input odaktayken RightControl'ün pencereyi kapatmadığını doğrulayın. Pencereyi sürükleyin, gizleyip açın, ekran boyutunu değiştirin. Device Emulator ile dokunmatik slider ve sürüklemeyi deneyin. Son olarak kırmızı kapatma düğmesinin UI'yi kaldırdığını kontrol edin.
