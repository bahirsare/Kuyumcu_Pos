import time
import firebase_admin
from firebase_admin import credentials, firestore
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import StaleElementReferenceException

# 1. Firebase Bağlantısı
if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("Bot başlatılıyor (Darphane İşçilik Tablosu Modu)...")

# 2. Tarayıcı Ayarları
options = uc.ChromeOptions()
options.add_argument("--no-first-run")
options.add_argument("--password-store=basic")
options.add_argument("--window-size=1280,800")

driver = uc.Chrome(options=options, use_subprocess=True)

TARGET_URL = "https://canlipiyasalar.haremaltin.com/"

# --- TABLO YAPILANDIRMASI ---
# Bu tabloda satır ismini bulup, o satırdaki 4 ayrı sütunu okuyacağız.
# Yapı: [0]İsim - [1]YeniAlış - [2]YeniSatış - [3]EskiAlış - [4]EskiSatış

URUNLER = [
    {"sitedeki_ad": "Çeyrek",   "db_ad": "Ceyrek"},
    {"sitedeki_ad": "Yarım",    "db_ad": "Yarim"},
    {"sitedeki_ad": "Tek",      "db_ad": "Tam"},      # Sitede Tek -> Bizde Tam
    {"sitedeki_ad": "Ata",      "db_ad": "Ata"},
    {"sitedeki_ad": "Gremese",  "db_ad": "Gremese"},
    {"sitedeki_ad": "Ata 5'li", "db_ad": "Ata_5li"}
]

# --- KORUMA AYARLARI ---
MAX_HATA_SINIRI = 5
REFRESH_SURESI = 1800 
son_yenileme_zamani = time.time()
hata_sayaci = 0

try:
    driver.get(TARGET_URL)
    print("Site açıldı. Veriler bekleniyor...")
    time.sleep(10)

    while True:
        simdiki_zaman = time.time()

        # 1. Bakım (Refresh)
        if simdiki_zaman - son_yenileme_zamani > REFRESH_SURESI:
            print("⏳ Bakım zamanı: Sayfa yenileniyor...")
            try:
                driver.refresh()
                time.sleep(10)
                son_yenileme_zamani = simdiki_zaman
                hata_sayaci = 0
            except:
                pass

        # 2. Hata Koruması
        if hata_sayaci >= MAX_HATA_SINIRI:
            print("⚠️ Çok hata alındı, sayfa yeniden yükleniyor...")
            try:
                driver.get(TARGET_URL)
                time.sleep(10)
                hata_sayaci = 0
            except:
                time.sleep(10)
                continue

        try:
            wait = WebDriverWait(driver, 20, ignored_exceptions=[StaleElementReferenceException])
            
            # --- A) HAS ALTIN (Ana Fiyat) ---
            # Bunu hala çekiyoruz çünkü hesaplamada lazım olabilir
            has_satir = wait.until(
                EC.presence_of_element_located((By.XPATH, "//tr[.//a[contains(text(), 'HAS')]]"))
            )
            has_sutunlar = has_satir.find_elements(By.TAG_NAME, "td")
            
            if len(has_sutunlar) >= 3:
                has_alis = float(has_sutunlar[1].text.strip().replace('.', '').replace(',', '.'))
                has_satis = float(has_sutunlar[2].text.strip().replace('.', '').replace(',', '.'))
                
                print(f"🟡 HAS ALTIN: {has_alis} - {has_satis}")
                
                db.collection('piyasa').document('canli').set({
                    'alis': has_alis,
                    'satis': has_satis,
                    'tarih': firestore.SERVER_TIMESTAMP
                })

            # --- B) DARPHANE İŞÇİLİK TABLOSU ---
            iscilik_verileri = {}
            
            for urun in URUNLER:
                try:
                    isim = urun["sitedeki_ad"]
                    # Sitedeki isme (örn: Çeyrek) sahip satırı bul
                    # XPath: İçinde 'Çeyrek' yazan 'a' etiketine sahip 'tr'
                    satir = driver.find_element(By.XPATH, f"//tr[td/a[contains(text(), \"{isim}\")]]")
                    
                    sutunlar = satir.find_elements(By.TAG_NAME, "td")
                    
                    # Senin attığın HTML'e göre sütunlar şöyle:
                    # [0]: İsim (Link)
                    # [1]: Yeni Alış
                    # [2]: Yeni Satış
                    # [3]: Eski Alış
                    # [4]: Eski Satış
                    
                    if len(sutunlar) >= 5:
                        # Verileri temizle (virgül -> nokta)
                        yeni_alis = float(sutunlar[1].text.strip().replace('.', '').replace(',', '.'))
                        yeni_satis = float(sutunlar[2].text.strip().replace('.', '').replace(',', '.'))
                        
                        eski_alis = float(sutunlar[3].text.strip().replace('.', '').replace(',', '.'))
                        eski_satis = float(sutunlar[4].text.strip().replace('.', '').replace(',', '.'))
                        
                        db_key = urun["db_ad"]
                        
                        # Veritabanına hem Yeni hem Eski olarak kaydediyoruz
                        iscilik_verileri[f"Yeni_{db_key}"] = {'alis': yeni_alis, 'satis': yeni_satis}
                        iscilik_verileri[f"Eski_{db_key}"] = {'alis': eski_alis, 'satis': eski_satis}
                        
                        print(f"   🔨 {db_key} -> Yeni: {yeni_alis}/{yeni_satis} | Eski: {eski_alis}/{eski_satis}")

                except Exception as row_e:
                    # O an o ürünü bulamazsa devam et
                    pass

            if iscilik_verileri:
                iscilik_verileri['tarih'] = firestore.SERVER_TIMESTAMP
                db.collection('piyasa').document('iscilik').set(iscilik_verileri)

            hata_sayaci = 0

        except Exception as e:
            hata_sayaci += 1
            print(f"Hata ({hata_sayaci}): {str(e).splitlines()[0]}")
            if "no such window" in str(e):
                break

        time.sleep(5)

except KeyboardInterrupt:
    print("\nBot durduruldu.")
    driver.quit()
