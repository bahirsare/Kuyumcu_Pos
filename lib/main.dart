import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const BaslaticiUygulama());   
}
class BaslaticiUygulama extends StatelessWidget {
  const BaslaticiUygulama({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bigbos Eren Kuyumculuk',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B2631)),
        scaffoldBackgroundColor: const Color(0xFFEDEFF5),
      ),
      home: const AcilisEkrani(), // İlk burası açılacak
    );
  }
}
class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});

  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani> {
  String _durum = "Sistem Başlatılıyor...";
  String _hataDetayi="";
  bool _hataVar = false;

  @override
  void initState() {
    super.initState();
    _guvenliBaslat();
  }

Future<void> _guvenliBaslat() async {
    try {
      setState(() => _durum = "Sunucuya Bağlanılıyor...");
      
      // --- WEB / MOBİL AYRIMI (BURASI DEĞİŞTİ) ---
      if (kIsWeb) {
        // WEB İÇİN BAŞLATMA
        // Bu bilgileri Firebase Console -> Project Settings -> General -> Your Apps (Web) kısmından alacaksın.
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyBvfN6lu26VOul4R9PiowpIGWkZ4LTrgJM",
            authDomain: "kuyumcu-75b22.firebaseapp.com",
            projectId: "kuyumcu-75b22",
            storageBucket: "kuyumcu-75b22.firebasestorage.app",
            messagingSenderId: "905664498738",
            appId: "1:905664498738:web:8540cb5da77e847973c02b",
            measurementId: "G-14611N1PXZ"

          ),
        );
      } else {
        // MOBİL (ANDROID/IOS) İÇİN BAŞLATMA
        await Firebase.initializeApp();
      }
      // -------------------------------------------

      setState(() => _durum = "Kimlik Doğrulanıyor...");
      await DB.baslat(); // Hafızadaki kodu okur

      // HEDEF: Varsayılan olarak Giriş Ekranı
      Widget hedefEkran = const LoginScreen();

      // Eğer hafızada bir kod varsa (Örn: eren_kuyumculuk)
      if (DB.magazaKodu.isNotEmpty) {
        print("LOG: Hafızada mağaza bulundu: ${DB.magazaKodu}. Kontrol ediliyor...");
        
        try {
          // Veritabanına sor: Bu mağaza gerçekten var mı?
          var doc = await FirebaseFirestore.instance
              .collection('magazalar')
              .doc(DB.magazaKodu)
              .collection('ayarlar')
              .doc('genel')
              .get();

          if (doc.exists) {
            // VAR: Harika, içeri al.
            print("LOG: Mağaza doğrulandı.");
            hedefEkran = const PosScreen();
          } else {
            // YOK: Silinmiş! ACİL DURUM PROSEDÜRÜ
            print("LOG: Mağaza veritabanında YOK! Oturum zorla kapatılıyor...");
            
            // 1. Hafızayı temizle
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear(); // Hepsini sil
            
            // 2. RAM'i temizle
            DB.magazaKodu = "";
            
            // 3. Hedef zaten LoginScreen idi, öyle kalsın.
          }
        } catch (e) {
          print("LOG: Bağlantı hatası ($e). Güvenlik için çıkış yapılıyor.");
          // İnternet yoksa veya hata varsa riske atma, çıkış yap.
          await DB.cikisYap();
          hedefEkran = const LoginScreen();
        }
      }

      // YÖNLENDİRME
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => hedefEkran),
          (route) => false // Geri tuşunu iptal et, geçmişi sil
        );
      }

    } catch (e) {
      setState(() {
        _hataVar = true;
        _durum = "KRİTİK HATA: $e";
        _hataDetayi = e.toString();
      });
    }
  }
  
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2631),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo veya İkon
              const Icon(Icons.diamond, size: 80, color: Color(0xFFD4AF37)),
              const SizedBox(height: 20),
              
              const Text(
                "EREN KUYUMCULUK", 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 40),

              // Hata varsa Kırmızı Yazı, Yoksa Dönen Tekerlek
              if (_hataVar)
                Text(_durum, style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center)
              else ...[
                const CircularProgressIndicator(color: Color(0xFFD4AF37)),
                const SizedBox(height: 20),
                Text(_durum, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 40),
              
              // MANUEL SIFIRLAMA BUTONU
              TextButton.icon(
                onPressed: () async {
                  print("Manuel sıfırlama yapılıyor...");
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear(); // Hafızayı sil
                  DB.magazaKodu = ""; // Değişkeni sil
                  
                  // Uygulamayı yeniden başlatır gibi Login'e at
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (c) => const LoginScreen()), 
                    (route) => false
                  );
                },
                icon: const Icon(Icons.delete_forever, color: Colors.white54),
                label: const Text("Önbelleği Temizle ve Çıkış Yap", style: TextStyle(color: Colors.white54)),
              ),
              ]
            ],
          ),
        ),
      ),
    );
  }

}
class DB {
  // Artık sabit değil, boş başlıyor
  static String magazaKodu = ""; 

  // Uygulama açılırken hafızadan kodu okuyacak fonksiyon
  static Future<void> baslat() async {
    final prefs = await SharedPreferences.getInstance();
    magazaKodu = prefs.getString('magaza_kodu') ?? "";
  }

