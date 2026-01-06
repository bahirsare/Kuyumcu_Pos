import time
import sys
try:
    import firebase_admin
    from firebase_admin import credentials
    from firebase_admin import firestore
    from selenium import webdriver
    from selenium.webdriver.chrome.service import Service
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.common.by import By
    from webdriver_manager.chrome import ChromeDriverManager
except ImportError:
    print("Kutuphaneler eksik! (pip install firebase-admin selenium webdriver-manager)")
    sys.exit()

try:
    # serviceAccountKey.json dosyasının bu script ile aynı klasörde olduğundan emin ol
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print(">>> Firebase Baglandi!")
except Exception as e:
    print("Baglanti Hatasi: " + str(e))
    sys.exit()

URL = "https://canlipiyasalar.haremaltin.com"

def safe_float(text):
    try:
        return float(text.strip().replace(",", "."))
    except:
        return 0.0

def motoru_calistir():
    chrome_options = Options()
    chrome_options.add_argument("--headless=new") 
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--log-level=3")
    
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=chrome_options)
    
    print(">>> Bot calisiyor (Harem Isçilik Tablosu)...")
    
    while True:
        try:
            # Manuel mod kontrolü
            doc_ref = db.collection("piyasa").document("canli")
            doc = doc_ref.get()
            if doc.exists and doc.to_dict().get("mod") == "manuel":
                time.sleep(3)
                continue

            driver.get(URL)
            time.sleep(3) # Sayfanın yüklenmesini bekle

            # --- GÜNCELLEME BURADA YAPILDI ---
            # 'tarih': firestore.SERVER_TIMESTAMP ekledik.
            veri_paketi = {
                "guncelleme": time.strftime('%H:%M:%S'),
                "mod": "otomatik",
                "tarih": firestore.SERVER_TIMESTAMP 
            }

            # 1. Ana Tablodan HAS ALTIN Çekme
            rows = driver.find_elements(By.TAG_NAME, "tr")
            for r in rows:
                try:
                    cols = r.find_elements(By.TAG_NAME, "td")
                    if len(cols) < 3: continue
                    isim = cols[0].text.upper()
                    # HAS ALTIN satırını bul (GRAM ALTIN ile karışmasın diye kontrol)
                    if "HAS" in isim and "ALTIN" in isim and "GRAM" not in isim:
                        
                        a_txt = cols[1].text.replace(".", "").replace(",", ".")
                        s_txt = cols[2].text.replace(".", "").replace(",", ".")
                        veri_paketi["alis"] = float(a_txt)
                        veri_paketi["satis"] = float(s_txt)
                        break
                except: continue

            # 2. İşçilik Tablosundan (Çeyrek, Yarım vb.) Veri Çekme
            boxes = driver.find_elements(By.CLASS_NAME, "box")
            target_table = None
            
            for box in boxes:
                if "Darphane İşçilik Fiyatları (Has)" in box.text:
                    target_table = box.find_element(By.TAG_NAME, "table")
                    break
            
            if target_table:
                tr_list = target_table.find_elements(By.TAG_NAME, "tr")
                
                for tr in tr_list:
                    tds = tr.find_elements(By.TAG_NAME, "td")
                    if len(tds) < 5: continue
                    
                    row_name = tds[0].text.strip() 
                    
                    # Sütunlar: İsim | Yeni Alış | Yeni Satış | Eski Alış | Eski Satış
                    y_alis = safe_float(tds[1].text)
                    y_satis = safe_float(tds[2].text)
                    e_alis = safe_float(tds[3].text)
                    e_satis = safe_float(tds[4].text)

                    # Verileri eşle
                    if "Çeyrek" in row_name:
                        veri_paketi["y_ceyrek_alis_has"] = y_alis
                        veri_paketi["y_ceyrek_satis_has"] = y_satis
                        veri_paketi["e_ceyrek_alis_has"] = e_alis
                        veri_paketi["e_ceyrek_satis_has"] = e_satis
                    elif "Yarım" in row_name:
                        veri_paketi["y_yarim_alis_has"] = y_alis
                        veri_paketi["y_yarim_satis_has"] = y_satis
                        veri_paketi["e_yarim_alis_has"] = e_alis
                        veri_paketi["e_yarim_satis_has"] = e_satis
                    elif "Tek" in row_name: # Tam Altın genelde "Tek" geçer
                        veri_paketi["y_tam_alis_has"] = y_alis
                        veri_paketi["y_tam_satis_has"] = y_satis
                        veri_paketi["e_tam_alis_has"] = e_alis
                        veri_paketi["e_tam_satis_has"] = e_satis
                    elif "Ata" in row_name and "5" not in row_name:
                        veri_paketi["y_ata_alis_has"] = y_alis
                        veri_paketi["y_ata_satis_has"] = y_satis
                        veri_paketi["e_ata_alis_has"] = e_alis
                        veri_paketi["e_ata_satis_has"] = e_satis
                    elif "Gremese" in row_name:
                        veri_paketi["y_gremse_alis_has"] = y_alis
                        veri_paketi["y_gremse_satis_has"] = y_satis
                        veri_paketi["e_gremse_alis_has"] = e_alis
                        veri_paketi["e_gremse_satis_has"] = e_satis

            # Veriyi Firebase'e Bas
            if "alis" in veri_paketi:
                doc_ref.set(veri_paketi, merge=True)
                print(f"[{time.strftime('%H:%M:%S')}] Guncellendi -> Has: {veri_paketi['alis']} | Tarih Damgasi Eklendi")
                
        except Exception as e:
            print("Hata: " + str(e))
            
        time.sleep(10) # Harem'i çok yormamak için süreyi 10 saniye yaptım, istersen düşürürsün.

if __name__ == "__main__":
    motoru_calistir()
