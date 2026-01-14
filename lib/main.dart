import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ErenKuyumculukApp());
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

class ErenKuyumculukApp extends StatelessWidget {
  const ErenKuyumculukApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bigbos Eren Kuyumculuk',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B2631),
          primary: const Color(0xFF1B2631),
          secondary: const Color(0xFFD4AF37),
        ),
        scaffoldBackgroundColor: const Color(0xFFEDEFF5),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
      ),
      home: const PosScreen(),
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

  // Sepet ve Kontrolcüler
  final List<SatisSatiri> _sepet = [];
  final TextEditingController _hasSatisManuelController = TextEditingController();
  
  // Takı Formu
  String _formSecilenTur = "std_kolye";
  final TextEditingController _formGramController = TextEditingController();
  final TextEditingController _formMilyemController = TextEditingController();

  // Hurda Formu
  final TextEditingController _hurdaGramController = TextEditingController();
  final TextEditingController _hurdaMilyemController = TextEditingController();

  List<String> _personelListesi = ["Mağaza"];
  String? _secilenPersonel;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _firebaseDinle();
  }

  // --- FIREBASE DİNLEYİCİLERİ ---
  void _firebaseDinle() {
    // 1. Ayarları Dinle
    FirebaseFirestore.instance.collection('ayarlar').doc('genel').snapshots().listen((doc) {
      if (doc.exists) {
        setState(() {
          _ayarlar = doc.data()!;
          
          // Toptan Aralıkları
          if (_ayarlar.containsKey('toptan_araliklar')) {
            _toptanAraliklar = List.from(_ayarlar['toptan_araliklar']);
            _toptanAraliklar.sort((a, b) => (a['limit'] as num).compareTo(b['limit'] as num));
          }
          
          // Personel Listesi
          if (_ayarlar.containsKey('personel_listesi')) {
            _personelListesi = List<String>.from(_ayarlar['personel_listesi']);
          }
          _otomatikDegerleriGuncelle();

          // Hurda Ayarları (DİNAMİK)
          // Hurda Ayarları (DİNAMİK & ALFABETİK SIRALI)
          if (_ayarlar.containsKey('hurda_ayarlari')) {
            Map<String, dynamic> hAyarlar = _ayarlar['hurda_ayarlari'];
            
            _hurdaAlisMilyemleri.clear();
            _hurdaHasMilyemleri.clear();
            
            // 1. Önce anahtarları (isimleri) alıp listeye çeviriyoruz
            var siraliAnahtarlar = hAyarlar.keys.toList();
            
            // 2. Bu listeyi Alfabetik olarak sıralıyoruz (A'dan Z'ye)
            siraliAnahtarlar.sort(); 

            // 3. Sıralanmış liste üzerinden dönerek Map'i dolduruyoruz
            // Böylece dropdown'da bu sırayla gözükecek.
            for (var k in siraliAnahtarlar) {
              List<dynamic> vals = hAyarlar[k]; 
              _hurdaAlisMilyemleri[k] = (vals[0] as num).toDouble();
              _hurdaHasMilyemleri[k] = (vals[1] as num).toDouble();
            }
            
            // Eğer seçili tür listede yoksa ilkini seç
            if (_hurdaAlisMilyemleri.isNotEmpty) {
               if (_hurdaSecilenTur == null || !_hurdaAlisMilyemleri.containsKey(_hurdaSecilenTur)) {
                 _hurdaSecilenTur = _hurdaAlisMilyemleri.keys.first;
                 // İlk değerin milyemini de ekrana basalım
                 _hurdaMilyemController.text = _hurdaAlisMilyemleri[_hurdaSecilenTur]!.toStringAsFixed(3);
               }
            }
          }
        });
      }
    });

    // 2. Piyasayı Dinle
    FirebaseFirestore.instance.collection('piyasa').doc('canli').snapshots().listen((doc) {
      if (doc.exists) {
        var data = doc.data()!;
        _piyasaVerileri = data;
        Timestamp? sunucuZamani = data['tarih'];
        bool veriTaze = false;
        bool guvenlikKilidi = false;

        if (sunucuZamani != null) {
          Duration fark = DateTime.now().difference(sunucuZamani.toDate());
          if (fark.inSeconds < 60) {
            veriTaze = true;
          } else if (fark.inMinutes >= 3) guvenlikKilidi = true;
        } else {
          guvenlikKilidi = true;
        }

        setState(() {
          _veriGuncelMi = veriTaze;
          if (guvenlikKilidi) {
            _canliHasAlis = 0;
            _canliHasSatis = 0;
            if (!_fiyatSabit) {
               _hasSatisManuelController.text = "";
               _kilitliHasAlis = 0;
            }
          } else {
            _canliHasAlis = (data['alis'] as num).toDouble();
            _canliHasSatis = (data['satis'] as num).toDouble();
            if (!_fiyatSabit) {
               double mevcutDeger = double.tryParse(_hasSatisManuelController.text) ?? 0;
               if (mevcutDeger != _canliHasSatis) {
                  _hasSatisManuelController.text = _canliHasSatis.toString();
               }
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
    if (satir.isHurda) {
       // HURDA İSE: Alış fiyatı üzerinden hesaplanır
       if(satir.tur.contains("ziynet")) {
         return satir.gram * satir.deger; // Adet * Birim Fiyat
       } else {
         double alisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;
         return satir.gram * satir.deger * alisFiyati; // Gram * Milyem * Has Alış
       }
    }
    
    // SATIŞ İSE
    if (satir.tur.startsWith("ziynet")) {
      return satir.gram * satir.deger;
    } else if (satir.tur.startsWith("wedding")) return hasFiyat * (satir.gram * 0.585 + satir.deger);
    else return hasFiyat * satir.gram * satir.deger;
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
  double _sepetMaliyetiniBul() {
    double toplamMaliyet = 0;
    double bazAlinacakHasMaliyet = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis; 

    for(var s in _sepet) {
      if (!s.isHurda) { // Sadece satışların maliyeti
        if(s.tur.startsWith("ziynet")) {
          String turKod = s.tur.replaceAll("ziynet_", "");
          var urun = _ziynetTurleri.firstWhere((e) => e['id'] == turKod, orElse: () => {});
          if(urun.isNotEmpty) {
             String anahtar = "${urun['id']}_satis_has";
             double hamHas = (_piyasaVerileri.containsKey(anahtar)) ? (_piyasaVerileri[anahtar] as num).toDouble() : urun['def_has'];
             toplamMaliyet += (hamHas * s.gram * bazAlinacakHasMaliyet); 
          }
        } else {
          double safOran = 0.585;
          if(s.tur.startsWith("b22") || s.tur == "b22_taki") {
            safOran = 0.916;
          } else if(s.tur.startsWith("wedding")) safOran = 0.585; 
          toplamMaliyet += (s.gram * safOran * bazAlinacakHasMaliyet);
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
    double hasAlis = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;
    
    if (gr > 0 && milyem > 0 && hasAlis > 0) {
      setState(() {
        _hurdaAnlikTutar = gr * milyem * hasAlis;
      });
    } else {
      setState(() => _hurdaAnlikTutar = 0);
    }
  }

  void _formHesapla(double gram, double milyem) {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double tutar = 0;
    SatisSatiri temp = SatisSatiri(id: "temp", tur: _formSecilenTur, urunAdi: "", gram: gram, deger: milyem);
    tutar = _satirFiyatiHesapla(temp, hasFiyat);
    setState(() => _formAnlikTutar = tutar);
  }

  // --- ANA BUILD ---
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 0);
    double ekrandakiFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double fark = ekrandakiFiyat - _canliHasSatis;

    return ResponsiveAnaSablon(
      appBar: AppBar(
        title: const Text("Bigbos Kuyumculuk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B2631),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _veriGuncelMi ? Colors.green : Colors.red, width: 1.5)
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 14, color: _veriGuncelMi ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 6),
                Text(_veriGuncelMi ? "CANLI" : "ESKİ VERİ", style: TextStyle(color: _veriGuncelMi ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))
              ],
            ),
          ),
          IconButton(icon: Icon(_sunumModu ? Icons.visibility_off : Icons.visibility, color: _sunumModu ? Colors.orange : Colors.white), onPressed: () => setState(() => _sunumModu = !_sunumModu)),
          IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: () => _gecmisSatislariGoster(context, fmt)),
          IconButton(icon: const Icon(Icons.admin_panel_settings, color: Colors.white70), onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
          })
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              if(!_sunumModu)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                color: const Color(0xFF212F3C),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _fiyatKutusu("HAS ALIŞ", _kilitliHasAlis.toStringAsFixed(2), Colors.orangeAccent, readOnly: true),
                          const SizedBox(width: 20),
                          _fiyatKutusu("HAS SATIŞ", "", const Color(0xFF2ECC71), controller: _hasSatisManuelController),
                          const SizedBox(width: 10),
                          Column(children: [
                            Transform.scale(scale: 1.3, child: Checkbox(
                              value: _fiyatSabit, activeColor: Colors.red, side: const BorderSide(color: Colors.white54, width: 2),
                              onChanged: (val) { setState(() { _fiyatSabit = val!; if (!_fiyatSabit) { _hasSatisManuelController.text = _canliHasSatis.toString(); _kilitliHasAlis = _canliHasAlis; } }); },
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
  bool ziynetMi = s.tur.startsWith("ziynet");
  // Ziynet mi kontrolünü hem satış hem hurda için kapsayacak şekilde genişletiyoruz:
  bool isZiynetItem = s.tur.contains("ziynet"); 
  double guncelKur = double.tryParse(_hasSatisManuelController.text) ?? 0;

  // --- FİYAT GÖSTERİM DÜZELTMESİ ---
  double guncelTutar;
  if (hurdaMi) {
       // Eğer hurda ZİYNET ise: Adet * Birim Fiyat (Zaten hesaplanmış geliyor)
       if(isZiynetItem) {
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

  // ... (eskiTutar hesaplama kısmı aynı kalabilir) ...
  double? eskiTutar;
  if (s.eskiDeger != null && s.eskiDeger != s.deger && !ziynetMi && !hurdaMi) {
    eskiTutar = s.gram * s.eskiDeger! * guncelKur;
  }

  return Container(
    // ... (Container dekorasyonu aynı) ...
    child: Row(
      children: [
        // ... (İkon kısmı aynı) ...
        hurdaMi 
          ? const Icon(Icons.recycling, color: Colors.red, size: 28) 
          : (ziynetMi ? const Icon(Icons.monetization_on, color: Colors.orange, size: 28) : const Icon(Icons.diamond, color: Colors.blue, size: 28)),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.urunAdi, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: hurdaMi ? Colors.red : Colors.black)),
              // ... (Milyem gösterimi aynı) ...
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
              // DEĞİŞEN KISIM: Hem satış ziynet hem hurda ziynet için "Ad" yazar
              isZiynetItem ? "${s.gram.toInt()} Ad" : "${s.gram} Gr",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ... (Fiyat gösterim kısmı aynı, guncelTutar artık doğru) ...
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
          DropdownButtonFormField<String>(
            value: _urunCesitleri.containsKey(_formSecilenTur) ? _formSecilenTur : _urunCesitleri.keys.first,
            decoration: const InputDecoration(labelText: "Ürün Türü", prefixIcon: Icon(Icons.category)),
            items: _urunCesitleri.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (val) {
              setState(() {
                _formSecilenTur = val!;
                _milyemElleDegisti = false;
                _formAnlikTutar = 0;

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
          Row(
            children: [
              Expanded(child: TextField(
                controller: _formGramController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Gram", suffixText: "gr", prefixIcon: Icon(Icons.scale)),
                onChanged: (val) {
                  double gr = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                  if (gr > 0 && !_milyemElleDegisti) {
                      double otoMilyem = _dinamikMilyemBul(_formSecilenTur, gr);
                      _formMilyemController.text = otoMilyem.toStringAsFixed(3);
                      _formHesapla(gr, otoMilyem);
                  } else if (gr > 0 && _milyemElleDegisti) {
                      double mevcutMilyem = double.tryParse(_formMilyemController.text) ?? 0;
                      _formHesapla(gr, mevcutMilyem);
                  } else {
                    setState(() => _formAnlikTutar = 0);
                  }
                },
              )),
              const SizedBox(width: 15),
              if(!_sunumModu)
              Expanded(child: TextField(
                controller: _formMilyemController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "İşçilik / Milyem",
                  prefixIcon: Icon(Icons.percent, size: 18),
                ),
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
          
          if(!_sunumModu)
          const SizedBox(height: 20),

          if (_formAnlikTutar > 0)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200)
            ),
            child: Column(
              children: [
                const Text("HESAPLANAN TUTAR", style: TextStyle(fontSize: 10, color: Colors.green)),
                Text(fmt.format(_formAnlikTutar), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),

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
                    _formGramController.clear();
                    _formMilyemController.clear();
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

  Widget _buildZiynetGrid(NumberFormat fmt) {
    double hasAlisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.8, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _ziynetTurleri.length,
      itemBuilder: (context, index) {
        var urun = _ziynetTurleri[index];
        double birimFiyat = _ziynetBirimFiyatHesapla(urun);
        return Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: urun['id'].toString().startsWith('y') ? Colors.white : const Color(0xFFFFF8E1),
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
                    deger: birimFiyat,
                    isManuel: true,
                  ));
                } else {
                  mevcut.gram++;
                  mevcut.deger = birimFiyat;
                }
                _sepetAcik = true;
              });
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(urun['ad'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(fmt.format(birimFiyat), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF27AE60))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
 Widget _buildHurdaFormu(NumberFormat fmt) {
    double hasAlisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.red.shade50, 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: Colors.red.shade200)
            ),
            child: const Center(
              child: Text("HURDA / BOZUM İŞLEMİ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  // --- DÜZELTME 1: DROPDOWN KİLİTLENME SORUNU ---
                  DropdownButtonFormField<String>(
                    // Eğer seçili olan listede yoksa null yap ki hata vermesin
                    value: _hurdaAlisMilyemleri.containsKey(_hurdaSecilenTur) ? _hurdaSecilenTur : null,
                    decoration: const InputDecoration(
                      labelText: "Hurda Türü", 
                      prefixIcon: Icon(Icons.recycling, color: Colors.red),
                      fillColor: Colors.white
                    ),
                    items: _hurdaAlisMilyemleri.keys.map((tur) => DropdownMenuItem(value: tur, child: Text(tur))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _hurdaSecilenTur = val!;
                        if (_hurdaAlisMilyemleri.containsKey(_hurdaSecilenTur)) {
                           double m = _hurdaAlisMilyemleri[_hurdaSecilenTur]!;
                           _hurdaMilyemController.text = m.toStringAsFixed(3);
                        }
                        _hurdaHesapla();
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hurdaGramController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "Gram", suffixText: "gr", prefixIcon: Icon(Icons.scale, color: Colors.red)),
                          onChanged: (v) => _hurdaHesapla(),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _hurdaMilyemController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: "Milyem", prefixIcon: Icon(Icons.analytics, color: Colors.red)),
                          onChanged: (v) => _hurdaHesapla(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  if (_hurdaAnlikTutar > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        const Text("ÖDENECEK TUTAR", style: TextStyle(fontSize: 10, color: Colors.red)),
                        Text(fmt.format(_hurdaAnlikTutar), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        double gr = double.tryParse(_hurdaGramController.text.replaceAll(',', '.')) ?? 0;
                        double milyem = double.tryParse(_hurdaMilyemController.text.replaceAll(',', '.')) ?? 0;

                        if (gr > 0 && milyem > 0) {
                          setState(() {
                            _sepet.add(SatisSatiri(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              tur: "hurda_$_hurdaSecilenTur", 
                              urunAdi: "$_hurdaSecilenTur Hurda",
                              gram: gr,
                              deger: milyem, 
                              isHurda: true, 
                              isManuel: true,
                            ));
                            _sepetAcik = true;
                            _hurdaGramController.clear();
                            _hurdaAnlikTutar = 0;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hurda Sepete Eklendi"), backgroundColor: Colors.red));
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("HURDA SEPETİNE EKLE"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                    ),
                  ),
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
              double alisBirimFiyat = hasAlisFiyati * urun['def_has'];
              
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: Colors.red.shade50, 
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _sepet.add(SatisSatiri(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        tur: "hurda_ziynet_${urun['id']}",
                        urunAdi: "${urun['ad']} (BOZUM)",
                        gram: 1, 
                        deger: alisBirimFiyat, 
                        isHurda: true,
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

    double guncelTutar = hamNakit * (1 + (oran / 100));
    double? eskiTutar;

    if (hamEski > hamNakit + 1) {
       eskiTutar = hamEski * (1 + (oran / 100));
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

  Widget _sepetIciToptanButonu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: Colors.amber.shade50,
      child: ElevatedButton.icon(
        onPressed: () {
          if (_sepet.isEmpty) return;

          double sepetteki14kGram = 0;
          for (var urun in _sepet) {
            if (urun.tur.startsWith("std_")) {
              sepetteki14kGram += urun.gram;
            }
          }

          if (sepetteki14kGram == 0) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sepette standart 14 ayar ürün yok.")));
             return;
          }

          double onerilenMilyem = 0;
          List<dynamic> araliklar = _toptanAraliklar.isNotEmpty ? _toptanAraliklar : [
             {'limit': 5, 'carpan': 0.90}, {'limit': 10, 'carpan': 0.85}, {'limit': 15, 'carpan': 0.82}, {'limit': 25, 'carpan': 0.77},
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
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Toplam $sepetteki14kGram gr bulundu. Milyem $onerilenMilyem olarak güncellendi! ($guncellenenAdet ürün)"),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          });
        },
        icon: const Icon(Icons.discount, color: Colors.black87),
        label: const Text("TOPTAN HESAPLA & İNDİRİM UYGULA", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          minimumSize: const Size(double.infinity, 45),
          elevation: 2,
        ),
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
              
              const SizedBox(height: 15),
              TextButton.icon(onPressed: () => _fisYazdir(fmt), icon: const Icon(Icons.print), label: const Text("FİŞ ÖNİZLEME"))
            ]),
          );
        });
      }
    );
  }
Future<void> _satisiTamamla(String odemeTipi) async {
    if (_secilenPersonel == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen Personel Seçin!"), backgroundColor: Colors.red)); return; }
    Navigator.pop(context); 

    double satisOrani = 0;     
    double bankaMaliyetOrani = 0; 
    
    if(odemeTipi == "Tek Çekim") {
       satisOrani = (_ayarlar['cc_single_rate'] ?? 0).toDouble();
       bankaMaliyetOrani = (_ayarlar['pos_cost_single'] ?? 0).toDouble(); 
    }
    else if(odemeTipi == "3 Taksit") {
       satisOrani = (_ayarlar['cc_install_rate'] ?? 0).toDouble();
       bankaMaliyetOrani = (_ayarlar['pos_cost_install'] ?? 0).toDouble(); 
    }

    double hamSatisTutari = _toplamNakit; // Vade eklenmemiş saf tutar
    double tahsilEdilenTutar = hamSatisTutari * (1 + (satisOrani / 100)); // Müşteriden çekilen
    
    double bankaKomisyonTutari = tahsilEdilenTutar * (bankaMaliyetOrani / 100);
    double netEleGecen = tahsilEdilenTutar - bankaKomisyonTutari;

    // --- KAR HESAPLAMA ---
    double satisUrunMaliyeti = _sepetMaliyetiniBul();
    double toplamHurdaKari = 0;
    double bazHasFiyat = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;

    for (var s in _sepet) {
      if (s.isHurda) {
        String safTurAdi = s.tur.replaceFirst("hurda_", ""); 
        double musteriyeOdenenMilyem = s.deger;
        
        // Hurda takı ise kar hesapla (Ziynette karı ihmal ediyoruz veya 0 sayıyoruz şimdilik)
        if (!s.tur.contains("ziynet") && _hurdaHasMilyemleri.containsKey(safTurAdi)) {
           double gercekHasMilyem = _hurdaHasMilyemleri[safTurAdi]!;
           double buSatirKari = s.gram * (gercekHasMilyem - musteriyeOdenenMilyem) * bazHasFiyat;
           toplamHurdaKari += buSatirKari;
        }
      } 
    }
    
    // Sadece satılan ürünlerin cirosunu bul (Hurda hariç)
    double sadeceSatisCirosu = 0;
    for(var s in _sepet) { 
        if(!s.isHurda) {
            // Satış satırının ham fiyatını bul
             if (s.tur.startsWith("ziynet")) {
                sadeceSatisCirosu += s.gram * s.deger;
             } else {
                double kur = double.tryParse(_hasSatisManuelController.text) ?? 0;
                sadeceSatisCirosu += s.gram * s.deger * kur;
             }
        } 
    }

    // 1. Ürün Karı (Altın alım-satım farkı)
    double sadeceSatisKari = sadeceSatisCirosu - satisUrunMaliyeti;
    
    // 2. Vade Farkı Geliri (Müşteriden alınan fazladan % tutar)
    double vadeFarkiGeliri = hamSatisTutari * (satisOrani / 100); 
    
    // 3. Toplam Net Kar
    // (Satış Karı + Hurda Karı + Vade Geliri) - Banka Komisyonu
    double netKar = sadeceSatisKari + toplamHurdaKari + vadeFarkiGeliri - bankaKomisyonTutari;

    try {
      await FirebaseFirestore.instance.collection('satis_gecmisi').add({
        'tarih': FieldValue.serverTimestamp(), 
        'personel': _secilenPersonel, 
        'tutar': tahsilEdilenTutar, // Kasa Girişi
        'net_ele_gecen': netEleGecen, // Banka düşülmüş giriş
        
        // --- DETAYLI ANALİZ VERİLERİ ---
        'ham_tutar': hamSatisTutari,
        'vade_farki_geliri': vadeFarkiGeliri,
        'urun_satis_kari': sadeceSatisKari + toplamHurdaKari, // Saf ticaret karı
        'pos_gideri': bankaKomisyonTutari, 
        'kar': netKar, // Her şey dahil net cepte kalan
        
        'odeme_tipi': odemeTipi, 
        'has_fiyat': _canliHasSatis,
        'urunler': _sepet.map((s) => s.tur.contains("ziynet") ? "${s.urunAdi} (${s.gram.toInt()} Ad)" : "${s.urunAdi} (${s.gram} Gr)").toList(),
      });
      
      setState(() { _sepet.clear(); _secilenPersonel = null; _sepetAcik = false; });
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Satış Başarılı! Net Kar: ${NumberFormat.currency(locale:"tr", symbol:"₺").format(netKar)}"), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          )
        );
      }
    } catch(e) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu!"), backgroundColor: Colors.red));
    }
  }

  Future<void> _fisYazdir(NumberFormat fmt) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Center(child: pw.Text("BIGBOS EREN KUYUMCULUK", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))),
            pw.Divider(),
            pw.Text("Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}"),
            pw.Text("Personel: ${_secilenPersonel ?? '-'}"),
            pw.Divider(),
            ..._sepet.map((s) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(s.tur.startsWith("ziynet") ? "${s.urunAdi} x${s.gram.toInt()}" : "${s.urunAdi} (${s.gram} gr)"),
              pw.Text(fmt.format(s.deger * s.gram)),
            ])),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("TOPLAM:"), pw.Text(fmt.format(_toplamNakit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
            pw.SizedBox(height: 20), pw.Center(child: pw.Text("Tesekkur Ederiz"))
        ]);
      }
    ));
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

void _gecmisSatislariGoster(BuildContext context, NumberFormat fmt) {
    // Artık basit bir BottomSheet değil, profesyonel bir sayfaya gidiyoruz
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

  final TextEditingController _sarrafiyeMakasController = TextEditingController();
  
  final TextEditingController _ccSingleController = TextEditingController();
  final TextEditingController _ccInstallController = TextEditingController();

  final TextEditingController _posCostSingleCtrl = TextEditingController();
  final TextEditingController _posCostInstallCtrl = TextEditingController();

  final TextEditingController _weddingPlainCtrl = TextEditingController();
  final TextEditingController _weddingPatternCtrl = TextEditingController();
  final TextEditingController _b22SarnelCtrl = TextEditingController();
  final TextEditingController _b22AjdaCtrl = TextEditingController();
  final TextEditingController _b22TakiCtrl = TextEditingController(); 
  final TextEditingController _maxFactorCtrl = TextEditingController();

  List<Map<String, dynamic>> _dinamikHurdaListesi = [];
  List<Map<String, dynamic>> _toptanListesi = [];
  List<String> _personelListesi = [];

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('ayarlar').doc('genel').get().then((doc) {
      if(doc.exists) {
        var data = doc.data()!;
        setState(() {
          _sarrafiyeMakasController.text = (data['sarrafiye_makas'] ?? 0.02).toString();
          
          _ccSingleController.text = (data['cc_single_rate'] ?? 7).toString();
          _ccInstallController.text = (data['cc_install_rate'] ?? 12).toString();
          
          _posCostSingleCtrl.text = (data['pos_cost_single'] ?? 0).toString();
          _posCostInstallCtrl.text = (data['pos_cost_install'] ?? 0).toString();

          _weddingPlainCtrl.text = (data['factor_wedding_plain'] ?? 0.60).toString();
          _weddingPatternCtrl.text = (data['factor_wedding_pattern'] ?? 0.80).toString();
          _b22SarnelCtrl.text = (data['factor_b22_Sarnel'] ?? 0.940).toString();
          _b22AjdaCtrl.text = (data['factor_b22_ajda'] ?? 0.930).toString();
          _b22TakiCtrl.text = (data['factor_b22_taki'] ?? 0.960).toString(); 
          _maxFactorCtrl.text = (data['factor_max'] ?? 0.725).toString();

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

      FirebaseFirestore.instance.collection('ayarlar').doc('genel').set({
        'sarrafiye_makas': double.parse(_sarrafiyeMakasController.text.replaceAll(',', '.')),
        
        'cc_single_rate': double.parse(_ccSingleController.text.replaceAll(',', '.')),
        'cc_install_rate': double.parse(_ccInstallController.text.replaceAll(',', '.')),
        
        'pos_cost_single': double.parse(_posCostSingleCtrl.text.replaceAll(',', '.')),
        'pos_cost_install': double.parse(_posCostInstallCtrl.text.replaceAll(',', '.')),

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
              _buildInput("22 Ayar Takı (İşçilikli)", _b22TakiCtrl), 
              
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
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _kaydet, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("TÜMÜNÜ KAYDET")))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String lbl, TextEditingController ctrl, {IconData? icon, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl, 
        decoration: InputDecoration(
          labelText: lbl,
          prefixIcon: icon != null ? Icon(icon, color: color, size: 18) : null,
          isDense: true
        ), 
        keyboardType: TextInputType.number
      ),
    );
  }
}// --- GELİŞMİŞ SATIŞ GEÇMİŞİ VE DETAYLI RAPOR EKRANI ---
class SatisGecmisiSayfasi extends StatefulWidget {
  const SatisGecmisiSayfasi({super.key});

  @override
  State<SatisGecmisiSayfasi> createState() => _SatisGecmisiSayfasiState();
}

class _SatisGecmisiSayfasiState extends State<SatisGecmisiSayfasi> {
  // Varsayılan: Bugün
  DateTime _baslangicTarihi = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _bitisTarihi = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 2); // Kuruşları da görelim

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFF5),
      appBar: AppBar(
        title: const Text("Satış Raporu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B2631),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _tarihAraligiSec,
            tooltip: "Tarih Seç",
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('satis_gecmisi')
            .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(_baslangicTarihi))
            .where('tarih', isLessThanOrEqualTo: Timestamp.fromDate(_bitisTarihi))
            .orderBy('tarih', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.manage_search, size: 80, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text("${DateFormat('dd.MM.yyyy').format(_baslangicTarihi)} tarihinde işlem yok.", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          // --- GÜNLÜK TOPLAM HESAPLAMA ---
          double toplamCiro = 0;
          double toplamNetKar = 0;
          double toplamBankaGideri = 0;
          double nakitKasa = 0;
          double posKasa = 0;

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            double tutar = (data['tutar'] ?? 0).toDouble(); // Müşteriden çıkan
            double kar = (data['kar'] ?? 0).toDouble();
            double pos = (data['pos_gideri'] ?? 0).toDouble();
            String tip = data['odeme_tipi'] ?? "Nakit";

            toplamCiro += tutar;
            toplamNetKar += kar;
            toplamBankaGideri += pos;
            
            if(tip == "Nakit") nakitKasa += tutar;
            else posKasa += tutar;
          }

          return Column(
            children: [
              // 1. DASHBOARD (ÖZET TABLOSU)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.black12))
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _dashboardKutu("TOPLAM CİRO", fmt.format(toplamCiro), Colors.blue.shade900, Icons.storefront),
                        const SizedBox(width: 10),
                        _dashboardKutu("NET KAR", fmt.format(toplamNetKar), Colors.green.shade800, Icons.verified),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _dashboardKutu("NAKİT KASA", fmt.format(nakitKasa), Colors.orange.shade800, Icons.payments),
                        const SizedBox(width: 10),
                        _dashboardKutu("POS GEÇEN", fmt.format(posKasa), Colors.purple.shade800, Icons.credit_card),
                      ],
                    ),
                    if(toplamBankaGideri > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                          const SizedBox(width: 5),
                          Text("Bugün Bankaya Ödenen Komisyon: ${fmt.format(toplamBankaGideri)}", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              // 2. DETAYLI SATIŞ LİSTESİ
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    // Temel Veriler
                    double tutar = (data['tutar'] ?? 0).toDouble();
                    double kar = (data['kar'] ?? 0).toDouble();
                    String personel = data['personel'] ?? "Belirsiz";
                    String odemeTipi = data['odeme_tipi'] ?? "Nakit";
                    Timestamp? ts = data['tarih'];
                    String saat = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : "-";
                    List<dynamic> urunler = data['urunler'] ?? [];

                    // Detaylı Finansal Veriler (Eski kayıtlarda olmayabilir diye kontrol ediyoruz)
                    double hamTutar = (data['ham_tutar'] ?? tutar).toDouble();
                    double vadeGeliri = (data['vade_farki_geliri'] ?? 0).toDouble();
                    double posGideri = (data['pos_gideri'] ?? 0).toDouble();

                    bool nakitMi = odemeTipi == "Nakit";

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias, // Taşan renkleri keser
                      child: ExpansionTile(
                        backgroundColor: Colors.white,
                        collapsedBackgroundColor: Colors.white,
                        // Sol taraf: İkon ve Tutar
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: nakitMi ? Colors.green.shade50 : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: Icon(nakitMi ? Icons.payments : Icons.credit_card, color: nakitMi ? Colors.green : Colors.purple),
                        ),
                        title: Text(
                          fmt.format(tutar), 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: nakitMi ? Colors.green.shade800 : Colors.purple.shade800)
                        ),
                        subtitle: Text("$saat  |  $personel  |  $odemeTipi", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        
                        // Sağ taraf: Kar göstergesi
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("NET KAR", style: TextStyle(fontSize: 9, color: Colors.grey)),
                            Text(fmt.format(kar), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                          ],
                        ),
                        
                        // AÇILINCA GÖRÜNEN DETAYLAR
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: Colors.grey.shade50, border: const Border(top: BorderSide(color: Colors.black12))),
                            child: Column(
                              children: [
                                // FİNANSAL TABLO
                                if(!nakitMi) ...[
                                  _detaySatiri("Ürün Nakit Fiyatı", fmt.format(hamTutar)),
                                  _detaySatiri("Vade Farkı Geliri (+)", fmt.format(vadeGeliri), renk: Colors.green),
                                  const Divider(),
                                  _detaySatiri("Karttan Çekilen", fmt.format(tutar), kalin: true),
                                  _detaySatiri("Banka Komisyonu (-)", fmt.format(posGideri), renk: Colors.red),
                                  const Divider(),
                                  _detaySatiri("NET KASA GİRİŞİ", fmt.format(tutar - posGideri), kalin: true, renk: Colors.blue.shade900),
                                  const SizedBox(height: 15),
                                ],

                                // ÜRÜN LİSTESİ
                                const Align(alignment: Alignment.centerLeft, child: Text("SATILAN ÜRÜNLER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                const SizedBox(height: 5),
                                ...urunler.map((u) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(children: [const Icon(Icons.check_circle, size: 14, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(u.toString(), style: const TextStyle(fontWeight: FontWeight.w500))) ]),
                                )),

                                const SizedBox(height: 15),
                                // ALT BİLGİ VE SİLME
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if(data.containsKey('has_fiyat'))
                                      Text("Kur: ${data['has_fiyat']} ₺", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                    
                                    TextButton.icon(
                                      onPressed: () => _satisIptalEt(doc.id), 
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                      label: const Text("Satışı İptal Et", style: TextStyle(color: Colors.red)),
                                      style: TextButton.styleFrom(backgroundColor: Colors.red.shade50),
                                    )
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Yardımcı Widget: Dashboard Kutusu
  Widget _dashboardKutu(String baslik, String deger, Color renk, IconData ikon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: renk.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(ikon, color: renk, size: 22),
            const SizedBox(height: 4),
            Text(baslik, style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(deger, style: TextStyle(color: renk, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  // Yardımcı Widget: Detay Satırı
  Widget _detaySatiri(String sol, String sag, {bool kalin = false, Color? renk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(sol, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(sag, style: TextStyle(color: renk ?? Colors.black87, fontWeight: kalin ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ],
      ),
    );
  }

  // Tarih Filtresi
  void _tarihAraligiSec() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _baslangicTarihi, end: _bitisTarihi),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF1B2631),
            colorScheme: const ColorScheme.light(primary: Color(0xFF1B2631)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _baslangicTarihi = picked.start;
        // Seçilen bitiş gününün gecesine kadar (23:59:59)
        _bitisTarihi = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  // Satış Silme
  void _satisIptalEt(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Satışı Sil"),
        content: const Text("Bu işlem geri alınamaz. Kasa ve ciro raporlarından düşülecektir.\nEmin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseFirestore.instance.collection('satis_gecmisi').doc(docId).delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kayıt başarıyla silindi.")));
            },
            child: const Text("Evet, Sil"),
          )
        ],
      ),
    );
  }
}