  // Giriş yapınca kodu hafızaya kaydedecek fonksiyon
  static Future<void> girisYap(String kod) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('magaza_kodu', kod);
    magazaKodu = kod;
  }

  // Çıkış yapınca hafızayı silecek fonksiyon
  static Future<void> cikisYap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('magaza_kodu');
    magazaKodu = "";
  }

  static CollectionReference ref(String koleksiyonAdi) {
    if (magazaKodu.isEmpty) throw Exception("Mağaza Kodu Bulunamadı!");
    return FirebaseFirestore.instance
        .collection('magazalar')
        .doc(magazaKodu)
        .collection(koleksiyonAdi);
  }

  static DocumentReference piyasaRef() {
    return FirebaseFirestore.instance.collection('piyasa').doc('canli');
  }
}
// --- 1. RESPONSIVE WRAPPER (ANA İSKELET) ---
class ResponsiveAnaSablon extends StatelessWidget {
  final Widget child;
  final AppBar? appBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  const ResponsiveAnaSablon({
    Key? key,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        backgroundColor: const Color(0xFFEDEFF5),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
// --- 2. VERİ MODELİ ---
class SatisSatiri {
  String id;
  String tur;
  String urunAdi;
  double gram;
  double deger;
  double? eskiDeger;
  bool isManuel;
  bool isHurda;

  SatisSatiri({
    required this.id,
    required this.tur,
    required this.urunAdi,
    this.gram = 0.0,
    this.deger = 0.0,
    this.eskiDeger,
    this.isManuel = false,
    this.isHurda = false,
  });
}

// --- 3. ANA EKRAN (POS) ---
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Piyasa Verileri
  double _canliHasAlis = 0;
  double _canliHasSatis = 0;
  double _kilitliHasAlis = 0;

  // Durumlar
  bool _fiyatSabit = false;
  bool _sunumModu = false;
  bool _toptanModu = false;
  bool _veriGuncelMi = false;
  bool _sepetAcik = false;
  bool _milyemElleDegisti = false;

  // Anlık Hesaplamalar
  double _formAnlikTutar = 0;
  double _hurdaAnlikTutar = 0;

  // Hurda Seçimleri (DB'den gelecek)
  String? _hurdaSecilenTur; 
  Map<String, double> _hurdaAlisMilyemleri = {}; 
  Map<String, double> _hurdaHasMilyemleri = {};

  // Firebase Verileri
  Map<String, dynamic> _ayarlar = {};
  List<dynamic> _toptanAraliklar = [];
  Map<String, dynamic> _piyasaVerileri = {};
  double _guvenliDouble(dynamic veri, double varsayilan) {
    if (veri == null) return varsayilan;
    if (veri is int) return veri.toDouble();
    if (veri is double) return veri;
    if (veri is String) return double.tryParse(veri) ?? varsayilan;
    return varsayilan;
  }
  // Sepet ve Kontrolcüler
  final List<SatisSatiri> _sepet = [];
  final TextEditingController _hasSatisManuelController = TextEditingController();
  final TextEditingController _hasAlisManuelController = TextEditingController(); 
  // Takı Formu
  String _formSecilenTur = "std_kolye";
  final TextEditingController _formGramController = TextEditingController();
  final TextEditingController _formMilyemController = TextEditingController();
  final TextEditingController _formFiyatController = TextEditingController();
  // Hurda Formu
  final TextEditingController _hurdaGramController = TextEditingController();
  final TextEditingController _hurdaMilyemController = TextEditingController();

  List<String> _personelListesi = ["Mağaza"];
  String? _secilenPersonel;
  String _firmaAdi = "Default";
  String _adminPin = "1234";    

  final Map<String, String> _urunCesitleri = {
    "std_kolye": "Kolye (14K)",
    "std_kupe": "Küpe (14K)",
    "std_yuzuk": "Yüzük (14K)",
    "std_bileklik": "Bileklik (14K)",
    "std_kelepce": "Kelepçe (14K)",
    "std_set": "Set / Mini Set (14K)",
    "std_kolye_ucu": "Kolye Ucu (14K)",
    "std_zincir": "Zincir (14K)",
    "b22_taki": "22 Ayar Takı",
    "wedding_plain": "Düz Alyans",
    "wedding_pattern": "Kalemli Alyans",
    "b22_ajda": "Ajda (22K)",
    "b22_sarnel": "Şarnel (22K)",
  };

  final List<Map<String, dynamic>> _ziynetTurleri = [
    {'id': 'y_ceyrek', 'ad': 'YENİ ÇEYREK', 'def_has': 1.6350},
    {'id': 'e_ceyrek', 'ad': 'ESKİ ÇEYREK', 'def_has': 1.6100},
    {'id': 'y_yarim',  'ad': 'YENİ YARIM',  'def_has': 3.2700},
    {'id': 'e_yarim',  'ad': 'ESKİ YARIM',  'def_has': 3.2070},
    {'id': 'y_tam',    'ad': 'YENİ TAM',    'def_has': 6.5150},
    {'id': 'e_tam',    'ad': 'ESKİ TAM',    'def_has': 6.4300},
    {'id': 'y_ata',    'ad': 'YENİ ATA',    'def_has': 6.7000},
    {'id': 'e_ata',    'ad': 'ESKİ ATA',    'def_has': 6.6950},
    {'id': 'y_gremse', 'ad': 'YENİ GREMSE', 'def_has': 16.3000},
    {'id': 'e_gremse', 'ad': 'ESKİ GREMSE', 'def_has': 16.1500},
    {'id': 'y_ata5',   'ad': 'ATA BEŞLİ',   'def_has': 33.3500},
    {'id': 'e_ata5',   'ad': 'ESKİ BEŞLİ',  'def_has': 33.1000},
  ];
  final TextEditingController _hasSatisGramController = TextEditingController(text: "1");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _firebaseDinle();
  }

 void _firebaseDinle() {
    // 1. Ayarları Dinle
    DB.ref('ayarlar').doc('genel').snapshots().listen((doc) {
      if (doc.exists) {
        setState(() {
          _ayarlar = doc.data() as Map<String, dynamic>;
          if(_ayarlar.containsKey('firma_adi')) _firmaAdi = _ayarlar['firma_adi'];
          if(_ayarlar.containsKey('admin_pin')) _adminPin = _ayarlar['admin_pin'];
          if (_ayarlar.containsKey('toptan_araliklar')) {
            _toptanAraliklar = List.from(_ayarlar['toptan_araliklar']);
            _toptanAraliklar.sort((a, b) => (a['limit'] as num).compareTo(b['limit'] as num));
          }
          if (_ayarlar.containsKey('personel_listesi')) {
            _personelListesi = List<String>.from(_ayarlar['personel_listesi']);
          }
          _otomatikDegerleriGuncelle();

          // --- DÜZELTME: ALFABETİK SIRALAMA ---
          if (_ayarlar.containsKey('hurda_ayarlari')) {
            Map<String, dynamic> hAyarlar = _ayarlar['hurda_ayarlari'];
            _hurdaAlisMilyemleri.clear();
            _hurdaHasMilyemleri.clear();
            
            // İsimleri alıp A'dan Z'ye sıralıyoruz
            var siraliAnahtarlar = hAyarlar.keys.toList()..sort();

            for (var k in siraliAnahtarlar) {
              List<dynamic> vals = hAyarlar[k]; 
              _hurdaAlisMilyemleri[k] = (vals[0] as num).toDouble();
              _hurdaHasMilyemleri[k] = (vals[1] as num).toDouble();
            }
            
            // Liste dolduysa ve seçim yoksa ilkini seç
            if (_hurdaAlisMilyemleri.isNotEmpty) {
               if (_hurdaSecilenTur == null || !_hurdaAlisMilyemleri.containsKey(_hurdaSecilenTur)) {
                 _hurdaSecilenTur = _hurdaAlisMilyemleri.keys.first;
                 _hurdaMilyemController.text = _hurdaAlisMilyemleri[_hurdaSecilenTur]!.toStringAsFixed(3);
               }
            }
          }
        });
      }
    });

    // 2. Piyasayı Dinle (Burası aynı)
    DB.piyasaRef().snapshots().listen((doc) {
      if (doc.exists) {
        var data = doc.data()!  as Map<String, dynamic>;
        _piyasaVerileri = data ;
        Timestamp? sunucuZamani = data['tarih'];
        bool veriTaze = false;
        bool guvenlikKilidi = false;

        if (sunucuZamani != null) {
          Duration fark = DateTime.now().difference(sunucuZamani.toDate());
          if (fark.inSeconds < 60) { veriTaze = true; } 
          else if (fark.inMinutes >= 3) guvenlikKilidi = true;
        } else { guvenlikKilidi = true; }

       setState(() {
          _veriGuncelMi = veriTaze;
          if (guvenlikKilidi) {
            _canliHasAlis = 0; _canliHasSatis = 0;
            if (!_fiyatSabit) { 
               _hasSatisManuelController.text = ""; 
               _hasAlisManuelController.text = ""; 
               _kilitliHasAlis = 0; 
            }
          } else {
            _canliHasAlis = (data['alis'] as num).toDouble();
            _canliHasSatis = (data['satis'] as num).toDouble();
            if (!_fiyatSabit) {
               // SATIŞ KUTUSU GÜNCELLEME
               double mevcutSatis = double.tryParse(_hasSatisManuelController.text) ?? 0;
               if (mevcutSatis != _canliHasSatis) { _hasSatisManuelController.text = _canliHasSatis.toString(); }
               
               // YENİ: ALIŞ KUTUSU GÜNCELLEME
               double mevcutAlis = double.tryParse(_hasAlisManuelController.text) ?? 0;
               if (mevcutAlis != _canliHasAlis) { _hasAlisManuelController.text = _canliHasAlis.toString(); }

               _kilitliHasAlis = _canliHasAlis;
            }
          }
        });
      }
    });
  }
   // --- HESAPLAMA FONKSİYONLARI ---
  
  // Toptan modu açılınca veya sepet değişince milyemleri günceller
  void _otomatikDegerleriGuncelle() {
    double toplamStdGram = 0;
    if (_toptanModu) {
      for(var s in _sepet) {
        if(s.tur.startsWith("std_")) toplamStdGram += s.gram;
      }
    }
    for (var satir in _sepet) {
      if (!satir.isManuel && !satir.tur.startsWith("ziynet") && !satir.isHurda) {
        double refGram = (_toptanModu && satir.tur.startsWith("std_")) ? toplamStdGram : satir.gram;
        satir.deger = _dinamikMilyemBul(satir.tur, refGram);
      }
    }
  }

  // Ürün türüne ve gramaja göre milyem bulur
  double _dinamikMilyemBul(String tur, double gram) {
    if (_ayarlar.isEmpty) return 0;

    if (tur == "b22_taki") return (_ayarlar['factor_b22_taki'] ?? 0.960).toDouble();
    if (tur == "wedding_plain") return (_ayarlar['factor_wedding_plain'] ?? 0.60).toDouble();
    if (tur == "wedding_pattern") return (_ayarlar['factor_wedding_pattern'] ?? 0.80).toDouble();
    if (tur == "b22_sarnel") return (_ayarlar['factor_b22_bilezik'] ?? 0.940).toDouble();
    if (tur == "b22_ajda" ) return (_ayarlar['factor_b22_ajda'] ?? 0.930).toDouble();

    if (tur.startsWith("std_")) {
      List<dynamic> araliklar = _toptanAraliklar.isNotEmpty ? _toptanAraliklar : [
        {'limit': 5, 'carpan': 0.90},
        {'limit': 10, 'carpan': 0.85},
        {'limit': 15, 'carpan': 0.82},
        {'limit': 25, 'carpan': 0.77},
      ];

      for (var aralik in araliklar) {
        double limit = (aralik['limit'] as num).toDouble();
        double carpan = (aralik['carpan'] as num).toDouble();
        if (gram < limit) return carpan;
      }
      return (_ayarlar['factor_max'] ?? 0.725).toDouble();
    }
    return 0;
  }

  // Bir satırın TL karşılığını hesaplar (Satış veya Hurda)
 double _satirFiyatiHesapla(SatisSatiri satir, double hasFiyat) {
    double sonuc = 0;

    double guncelAlisFiyati = double.tryParse(_hasAlisManuelController.text.replaceAll(',', '.')) ?? 0;

    if (satir.isHurda) {
       // HURDA İSE
       if(satir.tur.contains("ziynet")) {
         sonuc = satir.gram * satir.deger; 
       } else {
         // --- DEĞİŞİKLİK BURADA: Eski değişken yerine guncelAlisFiyati kullandık ---
         sonuc = satir.gram * satir.deger * guncelAlisFiyati; 
       }
    }
    else {
       // SATIŞ İSE
       if (satir.tur.startsWith("ziynet")) {
         sonuc = satir.gram * satir.deger;
       } 
       else if (satir.tur.startsWith("wedding")) {
         sonuc = hasFiyat * (satir.gram * 0.585 + satir.deger);
       }
       else{
         sonuc = hasFiyat * satir.gram * satir.deger;
       } 
    }
    
    // --- BURASI EKLENDİ: YUVARLAMA İŞLEMİ ---
    return sonuc.roundToDouble(); 
  }
  // Ziynet satış fiyatını hesaplar
  double _ziynetBirimFiyatHesapla(Map<String, dynamic> urun) {
    String anahtar = "${urun['id']}_satis_has";
    double hamHasMaliyeti = (_piyasaVerileri.containsKey(anahtar)) ? (_piyasaVerileri[anahtar] as num).toDouble() : urun['def_has'];
    double globalMakas = (_ayarlar['sarrafiye_makas'] ?? 0.02).toDouble();
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    return hasFiyat * (hamHasMaliyeti + globalMakas);
  }

  
// Sepetteki SATILAN ürünlerin maliyetini bulur (Kar hesabı için)
// Sepetteki SATILAN ürünlerin maliyetini bulur (Kar hesabı için)
  double _sepetMaliyetiniBul() {
    double toplamMaliyet = 0;
    
    // 1. KURLARI BELİRLE
    // Hurda için ALIŞ kuru lazım (Müşteriye ödenen para)
    double kurAlis = double.tryParse(_hasAlisManuelController.text.replaceAll(',', '.')) ?? 0;
    
    // Satış ürünlerinin maliyeti için SATIŞ kuru lazım (Yerine koyma maliyeti)
    double kurSatis = double.tryParse(_hasSatisManuelController.text) ?? 0;
    // Eğer satış kuru boşsa (0 ise) mecburen alış kurunu kullan (Güvenlik)
    double aktifMaliyetKuru = (kurSatis > 0) ? kurSatis : kurAlis;

    // Ayarları Çek
    double maliyet14 = _guvenliDouble(_ayarlar['cost_14k'], 0.685);
    double maliyet22 = _guvenliDouble(_ayarlar['cost_22k'], 1.016);
    double maliyetAlyansDuz = _guvenliDouble(_ayarlar['cost_wedding_plain'], 0.20);
    double maliyetAlyansKalemli = _guvenliDouble(_ayarlar['cost_wedding_pattern'], 0.30);

    for(var s in _sepet) {
      if (!s.isHurda) { 
        // --- SATILAN ÜRÜNLER (Hepsi Satış Kurundan Hesaplanacak) ---
        
        if(s.tur.startsWith("ziynet")) {
           // ZİYNET MALİYETİ = Has * Satış Kuru
           String turKod = s.tur.replaceAll("ziynet_", "");
           var urun = _ziynetTurleri.firstWhere((e) => e['id'] == turKod, orElse: () => {});
           if(urun.isNotEmpty) {
              String anahtar = "${urun['id']}_satis_has";
              // Piyasadan gelen has değerini al, yoksa varsayılanı kullan
              double hamHas = (_piyasaVerileri.containsKey(anahtar)) ? (_piyasaVerileri[anahtar] as num).toDouble() : urun['def_has'];
              
              toplamMaliyet += (hamHas * s.gram * aktifMaliyetKuru); 
           }
        } 
        else if (s.tur == "has_paket") {
           // PAKET HAS MALİYETİ = Çarpan * Gram * Satış Kuru
           double limit = _guvenliDouble(_ayarlar['paket_satis_limiti'], 20.0);
           double maliyetCarpan = (s.gram >= limit) 
               ? _guvenliDouble(_ayarlar['paket_maliyet_yuksek'], 1.002)
               : _guvenliDouble(_ayarlar['paket_maliyet'], 1.01);
           
           toplamMaliyet += (s.gram * maliyetCarpan * aktifMaliyetKuru);
        }
        else {
          // TAKI / ALYANS / BİLEZİK MALİYETİ
          double maliyetMilyemi = 0.585; 
          
          if(s.tur.startsWith("b22") || s.tur == "b22_taki") {
            maliyetMilyemi = maliyet22; 
          } else if(s.tur.startsWith("std_")) {
            maliyetMilyemi = maliyet14; 
          } else if(s.tur.startsWith("wedding")) {
              double sabitIsclikHas = (s.tur == "wedding_plain") ? maliyetAlyansDuz : maliyetAlyansKalemli;
              // Alyans Maliyeti: ((Gram * 0.585) + İşçilik) * Satış Kuru
              double urunHasMaliyeti = (s.gram * 0.585) + sabitIsclikHas;
              toplamMaliyet += (urunHasMaliyeti * aktifMaliyetKuru); 
              continue; 
          } 
           
          // Standart Takı Maliyeti: Gram * Milyem * Satış Kuru
          toplamMaliyet += (s.gram * maliyetMilyemi * aktifMaliyetKuru); 
        }
      }
    }
    return toplamMaliyet;
  }
  // Toplam Sepet Tutarı (Hurda Düşülmüş)
  double get _toplamNakit {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double toplam = 0;
    for (var s in _sepet) {
      double tutar = _satirFiyatiHesapla(s, hasFiyat);
      if (s.isHurda) {
        toplam -= tutar; // HURDA İSE ÇIKAR
      } else {
        toplam += tutar; // SATIŞ İSE EKLE
      }
    }
    return toplam;
  }

  // İndirim öncesi tutar (Karşılaştırma için)
  double get _eskiToplamNakit {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double toplam = 0;
    for (var s in _sepet) {
      if (s.isHurda) {
         double alisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;
         toplam -= (s.gram * s.deger * alisFiyati);
      } else {
        if (s.tur.startsWith("ziynet")) {
          toplam += s.deger * s.gram;
        } else {
          double milyem = s.eskiDeger ?? s.deger;
          toplam += s.gram * milyem * hasFiyat;
        }
      }
    }
    return toplam;
  }

  // --- UI YARDIMCILARI ---
 double _safeParse(String val) {
    if (val.isEmpty) return 0;
    // Önce TL ve boşlukları temizle
    String temiz = val.replaceAll('₺', '').replaceAll('TL', '').trim();
    
    // Eğer virgül varsa (Türkçe format: 64.151,78), noktaları sil, virgülü nokta yap
    if (temiz.contains(',')) {
      temiz = temiz.replaceAll('.', '').replaceAll(',', '.');
    } 
    // Sadece nokta varsa ve düz sayı ise dokunma
    
    return double.tryParse(temiz) ?? 0;
  }


  void _miktarDuzenle(SatisSatiri satir) {
    TextEditingController cnt = TextEditingController(text: satir.tur.startsWith("ziynet") ? satir.gram.toInt().toString() : satir.gram.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${satir.urunAdi} Düzenle"),
        content: TextField(
          controller: cnt,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: "Adet/Gr"),
          onSubmitted: (val) { _miktarKaydet(satir, val); Navigator.pop(context); },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(onPressed: () { _miktarKaydet(satir, cnt.text); Navigator.pop(context); }, child: const Text("Güncelle"))
        ],
      ),
    );
  }

  void _miktarKaydet(SatisSatiri satir, String val) {
    setState(() {
      double yeniMiktar = double.tryParse(val.replaceAll(',', '.')) ?? 0;
      if (yeniMiktar > 0) {
        satir.gram = yeniMiktar;
        _otomatikDegerleriGuncelle();
      }
    });
  }

 void _hurdaHesapla() {
    double gr = double.tryParse(_hurdaGramController.text.replaceAll(',', '.')) ?? 0;
    double milyem = double.tryParse(_hurdaMilyemController.text.replaceAll(',', '.')) ?? 0;
    
    
    double hasAlis = double.tryParse(_hasAlisManuelController.text.replaceAll(',', '.')) ?? 0;
    
    if (gr > 0 && milyem > 0 && hasAlis > 0) {
      setState(() {
        _hurdaAnlikTutar = (gr * milyem * hasAlis).roundToDouble();
      });
    } else {
      setState(() => _hurdaAnlikTutar = 0);
    }
  }

