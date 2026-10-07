# Hutame UI v1.2.0

Referanstaki koyu hub arayüzünden esinlenen, Roblox istemcisinde çalışan Luau UI kütüphanesi. Harici paket gerektirmez. Avatar görseli Roblox üzerinden alınır.

Builder Sans / Medium / Bold font ailesi, minimum 12 px yardımcı yazılar ve daha belirgin ikincil metinler kullanılır. Pencere açılış/kapanışında fade + ölçek, sekme geçişlerinde fade + kayma, dropdown açılışında genişleme, butonlarda basma, input odak çizgisinde renk ve bildirimlerde giriş/çıkış animasyonları vardır.

1.2.0: 156 px sol panel, 660×440 varsayılan pencere, daha belirgin başlıklar, 36×36 kapatma/gizleme hedefleri, arama, yeniden boyutlandırma, primary/secondary ve kompakt butonlar, otomatik loading, keybind, tooltip, daraltılabilir bölümler ve config profilleri eklendi. Büyük dekoratif H kaldırıldı; butona basınca yazı/yerleşim ölçeklenmez, ince çerçeve vurgusu değişir.

32 px sekmelerde alt çizgi metinden ayrı durur. İçerik sekme yönünde yalnızca 6 px kayar. Cubic/Out easing kullanılır; aynı özelliğe yeni tween gelirse mevcut konumundan yeni hedefe devam eder. Farklı özellikler (ör. saydamlık ve yükseklik) birbirinin animasyonunu kesmez. `AnimationDuration` varsayılan 0.24 saniyedir; sekme hover süresi bunun %75'idir.

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

Kaynak ve örnekler Luau derleyicisiyle, Studio çıktıları Rojo ile kontrol edilir. Gerçek Madium istemcisinde `tests/Smoke.lua` temel davranışları; `tests/Features.lua` keybind, loading, arama, collapse, tooltip, boyut sınırları ve profil dosyası döngüsünü doğrular. Features testi yalnız kendisinin oluşturduğu benzersiz test profilini siler. Test fonksiyonlarına güncel Hutame tablosu argüman olarak verilir.

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
| `CreateButton` | Name, Description?, Callback?, Style?, Compact?, AutoLoading?, LoadingText? |
| `CreateToggle` | Name, Description?, Default?, Flag?, Callback? |
| `CreateSlider` | Name, Description?, Min?, Max?, Increment?, Default?, Flag?, Callback? |
| `CreateDropdown` | Name, Description?, Options, Default?, Flag?, Callback? |
| `CreateInput` | Name, Description?, Placeholder?, Default?, Flag?, Callback? |
| `CreateKeybind` | Name, Description?, Default?, Flag?, Callback?, Changed?, AllowWhenHidden? |
| `CreateLabel` | Name, Text? |
| `CreateDivider` | Ayar almaz |

Kontrol ayarları ayrıca `Tooltip`, `Disabled` ve `Persist` alır. Tüm kontroller `SetText`, `SetVisible`, `SetDisabled`, `SetLoading`, `SetTooltip`, `IsDisabled` ve `Destroy` metotları sağlar. Loading veya disabled durumunda kullanıcı etkileşimleri engellenir; programatik `SetValue` çalışır. Değer taşıyan kontroller `SetValue` / `GetValue` destekler. Label için `SetText` başlığı, `SetValue` alt metni değiştirir. Dropdown ayrıca `SetOptions({"A", "B"})` destekler; seçenekler metin olmalıdır.

`SetValue(value, true)` callback çağırmadan günceller. Oluşturma sırasında callback çağrılmaz. Input callback'i odak kaybolduğunda ve değer değişmişse çalışır. Slider değişiklik boyunca callback üretir. Callback hataları uyarı olarak raporlanır. Uzun süren işlemlerin durdurulması hub kodunun sorumluluğundadır.

`Flag` bir pencere içinde benzersiz olmalıdır. Çoklu pencerelerde `Window.Flags` kullanın; `Hutame.Flags` tek pencere kolaylığı için ortak görünüm sağlar ve aynı isimli flag'ler birbirini etkiler. Profiller Flag taşıyan toggle, slider, dropdown, input ve keybind değerlerini saklar. `Persist = false` kontrolü profilden çıkarır.

## Yeni özellikler

```lua
local Window = Hutame:CreateWindow({
    Title = "My Hub", Size = Vector2.new(660, 440),
    MinSize = Vector2.new(520, 340), MaxSize = Vector2.new(1280, 900),
    Resizable = true, ConfigFolder = "HutameUI/MyHub",
})
local Section = Window:CreateTab("Main"):CreateSection({Name = "Actions", Collapsed = false})
local Run = Section:CreateButton({
    Name = "Run", Style = "Primary", Compact = true,
    Tooltip = "Runs once; repeat clicks are blocked while working.",
    Callback = function() task.wait(1) end,
})
Section:CreateKeybind({
    Name = "Action shortcut", Default = Enum.KeyCode.F6, Flag = "ActionKey",
    Callback = function(key) print("Pressed", key) end,
    Changed = function(key) print("Assigned", key) end,
})
Window:CreateConfigTab() -- Hazır oluştur/yükle/değiştir/sil/sıfırla arayüzü
```

