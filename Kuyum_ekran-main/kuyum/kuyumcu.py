import time
import os  # <--- EKLENDİ: Dosya yolunu bulmak için
import sys # <--- EKLENDİ: Hata yakalamak için
import firebase_admin
from firebase_admin import credentials, firestore
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import StaleElementReferenceException

# --- ÖNEMLİ AYAR: Çift tıklayınca dosya yolunu bulma ---
# Kodun çalıştığı klasörü otomatik bulur
calisma_dizini = os.path.dirname(os.path.abspath(__file__))
json_dosya_yolu = os.path.join(calisma_dizini, "serviceAccountKey.json")

print(f"Bot Başlatılıyor... \nÇalışma Dizini: {calisma_dizini}")

# 1. Firebase Bağlantısı
try:
    if not firebase_admin._apps:
        # Artık dosya yolunu garantiye aldık
        cred = credentials.Certificate(json_dosya_yolu)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
except Exception as e:
    print("\n!!! HATA: Firebase dosyası bulunamadı veya hatalı !!!")
    print(f"Aranan yol: {json_dosya_yolu}")
    print(f"Hata detayı: {e}")
    input("\nKapatmak için Enter'a basın...") # Pencere hemen kapanmasın
    sys.exit()

print("Veritabanı bağlantısı başarılı. Tarayıcı açılıyor...")

# 2. Tarayıcı Ayarları
options = uc.ChromeOptions()
options.add_argument("--no-first-run")
options.add_argument("--password-store=basic")
options.add_argument("--window-size=1280,800")

try:
    driver = uc.Chrome(options=options, use_subprocess=True, version_main=143)
except Exception as e:
    print(f"\nChrome açılırken hata oluştu: {e}")
    input("Kapatmak için Enter'a basın...")
    sys.exit()

TARGET_URL = "https://canlipiyasalar.haremaltin.com/"

# --- TABLO YAPILANDIRMASI ---
URUNLER = [
    {"sitedeki_ad": "Çeyrek",   "db_ad": "Ceyrek"},
    {"sitedeki_ad": "Yarım",    "db_ad": "Yarim"},
    {"sitedeki_ad": "Tek",      "db_ad": "Tam"},
    {"sitedeki_ad": "Ata",      "db_ad": "Ata"},
    {"sitedeki_ad": "Gremese",  "db_ad": "Gremese"},
    {"sitedeki_ad": "Ata 5'li", "db_ad": "Ata_5li"}
]

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

        if simdiki_zaman - son_yenileme_zamani > REFRESH_SURESI:
            print("⏳ Bakım zamanı: Sayfa yenileniyor...")
            try:
                driver.refresh()
                time.sleep(10)
                son_yenileme_zamani = simdiki_zaman
                hata_sayaci = 0
            except:
                pass

        if hata_sayaci >= MAX_HATA_SINIRI:
            print("⚠️ KRİTİK HATA LİMİTİ! Script tamamen kapatılıyor (Watchdog yeniden başlatacak)...")
            # Driver'ı kapat ve programı tamamen sonlandır (sys.exit)
            try:
                driver.quit()
            except:
                pass
            import sys
            sys.exit(1)

        try:
            wait = WebDriverWait(driver, 20, ignored_exceptions=[StaleElementReferenceException])
            
            # --- HAS ALTIN ---
            has_satir = wait.until(EC.presence_of_element_located((By.XPATH, "//tr[.//a[contains(text(), 'HAS')]]")))
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

            # --- İŞÇİLİK ---
            iscilik_verileri = {}
            for urun in URUNLER:
                try:
                    isim = urun["sitedeki_ad"]
                    satir = driver.find_element(By.XPATH, f"//tr[td/a[contains(text(), \"{isim}\")]]")
                    sutunlar = satir.find_elements(By.TAG_NAME, "td")
                    
                    if len(sutunlar) >= 5:
                        yeni_alis = float(sutunlar[1].text.strip().replace('.', '').replace(',', '.'))
                        yeni_satis = float(sutunlar[2].text.strip().replace('.', '').replace(',', '.'))
                        eski_alis = float(sutunlar[3].text.strip().replace('.', '').replace(',', '.'))
                        eski_satis = float(sutunlar[4].text.strip().replace('.', '').replace(',', '.'))
                        
                        db_key = urun["db_ad"]
                        iscilik_verileri[f"Yeni_{db_key}"] = {'alis': yeni_alis, 'satis': yeni_satis}
                        iscilik_verileri[f"Eski_{db_key}"] = {'alis': eski_alis, 'satis': eski_satis}
                        print(f"   🔨 {db_key} -> Yeni: {yeni_alis} | Eski: {eski_alis}")

                except:
                    pass

            if iscilik_verileri:
                iscilik_verileri['tarih'] = firestore.SERVER_TIMESTAMP
                db.collection('piyasa').document('iscilik').set(iscilik_verileri)

            hata_sayaci = 0

        except Exception as e:
            hata_sayaci += 1
            print(f"Hata ({hata_sayaci}): {str(e).splitlines()[0]}")
            
            # Eğer Session Invalid hatası geldiyse bekleme, direkt patlat ki yeniden başlasın
            if "invalid session" in str(e).lower() or "no such window" in str(e).lower():
                print("💥 SESSION ÖLDÜ! Acil yeniden başlatma isteniyor...")
                import sys
                sys.exit(1)

        time.sleep(5)
except KeyboardInterrupt:
    print("\nBot durduruldu.")
    
except Exception as genel_hata:
    print(f"\nBEKLENMEYEN ÇÖKME: {genel_hata}")
    # ÖNEMLİ: Buradaki input() kaldırıldı.
    # Program direkt kapansın ki BAT dosyası yeniden açsın.
    import sys
    sys.exit(1)