void _formHesapla(double gram, double milyem) {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    
    // 1. Fiyatı hesapla
    SatisSatiri temp = SatisSatiri(id: "temp", tur: _formSecilenTur, urunAdi: "", gram: gram, deger: milyem);
    double tutar = _satirFiyatiHesapla(temp, hasFiyat);
    
    setState(() {
       _formAnlikTutar = tutar;
       
       // --- DÜZELTME BURADA ---
       // Eğer kullanıcı şu an fiyat kutusunun içine kendisi yazı YAZMIYORSA,
       // biz otomatik olarak hesaplanan tutarı kutuya yazıyoruz.
       if (!_formFiyatController.selection.isValid || _formFiyatController.text.isEmpty) {
          
          // Estetik düzeltme: Sonu .00 ise sil (24500.00 -> 24500)
          String yazilacak = tutar.toStringAsFixed(2);
          if(yazilacak.endsWith(".00")) yazilacak = yazilacak.substring(0, yazilacak.length - 3);
          
          // Kutunun içini doldur
          _formFiyatController.text = yazilacak;
       }
    });
  } void _sifreSorVeGirisYap() {
    TextEditingController pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yönetici Girişi"),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.lock), hintText: "****"),
          onSubmitted: (val) {
            if(val == _adminPin) { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel())); }
            else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı Şifre!"), backgroundColor: Colors.red)); }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              if(pinCtrl.text == _adminPin) {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı Şifre!"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Giriş"),
          )
        ],
      ),
    );
  
 
  }
  // --- ANA BUILD ---
 @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 0);
    double ekrandakiFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double fark = ekrandakiFiyat - _canliHasSatis;

    return ResponsiveAnaSablon(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_firmaAdi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        ),
        backgroundColor: const Color(0xFF1B2631),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _veriGuncelMi ? Colors.green : Colors.red, width: 1)
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: _veriGuncelMi ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 4),
                Text(_veriGuncelMi ? "CANLI" : "ESKİ", style: TextStyle(color: _veriGuncelMi ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))
              ],
            ),
          ),
          IconButton(icon: Icon(_sunumModu ? Icons.visibility_off : Icons.visibility, color: _sunumModu ? Colors.orange : Colors.white), onPressed: () => setState(() => _sunumModu = !_sunumModu)),
          IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: () => _gecmisSatislariGoster(context, fmt)),
          
          IconButton(icon: const Icon(Icons.admin_panel_settings, color: Colors.white70), onPressed: _sifreSorVeGirisYap)
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              if(!_sunumModu)
              // DÜZELTME 1: Sağ/Sol boşlukları kaldırmak için padding'i 0 yaptık
              Container(
                width: double.infinity, // Tam genişlik
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0), 
                color: const Color(0xFF212F3C),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _fiyatKutusu("HAS ALIŞ", _kilitliHasAlis.toStringAsFixed(2), Colors.orangeAccent, controller: _hasAlisManuelController, readOnly: false),
                          const SizedBox(width: 20),
                          _fiyatKutusu("HAS SATIŞ", "", const Color(0xFF2ECC71), controller: _hasSatisManuelController),
                          const SizedBox(width: 10),
                          Column(children: [
                            Transform.scale(scale: 1.3, child: Checkbox(
                              value: _fiyatSabit, activeColor: Colors.red, side: const BorderSide(color: Colors.white54, width: 2),
                              onChanged: (val) { 
                                setState(() { 
                                  _fiyatSabit = val!; 
                                  if (!_fiyatSabit) { 
                                    _hasSatisManuelController.text = _canliHasSatis.toString(); 
                                    _hasAlisManuelController.text = _canliHasAlis.toString();
                                    _kilitliHasAlis = _canliHasAlis; 
                                  } else {
                                    _kilitliHasAlis = double.tryParse(_hasAlisManuelController.text) ?? _canliHasAlis;
                                  }
                                }); 
                              },
                            )),
                            const Text("SABİTLE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_fiyatSabit && fark.abs() > 10 && !_sunumModu)
                Container(width: double.infinity, color: Colors.redAccent, padding: const EdgeInsets.all(5), child: Center(child: Text("DİKKAT! PİYASA FARKLI (${fark.toStringAsFixed(2)})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),

              Container(
                color: const Color(0xFF1B2631),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFD4AF37),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFFD4AF37),
                  tabs: const [Tab(text: "TAKI"), Tab(text: "ZİYNET"), Tab(text: "HURDA")],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTakiFormu(fmt),
                    _buildZiynetGrid(fmt),
                    _buildHurdaFormu(fmt),
                  ],
                ),
              ),
              const SizedBox(height: 70),
            ],
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _sepetAcik ? 500 : 70,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _sepetAcik = !_sepetAcik),
                    child: Container(
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Color(0xFF27AE60),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_basket, color: Colors.white),
                          const SizedBox(width: 10),
                          Text("SEPET (${_sepet.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),

                          const Spacer(),

                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_eskiToplamNakit > _toplamNakit + 1) ...[
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        fmt.format(_eskiToplamNakit),
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, decoration: TextDecoration.lineThrough, decorationColor: Colors.white70),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          "%${((1 - (_toplamNakit / _eskiToplamNakit)) * 100).toStringAsFixed(0)} İND.",
                                          style: const TextStyle(color: Color(0xFF27AE60), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      fmt.format(_toplamNakit),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),
                          Icon(_sepetAcik ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white, size: 30),
                        ],
                      ),
                    ),
                  ),

                  if (_sepetAcik)
                    Expanded(
                      child: Column(
                        children: [
                          if (_sepet.isNotEmpty && _sepet.any((s) => s.tur.startsWith("std_")))
                            _sepetIciToptanButonu(),
                          
                          Expanded(
                            child: _sepet.isEmpty
                            ? const Center(child: Text("Sepet Boş", style: TextStyle(fontSize: 18, color: Colors.grey)))
                            : ListView.separated(
                                padding: const EdgeInsets.all(10),
                                itemCount: _sepet.length,
                                separatorBuilder: (c,i) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  var s = _sepet[index];
                                  bool hurdaMi = s.isHurda; 
                                  // Ziynet kontrolünü genişlettik:
                                  bool ziynetMi = s.tur.startsWith("ziynet") || s.tur.contains("ziynet");
                                  double guncelKur = double.tryParse(_hasSatisManuelController.text) ?? 0;

                                  // --- FİYAT GÖSTERİM DÜZELTMESİ ---
                                  double guncelTutar;
                                  if (hurdaMi) {
                                       // Eğer hurda ZİYNET ise: Adet * Birim Fiyat
                                       if(ziynetMi) {
                                          guncelTutar = s.gram * s.deger; 
                                       } else {
                                          // Hurda TAKI/HAS ise: Gram * Milyem * Has Alış Fiyatı
                                          double alisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;
                                          guncelTutar = s.gram * s.deger * alisFiyati; 
                                       }
                                  } else {
                                       // NORMAL SATIŞ
                                       guncelTutar = ziynetMi ? (s.deger * s.gram) : (s.gram * s.deger * guncelKur);
                                  }

                                  double? eskiTutar;
                                  if (s.eskiDeger != null && s.eskiDeger != s.deger && !ziynetMi && !hurdaMi) {
                                    eskiTutar = s.gram * s.eskiDeger! * guncelKur;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    color: hurdaMi ? Colors.red.shade50 : (index % 2 == 0 ? Colors.white : Colors.grey.shade50),
                                    child: Row(
                                      children: [
                                        // İKON
                                        hurdaMi 
                                          ? const Icon(Icons.recycling, color: Colors.red, size: 28) 
                                          : (ziynetMi ? const Icon(Icons.monetization_on, color: Colors.orange, size: 28) : const Icon(Icons.diamond, color: Colors.blue, size: 28)),
                                        const SizedBox(width: 10),

                                        // İSİM VE MİLYEM
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(s.urunAdi, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: hurdaMi ? Colors.red : Colors.black)),
                                              if (!_sunumModu && !ziynetMi && !hurdaMi)
                                                Row(
                                                  children: [
                                                      if(s.eskiDeger != null && s.eskiDeger != s.deger) ...[
                                                        Text(s.eskiDeger!.toStringAsFixed(3), style: const TextStyle(fontSize: 11, color: Colors.red, decoration: TextDecoration.lineThrough)),
                                                        const Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                                                      ],
                                                      Text(s.deger.toStringAsFixed(3), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: (s.eskiDeger != null && s.eskiDeger != s.deger) ? Colors.green : Colors.grey.shade700)),
                                                    ],
                                                ),
                                            ],
                                          ),
                                        ),

                                        // --- ADET / GRAM DÜZELTMESİ ---
                                        InkWell(
                                          onTap: () => _miktarDuzenle(s),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                            child: Text(
                                              // BURASI ÖNEMLİ: Ziynet ise "Ad" yazar
                                              ziynetMi ? "${s.gram.toInt()} Ad" : "${s.gram} Gr",
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // FİYAT GÖSTERİMİ
                                        SizedBox(
                                          width: 90,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (eskiTutar != null)
                                                 FittedBox(fit: BoxFit.scaleDown, child: Text(fmt.format(eskiTutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red, decoration: TextDecoration.lineThrough))),
                                              
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  hurdaMi ? "- ${fmt.format(guncelTutar)}" : fmt.format(guncelTutar),
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: hurdaMi ? Colors.red : (eskiTutar != null ? const Color(0xFF27AE60) : Colors.black)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // SİL BUTONU
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                          onPressed: () => setState(() => _sepet.removeAt(index)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ),

                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              border: const Border(top: BorderSide(color: Colors.black12)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                            ),
                            child: Row(
                              children: [
                                _buildOdemeButonu(
                                  baslik: _toplamNakit < 0 ? "ÖDEME YAP" : "NAKİT AL", 
                                  oran: 0, 
                                  renk: _toplamNakit < 0 ? Colors.red.shade700 : const Color(0xFF27AE60), 
                                  fmt: fmt,
                                  onTap: () => _odemeYap(context, fmt, baslangicTipi: "Nakit"),
                                  aktif: true,
                                ),
                                _buildOdemeButonu(
                                  baslik: "TEK ÇEKİM",
                                  oran: (_ayarlar['cc_single_rate'] ?? 0).toDouble(),
                                  renk: const Color(0xFF2980B9),
                                  fmt: fmt,
                                  onTap: () => _odemeYap(context, fmt, baslangicTipi: "Tek Çekim"),
                                  aktif: _toplamNakit >= 0, 
                                ),
                                _buildOdemeButonu(
                                  baslik: "3 TAKSİT",
                                  oran: (_ayarlar['cc_install_rate'] ?? 0).toDouble(),
                                  renk: const Color(0xFF8E44AD),
                                  fmt: fmt,
                                  onTap: () => _odemeYap(context, fmt, baslangicTipi: "3 Taksit"),
                                  aktif: _toplamNakit >= 0, 
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- EKRAN WIDGETLARI ---
Widget _buildTakiFormu(NumberFormat fmt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. ÜRÜN TÜRÜ
          DropdownButtonFormField<String>(
            value: _urunCesitleri.containsKey(_formSecilenTur) ? _formSecilenTur : _urunCesitleri.keys.first,
            decoration: const InputDecoration(labelText: "Ürün Türü", prefixIcon: Icon(Icons.category)),
            items: _urunCesitleri.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) {
              setState(() {
                _formSecilenTur = val!;
                _milyemElleDegisti = false;
                _formAnlikTutar = 0;
                _formFiyatController.clear(); 

                if(_formGramController.text.isNotEmpty) {
                   double gr = double.tryParse(_formGramController.text.replaceAll(',', '.')) ?? 0;
                   if (gr > 0) {
                     double milyem = _dinamikMilyemBul(_formSecilenTur, gr);
                     _formMilyemController.text = milyem.toStringAsFixed(3);
                     _formHesapla(gr, milyem);
                   }
                }
              });
            },
          ),
          const SizedBox(height: 15),
          
          // 2. GRAM VE MİLYEM
          Row(
            children: [
              Expanded(child: TextField(
                controller: _formGramController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Gram", suffixText: "gr", prefixIcon: Icon(Icons.scale)),
                onChanged: (val) {
                  double gr = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                  if (gr > 0) {
                      double milyem = 0;
                      if (!_milyemElleDegisti) {
                         milyem = _dinamikMilyemBul(_formSecilenTur, gr);
                         _formMilyemController.text = milyem.toStringAsFixed(3);
                      } else {
                         milyem = double.tryParse(_formMilyemController.text.replaceAll(',', '.')) ?? 0;
                      }
                      _formHesapla(gr, milyem);
                  } else {
                    setState(() { _formAnlikTutar = 0; _formFiyatController.clear(); });
                  }
                },
              )),
              
              const SizedBox(width: 15),
              
              if(!_sunumModu)
              Expanded(child: TextField(
                controller: _formMilyemController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Milyem", prefixIcon: Icon(Icons.percent, size: 18)),
                onChanged: (val) {
                  double m = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                  double gr = double.tryParse(_formGramController.text.replaceAll(',', '.')) ?? 0;
                  setState(() {
                    _milyemElleDegisti = true; 
                    if(gr > 0) _formHesapla(gr, m);
                  });
                },
              )),
            ],
          ),
          
          const SizedBox(height: 20),

          // 3. SATIŞ FİYATI KUTUSU (PAZARLIK İÇİN)
          TextField(
            controller: _formFiyatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: "SATIŞ FİYATI (TL)",
              suffixText: "₺",
              prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
              fillColor: Colors.green.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
               // TERSİNE MÜHENDİSLİK: Fiyat -> Milyem
               double girilenFiyat = double.tryParse(val.replaceAll(',', '.')) ?? 0;
               double gr = double.tryParse(_formGramController.text.replaceAll(',', '.')) ?? 0;
               double kur = double.tryParse(_hasSatisManuelController.text) ?? 0;

               if(gr > 0 && kur > 0 && girilenFiyat > 0) {
                  double hesaplananMilyem = 0;
                  if(_formSecilenTur.startsWith("wedding")) {
                     // Alyans Ters Hesabı
                     hesaplananMilyem = (girilenFiyat / kur) - (gr * 0.585);
                  } else {
                     // Standart Ters Hesabı
                     hesaplananMilyem = girilenFiyat / (gr * kur);
                  }

                  setState(() {
                     _formMilyemController.text = hesaplananMilyem.toStringAsFixed(3);
                     _milyemElleDegisti = true; 
                     _formAnlikTutar = girilenFiyat; 
                  });
               }
            },
          ),
          
          // --- YENİ EKLENEN: PAZARLIK LİMİTİ BİLGİSİ (TURUNCU KUTU) ---
          if (!_sunumModu)
          Builder(builder: (context) {
              double gr = double.tryParse(_formGramController.text.replaceAll(',', '.')) ?? 0;
              double kur = double.tryParse(_hasSatisManuelController.text) ?? 0;
              
              if (gr > 0 && kur > 0) {
                // 1. Standart Milyemi Bul
                double stdMilyem = _dinamikMilyemBul(_formSecilenTur, gr);
                
                // 2. Pazarlıklı Milyemi Bul (ÖZEL MANTIK)
                double pazarlikMilyem = 0;

                // Ayarlardan özel limitleri çek (Yoksa varsayılanları kullan)
                double limitAjda = (_ayarlar['limit_b22_ajda'] ?? 0.926).toDouble();
                double limitSarnel = (_ayarlar['limit_b22_sarnel'] ?? 0.938).toDouble();

                if (_formSecilenTur == "b22_ajda") {
                   // Ajda için sabit limit
                   pazarlikMilyem = limitAjda; 
                } else if (_formSecilenTur == "b22_sarnel") {
                   // Şarnel için sabit limit
                   pazarlikMilyem = limitSarnel;
                } else {
                   // Diğerleri için standarttan 2.5 santim aşağısı
                   pazarlikMilyem = stdMilyem - 0.025;
                }
                
                // 3. Pazarlıklı Fiyatı Hesapla
                double pazarlikFiyat = 0;
                if (_formSecilenTur.startsWith("wedding")) {
                   // Alyans: (Gram * 0.585) + (İşçilik - 0.025)
                   pazarlikFiyat = ((gr * 0.585) + pazarlikMilyem) * kur;
                } else {
                   // Bilezik ve Takı: Gram * LimitMilyem * Kur
                   pazarlikFiyat = gr * pazarlikMilyem * kur;
                }
                
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 5),
                      Text(
                        "Pazarlık Limiti (${pazarlikMilyem.toStringAsFixed(3)}): ", 
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800)
                      ),
                      Text(
                        fmt.format(pazarlikFiyat), 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade900)
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
          }),
          // ------------------------------------------------

          const SizedBox(height: 20),

          // 4. SEPETE EKLE
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                double gr = double.tryParse(_formGramController.text.replaceAll(',', '.')) ?? 0;
                double val = double.tryParse(_formMilyemController.text.replaceAll(',', '.')) ?? 0;

                if(gr > 0) {
                  setState(() {
                    _sepet.add(SatisSatiri(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      tur: _formSecilenTur,
                      urunAdi: _urunCesitleri[_formSecilenTur]!,
                      gram: gr,
                      deger: val > 0 ? val : _dinamikMilyemBul(_formSecilenTur, gr),
                      isManuel: _milyemElleDegisti || (val > 0),
                    ));
                    _otomatikDegerleriGuncelle();
                    _sepetAcik = true;
                    // Temizlik
                    _formGramController.clear();
                    _formMilyemController.clear();
                    _formFiyatController.clear(); 
                    _milyemElleDegisti = false;
                    _formAnlikTutar = 0;
                  });
                }
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text("SEPETE EKLE"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B2631), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
   // --- ZİYNET SATIŞ IZGARASI (Müşteriye Satış) ---
  // Formül: (Piyasa Has + Makas) * Satış Kuru = YÜKSEK FİYAT
Widget _buildZiynetGrid(NumberFormat fmt) {
    // 1. Verileri Hazırla
    double hasSatisKuru = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double sarrafiyeMakas = _guvenliDouble(_ayarlar['sarrafiye_makas'], 0.02);
    
    // Paket Ayarları
    double paketStdCarpan = _guvenliDouble(_ayarlar['paket_satis_carpani'], 1.02);
    double paketYuksekCarpan = _guvenliDouble(_ayarlar['paket_satis_carpani_yuksek'], 1.005);
    double paketLimit = _guvenliDouble(_ayarlar['paket_satis_limiti'], 20.0);

    // Has Satış Hesaplama
    double girilenHasGram = double.tryParse(_hasSatisGramController.text.replaceAll(',', '.')) ?? 0;
    double hasSatisTutar = 0;
    double aktifCarpan = paketStdCarpan;

    if (girilenHasGram > 0 && hasSatisKuru > 0) {
        if (girilenHasGram >= paketLimit) {
            aktifCarpan = paketYuksekCarpan;
        } else {
            aktifCarpan = paketStdCarpan;
        }
        hasSatisTutar = girilenHasGram * hasSatisKuru * aktifCarpan;
    }

    // --- DEĞİŞİKLİK BURADA BAŞLIYOR: SCROLLABLE YAPISI ---
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20), // En alta biraz boşluk
      child: Column(
        children: [
          // 1. PAKETLİ HAS SATIŞ FORMU
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300)
            ),
            child: Column(
              children: [
                const Row(
                   children: [
                      Icon(Icons.stars, color: Colors.amber, size: 30),
                      SizedBox(width: 10),
                      Text("PAKETLİ HAS SATIŞ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                   ],
                 ),
                 const SizedBox(height: 15),
                 Row(
                   children: [
                     Expanded(
                       flex: 2,
                       child: TextField(
                         controller: _hasSatisGramController,
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                         decoration: const InputDecoration(
                           labelText: "Gram",
                           suffixText: "Gr",
                           fillColor: Colors.white,
                           prefixIcon: Icon(Icons.scale),
                           contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15)
                         ),
                         onChanged: (val) { setState(() {}); },
                       ),
                     ),
                     const SizedBox(width: 15),
                     Expanded(
                       flex: 3,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                          if (!_sunumModu)
                           Text("Çarpan: ${aktifCarpan.toStringAsFixed(3)}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                           
                           Text(fmt.format(hasSatisTutar), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.amber.shade900)),
                         ],
                       ),
                     )
                   ],
                 ),
                 const SizedBox(height: 10),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton.icon(
                     onPressed: () {
                        if (girilenHasGram > 0) {
                          setState(() {
                            _sepet.add(SatisSatiri(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              tur: "has_paket",
                              urunAdi: "Paket Has Altın",
                              gram: girilenHasGram,
                              deger: aktifCarpan,
                              isManuel: true,
                              isHurda: false
                            ));
                            _sepetAcik = true;
                            _hasSatisGramController.text="1";
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Paket Has Sepete Eklendi"), duration: Duration(seconds: 1), backgroundColor: Colors.amber));
                        }
                     }, 
                     icon: const Icon(Icons.add_shopping_cart, color: Colors.black), 
                     label: const Text("SEPETE EKLE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                   ),
                 )
              ],
            ),
          ),

          const Divider(thickness: 2),

          // 2. GRID (Artık Expanded değil, ShrinkWrap)
          GridView.builder(
            padding: const EdgeInsets.all(10),
            shrinkWrap: true, // BU ÇOK ÖNEMLİ (İçeriği kadar yer kaplar)
            physics: const NeverScrollableScrollPhysics(), // BU DA ÇOK ÖNEMLİ (Kendi içinde kaymaz, sayfayla kayar)
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 1.8, 
              crossAxisSpacing: 8, 
              mainAxisSpacing: 8
            ),
            itemCount: _ziynetTurleri.length,
            itemBuilder: (context, index) {
              var urun = _ziynetTurleri[index];
              String piyasaKey = "${urun['id']}_satis_has"; 
              double piyasadanGelenHas = urun['def_has']; 

              if (_piyasaVerileri.containsKey(piyasaKey)) {
                 piyasadanGelenHas = (_piyasaVerileri[piyasaKey] as num).toDouble();
              }
              double hamSatisBirimFiyat = (piyasadanGelenHas + sarrafiyeMakas) * hasSatisKuru;
              double satisBirimFiyat = hamSatisBirimFiyat.roundToDouble();
              
              return Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                color: urun['id'].toString().startsWith('gr_') ? Colors.amber.shade100 : (urun['id'].toString().startsWith('y') ? Colors.white : const Color(0xFFFFF8E1)),
                child: InkWell(
                  onTap: () {
                    var mevcut = _sepet.firstWhere((s) => s.tur == "ziynet_${urun['id']}", orElse: () => SatisSatiri(id: "", tur: "", urunAdi: ""));
                    setState(() {
                      if(mevcut.id == "") {
                         _sepet.add(SatisSatiri(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          tur: "ziynet_${urun['id']}", 
                          urunAdi: urun['ad'],
                          gram: 1,
                          deger: satisBirimFiyat,
                          isHurda: false, 
                          isManuel: true,
                        ));
                      } else {
                        mevcut.gram++;
                        mevcut.deger = satisBirimFiyat;
                      }
                      _sepetAcik = true;
                    });
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${urun['ad']} Sepete Eklendi"), duration: const Duration(seconds: 1), backgroundColor: Colors.green));
                  },
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(urun['ad'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        Text(fmt.format(satisBirimFiyat), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }  // --- HURDA ALIŞ EKRANI (Müşteriden Alış) ---
  // Formül: (Piyasa Has - Makas) * Alış Kuru = DÜŞÜK FİYAT
  Widget _buildHurdaFormu(NumberFormat fmt) {
    double hasAlisFiyati = double.tryParse(_hasAlisManuelController.text.replaceAll(',', '.')) ?? 0;
    double sarrafiyeMakas = (_ayarlar['sarrafiye_makas'] ?? 0.02).toDouble(); 

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
            child: const Center(child: Text("HURDA / BOZUM İŞLEMİ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))),
          ),

          Card(
             // ... (Burası senin manuel hurda giriş kartın, aynı kalacak) ...
             color: Colors.white,
             elevation: 2,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
             child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _hurdaAlisMilyemleri.containsKey(_hurdaSecilenTur) ? _hurdaSecilenTur : null,
                      decoration: const InputDecoration(labelText: "Hurda Türü", prefixIcon: Icon(Icons.recycling, color: Colors.red), fillColor: Colors.white),
                      items: _hurdaAlisMilyemleri.keys.map((tur) => DropdownMenuItem(value: tur, child: Text(tur))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _hurdaSecilenTur = val!;
                          if (_hurdaAlisMilyemleri.containsKey(_hurdaSecilenTur)) {
                             _hurdaMilyemController.text = _hurdaAlisMilyemleri[_hurdaSecilenTur]!.toStringAsFixed(3);
                          }
                          _hurdaHesapla();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Row(children: [
                        Expanded(child: TextField(controller: _hurdaGramController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Gram", suffixText: "gr", prefixIcon: Icon(Icons.scale, color: Colors.red)), onChanged: (v) => _hurdaHesapla())),
                        if (!_sunumModu) ...[
                        const SizedBox(width: 15),
                        Expanded(child: TextField(controller: _hurdaMilyemController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Milyem", prefixIcon: Icon(Icons.analytics, color: Colors.red)), onChanged: (v) => _hurdaHesapla())),
                    ]]),
                    const SizedBox(height: 15),
                    if (_hurdaAnlikTutar > 0) Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)), child: Column(children: [const Text("ÖDENECEK TUTAR", style: TextStyle(fontSize: 10, color: Colors.red)), Text(fmt.format(_hurdaAnlikTutar), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red))])),
                    const SizedBox(height: 15),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {
                         double gr = double.tryParse(_hurdaGramController.text.replaceAll(',', '.')) ?? 0;
                         double milyem = double.tryParse(_hurdaMilyemController.text.replaceAll(',', '.')) ?? 0;
                         if (gr > 0 && milyem > 0) {
                           setState(() {
                             _sepet.add(SatisSatiri(id: DateTime.now().millisecondsSinceEpoch.toString(), tur: "hurda_$_hurdaSecilenTur", urunAdi: "$_hurdaSecilenTur Hurda", gram: gr, deger: milyem, isHurda: true, isManuel: true));
                             _sepetAcik = true; _hurdaGramController.clear(); _hurdaAnlikTutar = 0;
                           });
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hurda Sepete Eklendi"), backgroundColor: Colors.red));
                         }
                    }, icon: const Icon(Icons.download), label: const Text("HURDA SEPETİNE EKLE"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)))),
                  ],
                ),
             ),
          ),

          const SizedBox(height: 25),
          const Text("SARRAFİYE BOZUM (ALIŞ)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const Divider(),

          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 1.8, 
              crossAxisSpacing: 8, 
              mainAxisSpacing: 8
            ),
            itemCount: _ziynetTurleri.length,
            itemBuilder: (context, index) {
              var urun = _ziynetTurleri[index];
              
              // 1. Piyasa Verisini Çek (Alış veya Satış fark etmez, has değeri lazım)
              String piyasaKey = "${urun['id']}_satis_has"; 
              double piyasadanGelenHas = urun['def_has']; // Varsayılan

              if (_piyasaVerileri.containsKey(piyasaKey)) {
                piyasadanGelenHas = (_piyasaVerileri[piyasaKey] as num).toDouble();
              }

              // 2. ALIŞ FORMÜLÜ: (Canlı Has - Makas) * Alış Kuru
              // Müşteriden alırken makası DÜŞÜYORUZ.
              double netHas = piyasadanGelenHas - sarrafiyeMakas;
              double alisBirimFiyat = hasAlisFiyati * netHas;
              
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: Colors.red.shade50, // Alış olduğu için kırmızımsı
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _sepet.add(SatisSatiri(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        tur: "hurda_ziynet_${urun['id']}", // Başına hurda_ ekledik
                        urunAdi: "${urun['ad']} (BOZUM)",
                        gram: 1, 
                        deger: alisBirimFiyat, 
                        isHurda: true, // Hurda olarak işaretledik
                        isManuel: true,
                      ));
                      _sepetAcik = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${urun['ad']} Bozumu Eklendi"), duration: const Duration(seconds: 1), backgroundColor: Colors.red));
                  },
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(urun['ad'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        // Alış olduğu için Kırmızı Renk
                        Text(fmt.format(alisBirimFiyat), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade800)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

   Widget _buildOdemeButonu({
    required String baslik,
    required double oran,
    required Color renk,
    required NumberFormat fmt,
    required VoidCallback onTap,
    bool aktif = true, 
  }) {
    double hamNakit = _toplamNakit;
    double hamEski = _eskiToplamNakit;

   double guncelTutar = (oran < 100) ? (hamNakit / (1 - (oran / 100))) : hamNakit;
    
    double? eskiTutar;
    if (hamEski > hamNakit + 1) {
       eskiTutar = (oran < 100) ? (hamEski / (1 - (oran / 100))) : hamEski;
    }

    return Expanded(
      child: InkWell(
        onTap: aktif ? onTap : null, 
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: aktif ? renk : Colors.grey.shade400, 
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(baslik, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 4),
              
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    if (eskiTutar != null && aktif) 
                      Text(
                        fmt.format(eskiTutar),
                        style: const TextStyle(color: Colors.white70, fontSize: 10, decoration: TextDecoration.lineThrough, decorationColor: Colors.white70),
                      ),
                    Text(
                      fmt.format(guncelTutar),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              
              if(oran > 0 && aktif)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                child: Text("%$oran Vade", style: const TextStyle(color: Colors.white, fontSize: 8)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _fiyatKutusu(String label, String val, Color color, {TextEditingController? controller, bool readOnly = false}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          SizedBox(width: 120, child: controller != null
            ? TextField(
                controller: controller, readOnly: readOnly, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
                onChanged: (v) { setState(() { _otomatikDegerleriGuncelle(); }); },
                decoration: const InputDecoration(fillColor: Color(0xFF2C3E50), contentPadding: EdgeInsets.symmetric(vertical: 8)),
              )
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF2C3E50), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(4)),
                child: Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22), textAlign: TextAlign.center),
              )
          )
        ],
      ),
    );
  }

 // DÜZELTME 3: TEMİZLE VE TOPTAN BUTONLARI (YAN YANA)
  Widget _sepetIciToptanButonu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          // 1. TEMİZLE BUTONU (Kırmızı, Küçük)
         Expanded(
            flex: 1,
            child: ElevatedButton( // .icon yerine normal buton kullanıp row ile biz dizeceğiz
              onPressed: () {
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  title: const Text("Sepeti Temizle"),
                  content: const Text("Tüm ürünler silinecek. Emin misiniz?"),
                  actions: [
                    TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("İptal")),
                    ElevatedButton(onPressed: (){ 
                      setState(() { _sepet.clear(); _sepetAcik=false; }); 
                      Navigator.pop(ctx); 
                    }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Evet"))
                  ],
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
                minimumSize: const Size(0, 45),
                padding: const EdgeInsets.symmetric(horizontal: 2), // Boşluğu azalttık
                elevation: 0,
              ),
              child: const FittedBox( // Yazı sığmazsa küçülsün
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:  [
                    Icon(Icons.delete_sweep, size: 18),
                    SizedBox(width: 2),
                    Text("Temizle", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), // "TEMİZLE" yerine "SİL" daha kısa
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 5),

          // 2. TOPTAN UYGULA BUTONU (Sarı, Büyük)
          Expanded(
            flex: 2, // Daha geniş olsun
            child: ElevatedButton.icon(
              onPressed: () {
                if (_sepet.isEmpty) return;
                double sepetteki14kGram = 0;
                for (var urun in _sepet) {
                  if (urun.tur.startsWith("std_")) sepetteki14kGram += urun.gram;
                }

                if (sepetteki14kGram == 0) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sepette standart 14 ayar ürün yok.")));
                   return;
                }

                double onerilenMilyem = 0;
                // Ayarları kullan veya default
                List<dynamic> araliklar = _toptanAraliklar.isNotEmpty ? _toptanAraliklar : [
                   {'limit': 5, 'carpan': 0.90}, {'limit': 10, 'carpan': 0.85}, {'limit': 25, 'carpan': 0.77},
                 ];

                bool bulundu = false;
                for (var aralik in araliklar) {
                  if (sepetteki14kGram < (aralik['limit'] as num).toDouble()) {
                    onerilenMilyem = (aralik['carpan'] as num).toDouble();
                    bulundu = true;
                    break;
                  }
                }
                if (!bulundu) onerilenMilyem = (_ayarlar['factor_max'] ?? 0.725).toDouble();

                setState(() {
                  int guncellenenAdet = 0;
                  for (var urun in _sepet) {
                    if (urun.tur.startsWith("std_")) {
                      if (urun.deger != onerilenMilyem) {
                         urun.eskiDeger = urun.deger;
                         urun.deger = onerilenMilyem;
                         urun.isManuel = true;
                         guncellenenAdet++;
                      }
                    }
                  }if (guncellenenAdet > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$guncellenenAdet Ürüne Toptan Fiyat ($onerilenMilyem) Uygulandı!"), 
                        backgroundColor: Colors.green, 
                        duration: const Duration(seconds: 2)
                      )
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Zaten tüm ürünler bu fiyatta."), backgroundColor: Colors.orange)
                    );
                  }
                });
              },
              icon: const Icon(Icons.discount, color: Colors.black87, size: 20),
              label: const Text("TOPTAN UYGULA", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                minimumSize: const Size(0, 45),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _odemeYap(BuildContext context, NumberFormat fmt, {String baslangicTipi = "Nakit"}) {
    double oran = 0;
    if(baslangicTipi == "Tek Çekim") oran = (_ayarlar['cc_single_rate'] ?? 0).toDouble();
    if(baslangicTipi == "3 Taksit") oran = (_ayarlar['cc_install_rate'] ?? 0).toDouble();
    
    double finalTutar = _toplamNakit * (1 + (oran/100));

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$baslangicTipi Tahsilat", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: ()=>Navigator.pop(context), icon: const Icon(Icons.close))
                ],
              ),
              const Divider(),
              
              DropdownButtonFormField<String>(
                value: _secilenPersonel,
                decoration: const InputDecoration(labelText: "Satışı Yapan Personel", prefixIcon: Icon(Icons.person)),
                items: _personelListesi.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) { setModalState(() => _secilenPersonel = val); },
              ),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    const Text("TAHSİL EDİLECEK TUTAR", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(fmt.format(finalTutar), style: const TextStyle(fontSize: 36, color: Color(0xFF1B2631), fontWeight: FontWeight.bold)),
                    if(oran > 0)
                      Text("(%${oran.toStringAsFixed(1)} Komisyon Dahil)", style: const TextStyle(color: Colors.red, fontSize: 12))
                  ],
                ),
              ),
              
              const SizedBox(height: 25),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _satisiTamamla(baslangicTipi),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: baslangicTipi == "Nakit" ? const Color(0xFF27AE60) : (baslangicTipi == "Tek Çekim" ? const Color(0xFF2980B9) : const Color(0xFF8E44AD)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  icon: const Icon(Icons.check_circle, size: 28),
                  label: const Text("ONAYLA VE BİTİR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
            ]),
          );
        });
      }
    );
  }

Future<void> _satisiTamamla(String odemeTipi) async {
    if (_secilenPersonel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen Personel Seçin!"), backgroundColor: Colors.red));
      return;
    }
    Navigator.pop(context);

    // 1. Ayarlar ve Kurlar
    double satisOrani = (odemeTipi == "Tek Çekim") ? _guvenliDouble(_ayarlar['cc_single_rate'], 0) : (odemeTipi == "3 Taksit" ? _guvenliDouble(_ayarlar['cc_install_rate'], 0) : 0);
    double bankaMaliyetOrani = (odemeTipi == "Tek Çekim") ? _guvenliDouble(_ayarlar['pos_cost_single'], 0) : (odemeTipi == "3 Taksit" ? _guvenliDouble(_ayarlar['pos_cost_install'], 0) : 0);
    
    double satisHasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double alisHasFiyat = double.tryParse(_hasAlisManuelController.text.replaceAll(',', '.')) ?? 0; 

    // 2. Kasa Tutarları (YENİ FORMÜL: TERS HESAP)
    double hamSatisTutari = _toplamNakit; 
    // Banka komisyonu düşülünce elimize tam para geçsin diye baştan ekliyoruz:
    double tahsilEdilenTutar = (satisOrani < 100) ? (hamSatisTutari / (1 - (satisOrani / 100))) : hamSatisTutari;

    double bankaKomisyonTutari = tahsilEdilenTutar * (bankaMaliyetOrani / 100);
    double netEleGecen = tahsilEdilenTutar - bankaKomisyonTutari;

    // Maliyet Ayarlarını Çek
    double cost14 = _guvenliDouble(_ayarlar['cost_14k'], 0.685);
    double cost22 = _guvenliDouble(_ayarlar['cost_22k'], 1.016);
    double costWPlain = _guvenliDouble(_ayarlar['cost_wedding_plain'], 0.20);
    double costWPattern = _guvenliDouble(_ayarlar['cost_wedding_pattern'], 0.30);

    // 3. DETAYLI KAR VE MALİYET HESABI
    double toplamNetKar = 0; 
    double vadeFarkiGeliri = hamSatisTutari > 0 ? (hamSatisTutari * (satisOrani / 100)) : 0; // Vade farkı aslında bir kardır

    try {
      // Veritabanına gidecek veri paketini hazırlıyoruz
      Map<String, dynamic> satisVerisi = {
        'tarih': DateTime.now(), // Yazdırma hatası olmasın diye DateTime
        'personel': _secilenPersonel,
        'tutar': tahsilEdilenTutar,
        'net_ele_gecen': netEleGecen,
        'ham_tutar': hamSatisTutari,
        'vade_farki_geliri': vadeFarkiGeliri,
        'pos_gideri': bankaKomisyonTutari,
        'odeme_tipi': odemeTipi,
        'has_fiyat': satisHasFiyat,
        
        // --- İŞTE DÜZELTİLEN KISIM: ÜRÜNLERİ MAPLERKEN MALİYETİ HESAPLIYORUZ ---
        'urunler': _sepet.map((s) {
            double satirSatisFiyati = 0; // Müşteriden alınan
            double satirMaliyet = 0;     // Yerine koyma maliyeti
            String detayBilgi = "";

            // --- A) HURDA İŞLEMİ ---
            if(s.isHurda) {
               if(s.tur.contains("ziynet")) {
                  // Hurda Ziynet
                  satirSatisFiyati = s.gram * s.deger; // Müşteriye ödenen (Adet * Fiyat)
                  
                  String turKod = s.tur.replaceAll("hurda_ziynet_", "");
                  var urun = _ziynetTurleri.firstWhere((e) => e['id'] == turKod, orElse: () => {});
                  if(urun.isNotEmpty) {
                     double defHas = (urun['def_has'] as num).toDouble();
                     satirMaliyet = s.gram * defHas * alisHasFiyat; // Gerçek Değeri (Alış Kuruyla)
                  }
               } else {
                  // Hurda Takı / Has
                  satirSatisFiyati = s.gram * s.deger * alisHasFiyat; // Müşteriye ödenen
                  
                  String safTurAdi = s.tur.replaceFirst("hurda_", ""); 
                  if (_hurdaHasMilyemleri.containsKey(safTurAdi)) {
                     double gercekHasMilyem = _hurdaHasMilyemleri[safTurAdi]!;
                     satirMaliyet = s.gram * gercekHasMilyem * alisHasFiyat; // Gerçek Değeri
                  }
               }
               // Hurda Karı = (Gerçek Değer - Ödenen)
               toplamNetKar += (satirMaliyet - satirSatisFiyati);
               detayBilgi = "Hurda Alış";
            } 
            
            // --- B) SATIŞ İŞLEMİ ---
            else {
               // 1. ZİYNET
               if(s.tur.startsWith("ziynet")) {
                   String turKod = s.tur.replaceAll("ziynet_", "");
                   var urun = _ziynetTurleri.firstWhere((e) => e['id'] == turKod, orElse: () => {});
                   if(urun.isNotEmpty) {
                      String anahtar = "${urun['id']}_satis_has";
                      double defHas = (_piyasaVerileri.containsKey(anahtar)) ? (_piyasaVerileri[anahtar] as num).toDouble() : urun['def_has'];
                      
                      satirSatisFiyati = s.gram * s.deger; // Kasaya Giren
                      satirMaliyet = s.gram * defHas * satisHasFiyat; // Maliyet (Satış Kurundan)
                      
                      detayBilgi = "Ziynet (Has: $defHas)";
                   }
               }
               
               // 2. PAKET HAS (Özel İstek)
               else if (s.tur == "has_paket") {
                  double limit = _guvenliDouble(_ayarlar['paket_satis_limiti'], 20.0);
                  double maliyetCarpan = (s.gram >= limit) 
                      ? _guvenliDouble(_ayarlar['paket_maliyet_yuksek'], 1.002)
                      : _guvenliDouble(_ayarlar['paket_maliyet'], 1.01);
                  
                  satirSatisFiyati = s.gram * s.deger * satisHasFiyat; // Satış
                  satirMaliyet = s.gram * maliyetCarpan * satisHasFiyat; // Maliyet
                  
                  detayBilgi = "Paket (Mal: $maliyetCarpan)";
               }
               
               // 3. TAKI & ALYANS
               else {
                  double mly = 0.585;
                  double sabitIsclik = 0;

                  if(s.tur.startsWith("b22")) mly = cost22;
                  else if(s.tur.startsWith("std_")) mly = cost14;
                  else if(s.tur == "wedding_plain") { mly = 0.585; sabitIsclik = costWPlain; detayBilgi="Düz Alyans"; }
                  else if(s.tur == "wedding_pattern") { mly = 0.585; sabitIsclik = costWPattern; detayBilgi="Kalemli Alyans"; }
                  else detayBilgi = "${s.deger.toStringAsFixed(3)} Milyem";
                  
                  if(s.tur.startsWith("wedding")) {
                     satirSatisFiyati = satisHasFiyat * ((s.gram * 0.585) + s.deger);
                     satirMaliyet = ((s.gram * 0.585) + sabitIsclik) * satisHasFiyat;
                  } else {
                     if (s.tur.startsWith("ziynet")) satirSatisFiyati = s.gram * s.deger; // Güvenlik
                     else satirSatisFiyati = _satirFiyatiHesapla(s, satisHasFiyat);
                     
                     satirMaliyet = s.gram * mly * satisHasFiyat;
                  }
               }
               // Satış Karı = (Satılan - Maliyet)
               toplamNetKar += (satirSatisFiyati - satirMaliyet);
            }

            // Listeye yazılacak format (VERİTABANI İÇİN)
            String miktar = s.tur.contains("ziynet") ? "${s.gram.toInt()} Ad" : "${s.gram} Gr";
            
            // Format: Ad | Miktar | MüşteriTutarı | GerçekDeğer(Maliyet) | ...
            return "${s.urunAdi} | $miktar | ${satirSatisFiyati.toStringAsFixed(2)} | ${satirMaliyet.toStringAsFixed(2)} | 0 | 0 | $detayBilgi";
        }).toList(),
      };

      // Toplam Karı Veriye Ekle (Vade farkı ve banka kesintisini de hesaba katıyoruz)
      double finalKar = toplamNetKar + vadeFarkiGeliri - bankaKomisyonTutari;
      satisVerisi['kar'] = finalKar;
      satisVerisi['urun_satis_kari'] = toplamNetKar;

      // Veritabanına kaydet
      await DB.ref('satis_gecmisi').add(satisVerisi);
      
      // Sepeti Temizle
      setState(() { _sepet.clear(); _secilenPersonel = null; _sepetAcik = false; });
      
      // Dialog Göster
      if(mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 10),
                const Text("Satış Başarılı", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(NumberFormat.currency(locale:"tr", symbol:"₺").format(tahsilEdilenTutar), style: const TextStyle(fontSize: 20, color: Colors.black54)),
              ],
            ),
            content: const Text("İşlem kaydedildi. Fiş yazdırmak ister misiniz?", textAlign: TextAlign.center),
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  FisIslemleri.yazdir(context, satisVerisi, _firmaAdi);
                }, 
                icon: const Icon(Icons.print),
                label: const Text("FİŞ YAZDIR"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); 
                }, 
                child: const Text("YENİ SATIŞ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              ),
            ],
            actionsAlignment: MainAxisAlignment.spaceEvenly,
          )
        );
      }
    } catch(e) { 
      print("HATA: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kayıt sırasında hata oluştu!"), backgroundColor: Colors.red));
    }
  }
 
 void _gecmisSatislariGoster(BuildContext context, NumberFormat fmt) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const SatisGecmisiSayfasi())
    );
  }}