Buton `Style = "Primary"` ile mavi vurgulu, aksi halde secondary görünür. `Compact = true` genişliği metne uydurur; varsayılan tam genişlik korunur. Callback tamamlanana kadar otomatik loading/repeat-click koruması vardır. `AutoLoading = false` bu davranışı kapatır; manuel `Run:SetLoading(true/false)` kullanılabilir. Bir callback'in başlattığı ayrı task'ların bitişini kütüphane takip etmez.

Keybind düğmesine tıklayın, yeni tuşa basın. Escape iptal, Backspace/Delete atamayı kaldırır. Yinelenen tuşlar ve pencerenin ToggleKey tuşu reddedilir. Metin yazarken ve oyun tarafından işlenmiş girdilerde tetiklenmez. `Callback` tuşa basınca, `Changed` atama değişince çalışır; profil yüklemek keybind eylemini çalıştırmaz. `AllowWhenHidden` varsayılan true'dur. `Capture()` ve `CancelCapture()` programatik seçim sağlar.

Arama sol paneldedir: sekme adı, bölüm adı, kontrol adı ve açıklamasında düz metin arar. `Window:SetSearch("volume")` aynı işlemi yapar. Seçili sekmede sonuç yoksa ilk eşleşen sekmeye geçer; bölüm geçici açılır. Sorgu silinince önceden daraltılmış durum geri gelir. `SetVisible(false)` aramayla geri açılmaz.

`Section:SetCollapsed(true/false)` ve `Section:Toggle()` veya bölüm başlığı daraltmayı yönetir. Tooltip, fare üzerinde 0.4 saniye kalınca veya dokunmada basılı tutulunca görünür. Başka sekmeye geçince ve pencere gizlenince kapanır; uzun açıklamalar için Description kullanın.

Pencereyi sağ alt köşeden boyutlandırın veya `Window:SetSize(Vector2.new(580, 380))` kullanın. `GetSize()` ölçeklenmemiş boyutu döndürür. `Size`, `MinSize`, `MaxSize` Vector2 veya offset-only UDim2 alır. Minimum kullanılabilir sınır 480×300'dür; `Resizable = false` yalnız fare/dokunmatik tutamacını kaldırır. Küçük ekranlarda mevcut düzen otomatik küçülür; ayrı mobil düzen yoktur.

## Config API

- `Window:ExportConfig()` → JSON string; `Window:ImportConfig(json, silent?)` → başarı, hata?
- `Window:SaveConfig(name, overwrite?)` → başarı, dosya yolu veya hata. Var olan profil için `overwrite=true` gerekir.
- `Window:LoadConfig(name, silent?)` → başarı, hata?
- `Window:ListConfigs()` → isim listesi, hata?
- `Window:DeleteConfig(name)` → başarı, hata?
- `Window:ResetConfig(silent?)` → varsayılan Flag değerlerine dön; kayıtlı dosyalar değişmez.

Profil adı 1–48 harf/rakam/alt çizgi/tire olmalıdır. `ConfigFolder` göreli klasördür; varsayılan `HutameUI/<GameId>`. Birden fazla hub için farklı klasör seçin. Dosyalar Madium workspace'inde JSON olarak kalıcıdır. Studio'da dosya API'leri olmadığı için `ExportConfig`/`ImportConfig` kullanılır; hazır profil sekmesinde dosya işlemleri pasif görünür.

İçe aktarma önce tüm bilinen değerlerin tipini, seçeneklerini ve keybind çakışmalarını kontrol eder; hatalı veri kısmen uygulanmaz. Bilinmeyen Flag'ler atlanır. `silent=true` callback'leri atlar; varsayılanda değer değişim callback'leri çalışır. Dropdown seçenekleri sonradan değiştiyse artık geçersiz olan profil/varsayılan değer reddedilir. Hazır profil sekmesinde silme için ikinci kez `Confirm delete` tıklaması gerekir.

## Pencere

- `Window:CreateTab("Settings")` veya `{Name = "Settings"}`
- `Tab:CreateSection("General")`, `Tab:Select()`
- `Window:Show()`, `Hide()`, `Toggle()`, `Destroy()`
- `Window:SetStatus("Ready")`
- `Window:Notify({Title = "Hello", Content = "Ready", Duration = 4})`

Başlık alanı fare ve dokunma ile sürüklenebilir. Sarı simge gizler; kırmızı simge pencereyi ve bağlantılarını kaldırır. Alttaki buton veya RightControl tekrar açar. Ekran boyutuna göre otomatik ölçekleme ve yatay sekme kaydırması vardır. Dar telefon ekranlarında masaüstü düzeni küçülür; ayrı mobil düzen henüz yoktur.

Tema anahtarları: `Background`, `Sidebar`, `Surface`, `Hover`, `Border`, `Text`, `Muted`, `Accent`. Tema oluşturma sırasında verilir. Color picker, ikon alanları ve dinamik tema değiştirme sonraki sürüm kapsamındadır.

Örnek hub yalnızca arayüz davranışını gösterir; oyun otomasyonu veya sunucu değiştirme işlemi içermez. Bu işlemleri kendi callback'lerinize bağlayın.

## Studio kontrol listesi

Play modunda sekmeleri değiştirin; toggle, slider, dropdown ve input değerlerini kontrol edin. Açık dropdown ile sayfayı kaydırın. Input odaktayken RightControl'ün pencereyi kapatmadığını doğrulayın. Pencereyi sürükleyin, gizleyip açın, ekran boyutunu değiştirin. Device Emulator ile dokunmatik slider ve sürüklemeyi deneyin. Son olarak kırmızı kapatma düğmesinin UI'yi kaldırdığını kontrol edin.