// --- ADMIN PANEL ---
class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firmaAdiCtrl = TextEditingController(); 
  final TextEditingController _adminPinCtrl = TextEditingController(); 
  final TextEditingController _sarrafiyeMakasController = TextEditingController();
  final TextEditingController _cost14kCtrl = TextEditingController(); 
  final TextEditingController _cost22kCtrl = TextEditingController(); 
  final TextEditingController _ccSingleController = TextEditingController();
  final TextEditingController _ccInstallController = TextEditingController();

  final TextEditingController _posCostSingleCtrl = TextEditingController();
  final TextEditingController _posCostInstallCtrl = TextEditingController();
  final TextEditingController _limitAjdaCtrl = TextEditingController();   // YENİ
  final TextEditingController _limitSarnelCtrl = TextEditingController(); 
  final TextEditingController _weddingPlainCtrl = TextEditingController();
  final TextEditingController _weddingPatternCtrl = TextEditingController();
  final TextEditingController _b22SarnelCtrl = TextEditingController();
  final TextEditingController _b22AjdaCtrl = TextEditingController();
  final TextEditingController _b22TakiCtrl = TextEditingController(); 
  final TextEditingController _maxFactorCtrl = TextEditingController();
  final TextEditingController _costWeddingPlainCtrl = TextEditingController(); // Düz Alyans Maliyet
  final TextEditingController _costWeddingPatternCtrl = TextEditingController(); // Kalemli Alyans Maliyet
  final TextEditingController _paketCarpanCtrl = TextEditingController();       // Düşük gramaj çarpanı
  final TextEditingController _paketYuksekCarpanCtrl = TextEditingController(); // Yüksek gramaj çarpanı
  final TextEditingController _paketLimitCtrl = TextEditingController();
  final TextEditingController _paketMaliyetCtrl = TextEditingController();       // Düşük gr alış maliyeti (Örn: 1.01)
  final TextEditingController _paketYuksekMaliyetCtrl = TextEditingController();

  List<Map<String, dynamic>> _dinamikHurdaListesi = [];
  List<Map<String, dynamic>> _toptanListesi = [];
  List<String> _personelListesi = [];
  double _guvenliDouble(dynamic veri, double varsayilan) {
    if (veri == null) return varsayilan;
    if (veri is int) return veri.toDouble();
    if (veri is double) return veri;
    if (veri is String) return double.tryParse(veri) ?? varsayilan;
    return varsayilan;
  }
  @override
  void initState() {
    super.initState();
    DB.ref('ayarlar').doc('genel').get().then((doc) {
      if(doc.exists) {
        var data = doc.data()!  as Map<String, dynamic>;
        setState(() {
          _firmaAdiCtrl.text = data['firma_adi'] ?? "Default";
          _adminPinCtrl.text = data['admin_pin'] ?? "1234"; 
          _sarrafiyeMakasController.text = (data['sarrafiye_makas'] ?? 0.02).toString();
          _paketCarpanCtrl.text = (data['paket_satis_carpani'] ?? 1.005).toString(); 
          _paketYuksekCarpanCtrl.text = (data['paket_satis_carpani_yuksek'] ?? 1.002).toString(); 
          _paketLimitCtrl.text = (data['paket_satis_limiti'] ?? 20).toString(); 
          _paketMaliyetCtrl.text = (data['paket_maliyet'] ?? 0.999).toString(); 
          _paketYuksekMaliyetCtrl.text = (data['paket_maliyet_yuksek'] ?? 0.997).toString();
          _ccSingleController.text = (data['cc_single_rate'] ?? 7).toString();
          _ccInstallController.text = (data['cc_install_rate'] ?? 12).toString();
          _limitAjdaCtrl.text = (data['limit_b22_ajda'] ?? 0.926).toString();
          _limitSarnelCtrl.text = (data['limit_b22_sarnel'] ?? 0.938).toString();
          _posCostSingleCtrl.text = (data['pos_cost_single'] ?? 0).toString();
          _posCostInstallCtrl.text = (data['pos_cost_install'] ?? 0).toString();
          _costWeddingPlainCtrl.text = (data['cost_wedding_plain'] ?? 0.20).toString();
          _costWeddingPatternCtrl.text = (data['cost_wedding_pattern'] ?? 0.40).toString();
          _weddingPlainCtrl.text = (data['factor_wedding_plain'] ?? 0.60).toString();
          _weddingPatternCtrl.text = (data['factor_wedding_pattern'] ?? 0.80).toString();
          _b22SarnelCtrl.text = (data['factor_b22_Sarnel'] ?? 0.940).toString();
          _b22AjdaCtrl.text = (data['factor_b22_ajda'] ?? 0.930).toString();
          _b22TakiCtrl.text = (data['factor_b22_taki'] ?? 0.960).toString(); 
          _maxFactorCtrl.text = (data['factor_max'] ?? 0.725).toString();
          _cost14kCtrl.text = (data['cost_14k'] ?? 0.685).toString();
          _cost22kCtrl.text = (data['cost_22k'] ?? 1.016).toString();
          if(data.containsKey('toptan_araliklar')) {
            _toptanListesi = List<Map<String, dynamic>>.from(data['toptan_araliklar']);
          } else {
            _toptanListesi = [{'limit': 5, 'carpan': 0.90}, {'limit': 10, 'carpan': 0.85}, {'limit': 15, 'carpan': 0.82}, {'limit': 25, 'carpan': 0.77}];
          }

          if(data.containsKey('hurda_ayarlari')) {
            Map<String, dynamic> gelenData = data['hurda_ayarlari'];
            _dinamikHurdaListesi.clear();
            gelenData.forEach((ad, degerler) {
              _dinamikHurdaListesi.add({
                'ad': ad,
                'alis': TextEditingController(text: degerler[0].toString()),
                'has': TextEditingController(text: degerler[1].toString()),
              });
            });
          } else {
            _varsayilanHurdalariYukle();
          }

          if(data.containsKey('personel_listesi')) {
            _personelListesi = List<String>.from(data['personel_listesi']);
          } else {
            _personelListesi = ["Mağaza", "Ahmet"];
          }
        });
      }
    });
  }

  void _varsayilanHurdalariYukle() {
    final varsayilanlar = {
      "Has Altın": [0.995, 0.995],
      "22 Ayar": [0.910, 0.914],
      "18 Ayar": [0.700, 0.735],
      "14 Ayar": [0.550, 0.575],
      "08 Ayar":  [0.300, 0.320],
      "Has Gümüş": [0.990, 1.000], 
    };
    _dinamikHurdaListesi.clear();
    varsayilanlar.forEach((ad, degerler) {
      _dinamikHurdaListesi.add({
        'ad': ad,
        'alis': TextEditingController(text: degerler[0].toString()),
        'has': TextEditingController(text: degerler[1].toString()),
      });
    });
  }

  void _kaydet() {
    if(_formKey.currentState!.validate()) {
      Map<String, List<double>> kaydedilecekHurdaMap = {};
      
      for (var item in _dinamikHurdaListesi) {
        String ad = item['ad'];
        double alis = double.tryParse((item['alis'] as TextEditingController).text.replaceAll(',', '.')) ?? 0;
        double has = double.tryParse((item['has'] as TextEditingController).text.replaceAll(',', '.')) ?? 0;
        kaydedilecekHurdaMap[ad] = [alis, has];
      }

      DB.ref('ayarlar').doc('genel').set({
        'firma_adi': _firmaAdiCtrl.text,
        'admin_pin': _adminPinCtrl.text,
        'paket_satis_carpani': double.parse(_paketCarpanCtrl.text.replaceAll(',', '.')),
        'paket_satis_carpani_yuksek': double.parse(_paketYuksekCarpanCtrl.text.replaceAll(',', '.')),
        'paket_satis_limiti': double.parse(_paketLimitCtrl.text.replaceAll(',', '.')),
        'paket_maliyet': double.parse(_paketMaliyetCtrl.text.replaceAll(',', '.')),
        'paket_maliyet_yuksek': double.parse(_paketYuksekMaliyetCtrl.text.replaceAll(',', '.')),
        'sarrafiye_makas': double.parse(_sarrafiyeMakasController.text.replaceAll(',', '.')),
        'cost_wedding_plain': double.parse(_costWeddingPlainCtrl.text.replaceAll(',', '.')),
        'cost_wedding_pattern': double.parse(_costWeddingPatternCtrl.text.replaceAll(',', '.')),
        'cc_single_rate': double.parse(_ccSingleController.text.replaceAll(',', '.')),
        'cc_install_rate': double.parse(_ccInstallController.text.replaceAll(',', '.')),
        'limit_b22_ajda': double.parse(_limitAjdaCtrl.text.replaceAll(',', '.')),
        'limit_b22_sarnel': double.parse(_limitSarnelCtrl.text.replaceAll(',', '.')),
        'pos_cost_single': double.parse(_posCostSingleCtrl.text.replaceAll(',', '.')),
        'pos_cost_install': double.parse(_posCostInstallCtrl.text.replaceAll(',', '.')),
        'cost_14k': double.parse(_cost14kCtrl.text.replaceAll(',', '.')),
        'cost_22k': double.parse(_cost22kCtrl.text.replaceAll(',', '.')),
        'factor_wedding_plain': double.parse(_weddingPlainCtrl.text.replaceAll(',', '.')),
        'factor_wedding_pattern': double.parse(_weddingPatternCtrl.text.replaceAll(',', '.')),
        'factor_b22_Sarnel': double.parse(_b22SarnelCtrl.text.replaceAll(',', '.')),
        'factor_b22_ajda': double.parse(_b22AjdaCtrl.text.replaceAll(',', '.')),
        'factor_b22_taki': double.parse(_b22TakiCtrl.text.replaceAll(',', '.')), 
        'factor_max': double.parse(_maxFactorCtrl.text.replaceAll(',', '.')),
        
        'hurda_ayarlari': kaydedilecekHurdaMap,
        'toptan_araliklar': _toptanListesi,
        'personel_listesi': _personelListesi,
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tüm Ayarlar ve Maliyetler Kaydedildi!")));
    }
  }

  void _yeniHurdaTuruEkle() {
    TextEditingController adCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Yeni Hurda Türü"),
      content: TextField(
        controller: adCtrl, 
        decoration: const InputDecoration(labelText: "Tür Adı (Örn: 21 Ayar)"),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
        ElevatedButton(onPressed: () {
          if(adCtrl.text.isNotEmpty) {
            setState(() {
              _dinamikHurdaListesi.add({
                'ad': adCtrl.text,
                'alis': TextEditingController(text: "0.0"), 
                'has': TextEditingController(text: "0.0"),
              });
            });
            Navigator.pop(ctx);
          }
        }, child: const Text("Ekle"))
      ],
    ));
  }

  void _hurdaSil(int index) {
    setState(() {
      _dinamikHurdaListesi.removeAt(index);
    });
  }

  void _listeElemanEkle(List<String> liste, String title) {
    TextEditingController ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Yeni $title Ekle"),
      content: TextField(controller: ctrl, decoration: InputDecoration(labelText: title)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
        ElevatedButton(onPressed: () { setState(() => liste.add(ctrl.text)); Navigator.pop(ctx); }, child: const Text("Ekle"))
      ]
    ));
  }
  
  void _aralikEkle() {
    TextEditingController limitCtrl = TextEditingController();
    TextEditingController carpanCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Yeni Toptan Aralık"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Gram Limiti")),
          const SizedBox(height: 10),
          TextField(controller: carpanCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Çarpan")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
        ElevatedButton(onPressed: () {
          setState(() => _toptanListesi.add({'limit': double.parse(limitCtrl.text), 'carpan': double.parse(carpanCtrl.text)}));
          Navigator.pop(ctx);
        }, child: const Text("Ekle"))
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAnaSablon(
      appBar: AppBar(title: const Text("Yönetici Paneli"), backgroundColor: Colors.black),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. GENEL
              const Text("MAĞAZA AYARLARI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              _buildInput("Firma Adı (Tabelada Görünecek)", _firmaAdiCtrl, icon: Icons.store, type: TextInputType.text), 
              _buildInput("Yönetici Şifresi (Giriş İçin)", _adminPinCtrl, icon: Icons.lock),
              const SizedBox(height: 25),
              const Text("POS AYARLARI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Text("Soldaki kutu müşteriye eklenir, sağdaki kutu banka kesintisidir (kar hesabında düşülür).", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const Divider(),
              
              const Text("Tek Çekim:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(children: [
                Expanded(child: _buildInput("Satış Farkı (%)", _ccSingleController, icon: Icons.add_circle_outline, color: Colors.green)),
                const SizedBox(width: 10),
                Expanded(child: _buildInput("Banka Maliyeti (%)", _posCostSingleCtrl, icon: Icons.remove_circle_outline, color: Colors.red)),
              ]),
              
              const SizedBox(height: 10),
              
              const Text("Taksitli (3 Taksit):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(children: [
                Expanded(child: _buildInput("Satış Farkı (%)", _ccInstallController, icon: Icons.add_circle_outline, color: Colors.green)),
                const SizedBox(width: 10),
                Expanded(child: _buildInput("Banka Maliyeti (%)", _posCostInstallCtrl, icon: Icons.remove_circle_outline, color: Colors.red)),
              ]),

              const SizedBox(height: 25),
              const Text("DİĞER AYARLAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              _buildInput("Sarrafiye Makas (Gr)", _sarrafiyeMakasController),

              const SizedBox(height: 25),
              const Text("ÖZEL ÜRÜN ÇARPANLARI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              Row(children: [
                  Expanded(child: _buildInput("Düz Alyans", _weddingPlainCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Kalemli Alyans", _weddingPatternCtrl)),
              ]),
              Row(children: [
                  Expanded(child: _buildInput("Şarnel Bilezik", _b22SarnelCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Ajda / Burma Bilezik", _b22AjdaCtrl)),
              ]),
              const SizedBox(height: 25),
              const Text("PAKETLİ HAS / GRAM ALTIN AYARLARI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber)),
              const Divider(),
              
              const Text("Standart Gramajlar (Limit Altı)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(children: [
                  Expanded(child: _buildInput("Satış Çarpanı (Örn: 1.02)", _paketCarpanCtrl, color: Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Maliyet Çarpanı (Örn: 1.01)", _paketMaliyetCtrl, color: Colors.red)),
              ]),
              
              const SizedBox(height: 10),
              _buildInput("Yüksek Gram Limiti (Gr)", _paketLimitCtrl),
              const SizedBox(height: 10),

              const Text("Yüksek Gramajlar (Limit Üstü)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(children: [
                  Expanded(child: _buildInput("Yük. Satış Çarpanı (1.005)", _paketYuksekCarpanCtrl, color: Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Yük. Maliyet Çarpanı (1.002)", _paketYuksekMaliyetCtrl, color: Colors.red)),
              ]),
              const Text("Not: Limit gramın üzerindeki satışlarda 'Yüksek Gr Çarpanı' devreye girer.", style: TextStyle(fontSize: 11, color: Colors.grey)),
              _buildInput("22 Ayar Takı (İşçilikli)", _b22TakiCtrl), 
              const SizedBox(height: 25),
              const SizedBox(height: 10),
              const Text("BİLEZİK PAZARLIK LİMİTLERİ (Taban Milyem)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
              Row(children: [
                  Expanded(child: _buildInput("Şarnel Limiti (0.938)", _limitSarnelCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Ajda Limiti (0.926)", _limitAjdaCtrl)),
              ]),
              const Text("MALİYET AYARLARI (İşçilik Dahil)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              Row(children: [
                 Expanded(child: _buildInput("14K Maliyet (0.685)", _cost14kCtrl)),
                 const SizedBox(width: 10),
                 Expanded(child: _buildInput("22K Maliyet (1.016)", _cost22kCtrl)),
                 ]),
              Row(children: [
                 Expanded(child: _buildInput("Düz Alyans Mal. (+0.20)", _costWeddingPlainCtrl)),
                 const SizedBox(width: 10),
                 Expanded(child: _buildInput("Kalemli Alyans Mal. (+0.40)", _costWeddingPatternCtrl)),
              ]),
              const SizedBox(height: 25),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("TOPTAN ARALIKLARI (Standart 14K)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                IconButton(onPressed: _aralikEkle, icon: const Icon(Icons.add_circle, color: Colors.green))
              ]),
              const Divider(),
              Column(children: [
                ..._toptanListesi.map((item) => ListTile(dense: true, title: Text("${item['limit']} Grama Kadar"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("x ${item['carpan']}"), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _toptanListesi.remove(item)))]) )),
                _buildInput("Max Çarpan (Limit Üstü)", _maxFactorCtrl)
              ]),

              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("HURDA ALIŞ AYARLARI (DB)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(onPressed: _yeniHurdaTuruEkle, icon: const Icon(Icons.add_circle, color: Colors.blue))
                ],
              ),
              const Text("Sol: Alış Milyemi | Sağ: Has Milyemi | Gümüş için 1.000 yazın.", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const Divider(),
              
              ListView.builder(
                shrinkWrap: true, 
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _dinamikHurdaListesi.length,
                itemBuilder: (context, index) {
                  var item = _dinamikHurdaListesi[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          onPressed: () => _hurdaSil(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        
                        SizedBox(
                          width: 85, 
                          child: Text(item['ad'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                        ),
                        
                        Expanded(
                          child: TextFormField(
                            controller: item['alis'],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: "Alış", isDense: true, fillColor: Colors.red.shade50, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8)),
                          ),
                        ),
                        const SizedBox(width: 5),
                        
                        Expanded(
                          child: TextFormField(
                            controller: item['has'],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: "Has", isDense: true, fillColor: Colors.green.shade50, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("PERSONEL LİSTESİ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(onPressed: () => _listeElemanEkle(_personelListesi, "Personel"), icon: const Icon(Icons.add_circle, color: Colors.green))
              ]),
              const Divider(),
              Wrap(spacing: 8, children: _personelListesi.map((p) => Chip(
                label: Text(p), 
                onDeleted: () => setState(() => _personelListesi.remove(p)), 
                deleteIconColor: Colors.red,
              )).toList()),

              const SizedBox(height: 30),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _kaydet, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("TÜMÜNÜ KAYDET"))
              
              ),
              const SizedBox(height: 20),
              
              // ÇIKIŞ BUTONU
              TextButton.icon(
                onPressed: () async {
                  await DB.cikisYap();
                  // Uygulamayı en başa (Login ekranına) at
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (c) => const LoginScreen()), (route) => false);
                }, 
                icon: const Icon(Icons.logout, color: Colors.red), 
                label: const Text("Oturumu Kapat / Mağaza Değiştir", style: TextStyle(color: Colors.red))
              ),
              const SizedBox(height: 20),
            
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInput(String lbl, TextEditingController ctrl, {IconData? icon, Color? color, TextInputType type = TextInputType.number}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl, 
        keyboardType: type, 
        decoration: InputDecoration(
          labelText: lbl,
          prefixIcon: icon != null ? Icon(icon, color: color, size: 18) : null,
          isDense: true
        ), 
      ),
    );
  }
}// --- GELİŞMİŞ SATIŞ GEÇMİŞİ VE DETAYLI RAPOR EKRANI (HATA DÜZELTİLMİŞ) ---
class SatisGecmisiSayfasi extends StatefulWidget {
  const SatisGecmisiSayfasi({super.key});

  @override
  State<SatisGecmisiSayfasi> createState() => _SatisGecmisiSayfasiState();
}

class _SatisGecmisiSayfasiState extends State<SatisGecmisiSayfasi> {
  DateTime _baslangicTarihi = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _bitisTarihi = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);

  
  double _safeParse(String val) {
    if (val.isEmpty) return 0;
    
    String temiz = val.replaceAll('₺', '').replaceAll('TL', '').trim();
    
    if (temiz.contains(',')) {
      temiz = temiz.replaceAll('.', '').replaceAll(',', '.');
    } 
    
    
    return double.tryParse(temiz) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFF5),
      appBar: AppBar(
        title: const Text("Satış Raporu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B2631),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _tarihAraligiSec)
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DB.ref('satis_gecmisi')
            .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(_baslangicTarihi))
            .where('tarih', isLessThanOrEqualTo: Timestamp.fromDate(_bitisTarihi))
            .orderBy('tarih', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Kayıt yok."));

          var docs = snapshot.data!.docs;
          double toplamCiro = 0, toplamNetKar = 0, toplamBankaGideri = 0, nakitKasa = 0, posKasa = 0;

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            double tutar = (data['tutar'] ?? 0).toDouble();
            double kar = (data['kar'] ?? 0).toDouble();
            double pos = (data['pos_gideri'] ?? 0).toDouble();
            String tip = data['odeme_tipi'] ?? "Nakit";

            toplamCiro += tutar;
            toplamNetKar += kar;
            toplamBankaGideri += pos;
            if(tip == "Nakit") nakitKasa += tutar; else posKasa += tutar;
          }

          return Column(
            children: [
              // ÖZET KUTUSU
              Container(
                padding: const EdgeInsets.all(15),
                color: Colors.white,
                child: Column(children: [
                    Row(children: [
                        _dashboardKutu("TOPLAM CİRO", fmt.format(toplamCiro), Colors.blue.shade900),
                        const SizedBox(width: 10),
                        _dashboardKutu("NET KAR", fmt.format(toplamNetKar), Colors.green.shade800),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                        _dashboardKutu("NAKİT", fmt.format(nakitKasa), Colors.orange.shade800),
                        const SizedBox(width: 10),
                        _dashboardKutu("POS", fmt.format(posKasa), Colors.purple.shade800),
                    ]),
                    if(toplamBankaGideri > 0) Text("Banka Kesintisi: ${fmt.format(toplamBankaGideri)}", style: const TextStyle(color: Colors.red, fontSize: 12))
                ]),
              ),
              const Divider(height: 1),
              
              // LİSTE
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    double tutar = (data['tutar'] ?? 0).toDouble();
                    double kar = (data['kar'] ?? 0).toDouble();
                    double hamTutar = (data['ham_tutar'] ?? tutar).toDouble();
                    double vadeGeliri = (data['vade_farki_geliri'] ?? 0).toDouble();
                    double posGideri = (data['pos_gideri'] ?? 0).toDouble();
                    String odemeTipi = data['odeme_tipi'] ?? "Nakit";
                    List<dynamic> urunler = data['urunler'] ?? [];

                    return Card(
                      child: ExpansionTile(
                        leading: Icon(odemeTipi == "Nakit" ? Icons.money : Icons.credit_card, color: odemeTipi == "Nakit" ? Colors.green : Colors.purple),
                        title: Text(fmt.format(tutar), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Kar: ${fmt.format(kar)}"),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            color: Colors.grey.shade50,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                               if(odemeTipi != "Nakit") ...[
                                 Text("Ürün Fiyatı: ${fmt.format(hamTutar)}"),
                                 Text("Vade Farkı: +${fmt.format(vadeGeliri)}"),
                                 Text("Banka Komisyonu: -${fmt.format(posGideri)}", style: const TextStyle(color: Colors.red)),
                                 const Divider(),
                               ],
                               
                               const Text("ÜRÜN DETAYLARI:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                               const SizedBox(height: 5),
                               
                               // --- ÜRÜN LİSTESİ VE DETAYLI KAR ---
                               ...urunler.map((uString) {
                                   List<String> p = uString.toString().split(" | ");
                                   // Parçalar: 0:Ad, 1:Miktar, 2:MüşteriTutarı, 3:GerçekMaliyet, 4:MaliyetHas, 5:SatışHasKrş, 6:Detay
                                   
                                   String ad = p.isNotEmpty ? p[0] : "";
                                   String miktar = p.length > 1 ? p[1] : "";
                                   String satisTL = "";
                                   
                                   if(p.length > 2) {
                                      double val = _safeParse(p[2]);
                                      satisTL = "${fmt.format(val)}";
                                   }
                                   
                                   String detayInfo = "";
                                   Color karRengi = Colors.green;

                                   if(p.length > 6) {
                                      double musteriTutari = _safeParse(p[2]); // Kasaya giren/çıkan
                                      double gercekMaliyet = _safeParse(p[3]); // Ürünün gerçek değeri
                                      double urunKari = 0;

                                      // --- KRİTİK DÜZELTME BURADA ---
                                      if(ad.contains("Hurda") || p[6].contains("Hurda")) {
                                         // HURDA İSE: Kar = Gerçek Değer - Müşteriye Ödenen
                                         urunKari = gercekMaliyet - musteriTutari;
                                      } else {
                                         // SATIŞ İSE: Kar = Müşteriden Alınan - Maliyet
                                         urunKari = musteriTutari - gercekMaliyet;
                                      }
                                      
                                      if(urunKari < 0) karRengi = Colors.red;
                                      
                                      detayInfo = "Kar: ${urunKari.toStringAsFixed(0)}₺  |  İşlem Has: ${p[5]}  |  ${p[6]}";
                                   }

                                   return Padding(
                                     padding: const EdgeInsets.symmetric(vertical: 4),
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Row(
                                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                           children: [
                                             Text("$ad ($miktar)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                             Text(satisTL, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ad.contains("Hurda") ? Colors.red : Colors.green)),
                                           ],
                                         ),
                                         if(detayInfo.isNotEmpty)
                                           Text(detayInfo, style: TextStyle(fontSize: 11, color: karRengi == Colors.red ? Colors.red.shade300 : Colors.grey.shade700, fontStyle: FontStyle.italic)),
                                       ],
                                     ),
                                   );
                               }),

                               const Divider(),
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                 children: [
                                   if(data.containsKey('has_fiyat'))
                                      Text("Kur: ${data['has_fiyat']} ₺", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                   
                                   Row(
                                     children: [
                                       TextButton.icon(
                                         onPressed: () => _satisIptalEt(doc.id), 
                                         icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                         label: const Text("Sil", style: TextStyle(color: Colors.red)),
                                       ),
                                       ElevatedButton.icon(
                                         onPressed: () async {                                        
                                         String fAdi = "Kuyumcu";
                                         try {
                                           var doc = await DB.ref('ayarlar').doc('genel').get();
                                           if(doc.exists) fAdi = doc['firma_adi'];
                                         } catch(e){}
                                         
                                         // Yeni Sınıfı Kullanıyoruz
                                         FisIslemleri.yazdir(context, data, fAdi);
                                        },
                                         icon: const Icon(Icons.print, size: 18),
                                         label: const Text("Fiş Yazdır"),
                                         style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                                       ),
                                     ],
                                   )
                                 ],
                               )
                            ]),
                          )
                        ],
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }

    Widget _dashboardKutu(String baslik, String deger, Color renk) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: renk.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [Text(baslik, style: TextStyle(color: renk, fontSize: 10)), Text(deger, style: TextStyle(color: renk, fontSize: 16, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  void _tarihAraligiSec() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime(2030));
    if (picked != null) setState(() { _baslangicTarihi = picked.start; _bitisTarihi = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59); });
  }

  void _satisIptalEt(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Satışı Sil"),
        content: const Text("Bu işlem geri alınamaz.\nEmin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
             DB.ref('satis_gecmisi').doc(docId).delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kayıt silindi.")));
            },
            child: const Text("Evet, Sil"),
          )
        ],
      ),
    );
  }
}
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _kodController = TextEditingController();
  final TextEditingController _pinController = TextEditingController(); 
  bool _yukleniyor = false;

 

  void _girisYap() async {
    if (_kodController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mağaza Kodu Giriniz"), backgroundColor: Colors.red));
      return;
    }
    
    setState(() => _yukleniyor = true);
    
    String girilenKod = _kodController.text.trim().toLowerCase().replaceAll(" ", "_");
    String girilenPin = _pinController.text.trim();

    try {
      // 1. Önce Veritabanındaki GİZLİ MASTER KEY'i çekiyoruz
      String dbMasterKey = "";
      try {
        var sysDoc = await FirebaseFirestore.instance.collection('yonetim').doc('lisans_ayarlari').get();
        if (sysDoc.exists) {
          dbMasterKey = sysDoc.data()?['master_key'] ?? ""; 
        }
      } catch (e) {
        print("Master key çekilemedi: $e");
      }

      // 2. Şimdi Mağazayı Kontrol Et
      var docRef = FirebaseFirestore.instance.collection('magazalar').doc(girilenKod).collection('ayarlar').doc('genel');
      var doc = await docRef.get();

      bool girisBasarili = false;
      bool yeniKurulum = false;

      if (doc.exists) {
        // --- 1. SENARYO: MAĞAZA VAR (Normal Giriş) ---
        var data = doc.data() as Map<String, dynamic>;
        String gercekPin = data['admin_pin'] ?? "1234"; 

        // Hem dükkanın kendi şifresiyle, hem de veritabanından gelen Master Key ile girebilirsin
        if (girilenPin == gercekPin || (dbMasterKey.isNotEmpty && girilenPin == dbMasterKey)) { 
          girisBasarili = true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı Şifre!"), backgroundColor: Colors.red));
        }
      } else {
        // --- 2. SENARYO: MAĞAZA YOK (Yeni Kayıt) ---
        
        // Veritabanından çektiğimiz Master Key doğru girildiyse oluştur
        if (dbMasterKey.isNotEmpty && girilenPin == dbMasterKey) {
           yeniKurulum = true;
           girisBasarili = true;
           
           // Yeni mağazayı oluştur
           await docRef.set({
             'firma_adi': _kodController.text.toUpperCase(), 
             'admin_pin': "1234", 
             'sarrafiye_makas': 0.02,
             // ... Varsayılan değerler ...
           });
           
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeni Mağaza Lisansı Veritabanına İşlendi!"), backgroundColor: Colors.green));
        } else {
           _hataGoster("Mağaza Bulunamadı! Lisans almak için iletişime geçiniz.");
        }
      }

      if (girisBasarili) {
        await DB.girisYap(girilenKod);
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PosScreen()));
        }
      }

    } catch (e) {
      _hataGoster("Bağlantı Hatası: $e");
    } finally {
      if(mounted) setState(() => _yukleniyor = false);
    }
  }

  void _hataGoster(String mesaj) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Giriş Başarısız"),
        content: Text(mesaj),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Tamam"))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2631),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(30),
            margin: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond, size: 60, color: Color(0xFFD4AF37)),
                const SizedBox(height: 10),
                const Text("UZMAN KUYUMCU", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const Text("Kuyumcu Yönetim Sistemi", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                // MAĞAZA KODU GİRİŞİ
                TextField(
                  controller: _kodController,
                  decoration: const InputDecoration(
                    labelText: "Mağaza Kodu",
                    hintText: "Örn: magaza_adi",
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white
                  ),
                ),
                const SizedBox(height: 15),
                
                // ŞİFRE GİRİŞİ
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.text, // Master key için text yaptık
                  decoration: const InputDecoration(
                    labelText: "Yönetici Şifresi",
                    hintText: "****",
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // GİRİŞ BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _yukleniyor ? null : _girisYap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2631), 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    child: _yukleniyor 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("GİRİŞ YAP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // DİPNOT
                const Text(
                  "Yeni kurulum için Master Key kullanınız.",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }}
  class FisIslemleri {
  
  static double _safeParse(dynamic val) {
    if (val == null) return 0;
    String temiz = val.toString().replaceAll('₺', '').replaceAll('TL', '').trim();
    if (temiz.contains(',')) {
      temiz = temiz.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(temiz) ?? 0;
  }

  static Future<void> yazdir(BuildContext context, Map<String, dynamic> data, String firmaAdi) async {
    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 2);

      final doc = pw.Document();
      
      // Tarih Ayarı
      String tarih = "-";
      if (data['tarih'] != null) {
        if (data['tarih'] is Timestamp) {
          tarih = DateFormat('dd.MM.yyyy HH:mm').format((data['tarih'] as Timestamp).toDate());
        } else if (data['tarih'] is DateTime) {
          tarih = DateFormat('dd.MM.yyyy HH:mm').format(data['tarih']);
        } else {
          tarih = data['tarih'].toString();
        }
      }

      String personel = data['personel'] ?? "-";
      String odeme = data['odeme_tipi'] ?? "-";
      double toplamTutar = (data['tutar'] ?? 0).toDouble();
      List<dynamic> urunler = data['urunler'] ?? [];

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context pdfCtx) {
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Center(child: pw.Text(firmaAdi, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16), textAlign: pw.TextAlign.center)),
              pw.Center(child: pw.Text("Müşteri Bilgi Fişi", style: const pw.TextStyle(fontSize: 10))),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Tarih:"), pw.Text(tarih)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Satış:"), pw.Text(personel)]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Ödeme:"), pw.Text(odeme)]),
              pw.Divider(),
              
              ...urunler.map((uString) {
                  List<String> p = uString.toString().split(" | ");
                  String ad = p[0];
                  String miktar = p.length > 1 ? p[1] : "";
                  String fiyat = "";
                  if(p.length > 2) {
                     double val = _safeParse(p[2]); 
                     fiyat = fmt.format(val);
                  }
                  
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text("$ad $miktar", style: const pw.TextStyle(fontSize: 10))),
                        pw.Text(fiyat, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ]
                    )
                  );
              }).toList(),
              
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("TOPLAM:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), 
                  pw.Text(fmt.format(toplamTutar), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))
              ]),
              pw.SizedBox(height: 20), 
              pw.Center(child: pw.Text("İyi Günler Dileriz...", style: const pw.TextStyle(fontSize: 10))),
              pw.Center(child: pw.Text("Mali Değeri Yoktur", style: const pw.TextStyle(fontSize: 8))),
          ]);
        }
      ));
      
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      print("Yazıcı Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yazıcı hatası oluştu."), backgroundColor: Colors.red));
    }
  }
}