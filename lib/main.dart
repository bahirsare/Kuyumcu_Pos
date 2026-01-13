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

// --- RESPONSIVE ANA ŞABLON (YENİ EKLENDİ) ---
// Bu widget bütün ekranları sarar, klavye sorununu çözer ve tablette ortalar.
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
      // Boşluğa tıklayınca klavyeyi kapat
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        backgroundColor: const Color(0xFFEDEFF5), // Ana arkaplan rengi
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // Tablet ve Web için maksimum genişlik sınırı (Çok yayılmasın)
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

// --- VERİ MODELLERİ ---
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
    this.isHurda=false,
  });
}

// --- ANA EKRAN (POS) ---
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // PİYASA VE AYARLAR
  double _canliHasAlis = 0;
  double _canliHasSatis = 0;
  double _kilitliHasAlis = 0;

  bool _fiyatSabit = false;
  bool _sunumModu = false;
  bool _toptanModu = false;
  bool _veriGuncelMi = false;
  bool _sepetAcik = false;

  bool _milyemElleDegisti = false;

  // Takı Formu Anlık Hesap
  double _formAnlikTutar = 0;

  Map<String, dynamic> _ayarlar = {};
  List<dynamic> _toptanAraliklar = [];
  Map<String, dynamic> _piyasaVerileri = {};

  final List<SatisSatiri> _sepet = [];
  final TextEditingController _hasSatisManuelController = TextEditingController();

  List<String> _personelListesi = ["Mağaza"];

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
    "b22_bilezik": "22 Ayar Bilezik",
    "b22_ajda": "Ajda (22K)",
    "b22_sarnel": "Şarnel (22K)",
  };

  String? _secilenPersonel;

  String _formSecilenTur = "std_kolye";
  final TextEditingController _formGramController = TextEditingController();
  final TextEditingController _formMilyemController = TextEditingController();

  final TextEditingController _hurdaGramController = TextEditingController();
  final TextEditingController _hurdaMilyemController = TextEditingController();
  double _hurdaAnlikTutar = 0;
  // ZİYNET LISTESI
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

Widget _buildHurdaFormu(NumberFormat fmt) {
    // Hızlı Ayar Butonları için Veri
    final ayarlar = [
      {'ad': '22 Ayar', 'milyem': 0.916},
      {'ad': '18 Ayar', 'milyem': 0.750},
      {'ad': '14 Ayar', 'milyem': 0.585},
      {'ad': '8 Ayar',  'milyem': 0.333},
      {'ad': 'Gümüş',   'milyem': 0.0}, // Gümüş için özel hesap gerekebilir, şimdilik manuel
    ];

    double hasAlisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // BİLGİLENDİRME KUTUSU
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
            child: Column(
              children: [
                const Text("İŞLEM TÜRÜ: HURDA ALIŞ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Text("Baz Alınan Has Alış: ${hasAlisFiyati.toStringAsFixed(2)} ₺", style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),

          // HIZLI SEÇİM BUTONLARI
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ayarlar.map((ayar) {
              return ActionChip(
                label: Text(ayar['ad'] as String),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.red.shade300),
                onPressed: () {
                  _hurdaMilyemController.text = (ayar['milyem'] as double).toString();
                  // Eğer gram girildiyse hemen hesapla
                  _hurdaHesapla();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // GİRİŞ ALANLARI
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hurdaGramController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Gram", suffixText: "gr", prefixIcon: Icon(Icons.scale, color: Colors.red)),
                  onChanged: (v) => _hurdaHesapla(),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _hurdaMilyemController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Milyem", prefixIcon: Icon(Icons.analytics, color: Colors.red)),
                  onChanged: (v) => _hurdaHesapla(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // HESAPLANAN TUTAR
          if (_hurdaAnlikTutar > 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200)
              ),
              child: Column(
                children: [
                  const Text("ÖDENECEK TUTAR", style: TextStyle(fontSize: 10, color: Colors.red)),
                  Text(fmt.format(_hurdaAnlikTutar), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),

          // SEPETE EKLE BUTONU
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
                      tur: "hurda",
                      urunAdi: "Hurda (${milyem.toStringAsFixed(3)})",
                      gram: gr,
                      deger: milyem, // Milyem değerini saklıyoruz
                      isHurda: true, // BU BİR HURDADIR
                      isManuel: true,
                    ));
                    _sepetAcik = true;
                    _hurdaGramController.clear();
                    _hurdaMilyemController.clear();
                    _hurdaAnlikTutar = 0;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hurda Sepete Eklendi (Tutar Düşüldü)")));
                }
              },
              icon: const Icon(Icons.download),
              label: const Text("SEPETE EKLE (TUTARDAN DÜŞ)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15)
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _hurdaHesapla() {
    double gr = double.tryParse(_hurdaGramController.text.replaceAll(',', '.')) ?? 0;
    double milyem = double.tryParse(_hurdaMilyemController.text.replaceAll(',', '.')) ?? 0;
    
    // Alış fiyatını kullanıyoruz
    double hasAlis = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;
    
    if (gr > 0 && milyem > 0 && hasAlis > 0) {
      setState(() {
        _hurdaAnlikTutar = gr * milyem * hasAlis;
      });
    } else {
      setState(() => _hurdaAnlikTutar = 0);
    }
  }

  void _firebaseDinle() {
    FirebaseFirestore.instance.collection('ayarlar').doc('genel').snapshots().listen((doc) {
      if (doc.exists) {
        setState(() {
          _ayarlar = doc.data()!;
          if (_ayarlar.containsKey('toptan_araliklar')) {
            _toptanAraliklar = List.from(_ayarlar['toptan_araliklar']);
            _toptanAraliklar.sort((a, b) => (a['limit'] as num).compareTo(b['limit'] as num));
          }
          if (_ayarlar.containsKey('personel_listesi')) {
            _personelListesi = List<String>.from(_ayarlar['personel_listesi']);
          }
          _otomatikDegerleriGuncelle();
        });
      }
    });

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

  void _otomatikDegerleriGuncelle() {
    double toplamStdGram = 0;
    if (_toptanModu) {
      for(var s in _sepet) {
        if(s.tur.startsWith("std_")) toplamStdGram += s.gram;
      }
    }
    for (var satir in _sepet) {
      if (!satir.isManuel && !satir.tur.startsWith("ziynet")) {
        double refGram = (_toptanModu && satir.tur.startsWith("std_")) ? toplamStdGram : satir.gram;
        satir.deger = _dinamikMilyemBul(satir.tur, refGram);
      }
    }
  }

  double _dinamikMilyemBul(String tur, double gram) {
    if (_ayarlar.isEmpty) return 0;

    if (tur == "b22_taki") return (_ayarlar['factor_b22_taki'] ?? 0.960).toDouble();
    if (tur == "wedding_plain") return (_ayarlar['factor_wedding_plain'] ?? 0.60).toDouble();
    if (tur == "wedding_pattern") return (_ayarlar['factor_wedding_pattern'] ?? 0.80).toDouble();
    if (tur == "b22_bilezik") return (_ayarlar['factor_b22_bilezik'] ?? 0.930).toDouble();
    if (tur == "b22_ajda" || tur == "b22_sarnel") return (_ayarlar['factor_b22_ajda'] ?? 0.930).toDouble();

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

double _satirFiyatiHesapla(SatisSatiri satir, double hasFiyat) {
    // EĞER HURDA İSE: Has Alış Fiyatını kullanmalı, gönderilen hasFiyat (Satış) değil!
    if (satir.isHurda) {
       double alisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;
       return satir.gram * satir.deger * alisFiyati;
    }
    
    // Normal Satışlar
    if (satir.tur.startsWith("ziynet")) {
      return satir.gram * satir.deger;
    } else if (satir.tur.startsWith("wedding")) return hasFiyat * (satir.gram * 0.585 + satir.deger);
    else return hasFiyat * satir.gram * satir.deger;
  }

  double _ziynetBirimFiyatHesapla(Map<String, dynamic> urun) {
    String anahtar = "${urun['id']}_satis_has";
    double hamHasMaliyeti = (_piyasaVerileri.containsKey(anahtar)) ? (_piyasaVerileri[anahtar] as num).toDouble() : urun['def_has'];
    double globalMakas = (_ayarlar['sarrafiye_makas'] ?? 0.02).toDouble();
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    return hasFiyat * (hamHasMaliyeti + globalMakas);
  }

  double _toplamKarHesapla(double hasFiyat) {
    double toplamSatis = _toplamNakit;
    double toplamMaliyet = 0;

    for(var s in _sepet) {
      if(s.tur.startsWith("ziynet")) {
        String turKod = s.tur.replaceAll("ziynet_", "");
        var urun = _ziynetTurleri.firstWhere((e) => e['id'] == turKod, orElse: () => {});
        if(urun.isNotEmpty) {
           String anahtar = "${urun['id']}_satis_has";
           double hamHas = (_piyasaVerileri.containsKey(anahtar)) ? (_piyasaVerileri[anahtar] as num).toDouble() : urun['def_has'];
           toplamMaliyet += (hamHas * s.gram * hasFiyat);
        }
      } else {
        double safOran = 0.585;
        if(s.tur.startsWith("b22") || s.tur == "b22_taki") {
          safOran = 0.916;
        } else if(s.tur.startsWith("wedding")) safOran = 0.585;
        toplamMaliyet += (s.gram * safOran * hasFiyat);
      }
    }
    return toplamSatis - toplamMaliyet;
  }
// Sepetteki ürünlerin bize maliyeti (Has Alış Fiyatından)
  double _sepetMaliyetiniBul() {
    double toplamMaliyet = 0;
    // Maliyet hesaplarken o anki "Canlı Alış" veya kilitlendiyse "Kilitli Alış" baz alınır.
    // Güvenlik için _canliHasAlis kullanıyoruz (yerine koyma maliyeti).
    double bazAlinacakHasMaliyet = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis; 

    for(var s in _sepet) {
      if(s.tur.startsWith("ziynet")) {
        String turKod = s.tur.replaceAll("ziynet_", "");
        var urun = _ziynetTurleri.firstWhere((e) => e['id'] == turKod, orElse: () => {});
        if(urun.isNotEmpty) {
           String anahtar = "${urun['id']}_satis_has"; // Piyasada genelde has maliyeti üzerinden veri gelir
           // Eğer piyasada o ürünün has karşılığı varsa onu, yoksa varsayılanı al
           double hamHas = (_piyasaVerileri.containsKey(anahtar)) ? (_piyasaVerileri[anahtar] as num).toDouble() : urun['def_has'];
           toplamMaliyet += (hamHas * s.gram * bazAlinacakHasMaliyet); 
        }
      } else {
        // Takılarda Has Oranı
        double safOran = 0.585; // 14 Ayar
        if(s.tur.startsWith("b22") || s.tur == "b22_taki") {
          safOran = 0.916; // 22 Ayar
        } else if(s.tur.startsWith("wedding")) safOran = 0.585; 
        
        toplamMaliyet += (s.gram * safOran * bazAlinacakHasMaliyet);
      }
    }
    return toplamMaliyet;
  }
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
  }double get _eskiToplamNakit {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double toplam = 0;
    for (var s in _sepet) {
      if (s.isHurda) {
         // Hurdada indirim olmaz, aynen düşüyoruz
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
  // --- ARAYÜZ (BUILD) ---
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 0);
    double ekrandakiFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double fark = ekrandakiFiyat - _canliHasSatis;

    // ResponsiveAnaSablon kullanımı
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
              // FİYAT BARI (Sunum Modunda Gizlenir)
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

              // TABLAR
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

          // --- AKORDEON SEPET ---
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
                          // SOL: Sepet İkonu ve Sayısı
                          const Icon(Icons.shopping_basket, color: Colors.white),
                          const SizedBox(width: 10),
                          Text("SEPET (${_sepet.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),

                          const Spacer(), // Araya boşluk atar

                          // SAĞ: Fiyat Bilgisi (Expanded ve FittedBox ile Taşma Çözüldü)
                          Expanded(
                            flex: 3, // Fiyata daha fazla yer ayır
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // İndirim Göstergesi (Sadece gerçekten indirim varsa)
                                if (_eskiToplamNakit > _toplamNakit + 1) ...[ // +1 tolerans
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

                                // ASIL FİYAT (Taşmayı önleyen kısım burası)
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

                 // --- 2. İÇERİK KISMI ---
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
        
        // --- DEĞİŞKENLERİ TANIMLIYORUZ ---
        bool hurdaMi = s.isHurda; // Hurda mı?
        bool ziynetMi = s.tur.startsWith("ziynet");
        double guncelKur = double.tryParse(_hasSatisManuelController.text) ?? 0;

        // Fiyat Hesaplama (Hurda ise Alış fiyatı, Satış ise Satış fiyatı aslında fonksiyonda çözülüyor ama görsel için burda da lazım)
        double guncelTutar;
        if (hurdaMi) {
             // Hurda görseli için
             double alisFiyati = _kilitliHasAlis > 0 ? _kilitliHasAlis : _canliHasAlis;
             guncelTutar = s.gram * s.deger * alisFiyati;
        } else {
             guncelTutar = ziynetMi ? (s.deger * s.gram) : (s.gram * s.deger * guncelKur);
        }

        // Eski Tutar (İndirim hesabı için)
        double? eskiTutar;
        if (s.eskiDeger != null && s.eskiDeger != s.deger && !ziynetMi && !hurdaMi) {
          eskiTutar = s.gram * s.eskiDeger! * guncelKur;
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          // Hurda ise arka plan hafif kırmızı olsun, değilse beyaz/gri
          color: hurdaMi ? Colors.red.shade50 : (index % 2 == 0 ? Colors.white : Colors.grey.shade50),
          child: Row(
            children: [
              // 1. İKON KISMI
              hurdaMi 
                ? const Icon(Icons.recycling, color: Colors.red, size: 28) // Hurda İkonu
                : (ziynetMi
                    ? const Icon(Icons.monetization_on, color: Colors.orange, size: 28)
                    : const Icon(Icons.diamond, color: Colors.blue, size: 28)),
              const SizedBox(width: 10),

              // 2. İSİM VE MİLYEM BİLGİSİ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.urunAdi, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: hurdaMi ? Colors.red : Colors.black)),

                    // Milyem gösterimi (Hurda değilse ve sunum modu kapalıysa)
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

              // 3. MİKTAR DÜZENLEME BUTONU
              InkWell(
                onTap: () => _miktarDuzenle(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    ziynetMi ? "${s.gram.toInt()} Ad" : "${s.gram} Gr",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 4. FİYAT GÖSTERİMİ (SORDUĞUN KOD BURASI)
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
                        // Hurda ise başına EKSİ koy ve Kırmızı yap
                        hurdaMi ? "- ${fmt.format(guncelTutar)}" : fmt.format(guncelTutar),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15, 
                          color: hurdaMi ? Colors.red : (eskiTutar != null ? const Color(0xFF27AE60) : Colors.black)
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. SİLME BUTONU
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
                     // C) YENİ ÖDEME PANELİ (3'lü Buton)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              border: const Border(top: BorderSide(color: Colors.black12)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                            ),
                            child: Row(
                              children: [
                                // 1. NAKİT BUTONU
                                _buildOdemeButonu(
                                  baslik: "NAKİT",
                                  oran: 0, 
                                  renk: const Color(0xFF27AE60), // Yeşil
                                  fmt: fmt,
                                  onTap: () => _odemeYap(context, fmt, baslangicTipi: "Nakit"),
                                ),

                                // 2. TEK ÇEKİM BUTONU
                                _buildOdemeButonu(
                                  baslik: "TEK ÇEKİM",
                                  oran: (_ayarlar['cc_single_rate'] ?? 0).toDouble(), // Ayarlardan gelen oran
                                  renk: const Color(0xFF2980B9), // Mavi
                                  fmt: fmt,
                                  onTap: () => _odemeYap(context, fmt, baslangicTipi: "Tek Çekim"),
                                ),

                                // 3. TAKSİT BUTONU
                                _buildOdemeButonu(
                                  baslik: "3 TAKSİT",
                                  oran: (_ayarlar['cc_install_rate'] ?? 0).toDouble(), // Ayarlardan gelen oran
                                  renk: const Color(0xFF8E44AD), // Mor
                                  fmt: fmt,
                                  onTap: () => _odemeYap(context, fmt, baslangicTipi: "3 Taksit"),
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
  Widget _buildOdemeButonu({
    required String baslik,
    required double oran, // 0 ise Nakit, değilse komisyon oranı
    required Color renk,
    required NumberFormat fmt,
    required VoidCallback onTap,
  }) {
    // 1. Fiyatları Hesapla
    double hamNakit = _toplamNakit;
    double hamEski = _eskiToplamNakit;

    // Komisyon eklenmiş halleri
    double guncelTutar = hamNakit * (1 + (oran / 100));
    double? eskiTutar;

    // Eğer indirim varsa eski fiyatı da komisyonlu hesapla
    if (hamEski > hamNakit + 1) {
       eskiTutar = hamEski * (1 + (oran / 100));
    }

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: renk,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BAŞLIK (Örn: TEK ÇEKİM)
              Text(baslik, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 4),
              
              // FİYATLAR
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    // Eski Fiyat (Varsa üstü çizili)
                    if (eskiTutar != null)
                      Text(
                        fmt.format(eskiTutar),
                        style: const TextStyle(
                          color: Colors.white70, 
                          fontSize: 10, 
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white70
                        ),
                      ),
                    // Güncel Fiyat
                    Text(
                      fmt.format(guncelTutar),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              
              // ORAN BİLGİSİ (%3 gibi)
              if(oran > 0)
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
    // RESPONSIVE FIX: FittedBox ile sığmayan yazı küçülür
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          // Genişliği 120 yerine biraz daha esnek yapabiliriz ama FittedBox zaten koruyor.
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
// --- YENİ SADELEŞTİRİLMİŞ TOPTAN BUTONU ---
  Widget _sepetIciToptanButonu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: Colors.amber.shade50, // Dikkat çekmesi için açık sarı zemin
      child: ElevatedButton.icon(
        onPressed: () {
          if (_sepet.isEmpty) return;

          // 1. Sepetteki STANDART (14 Ayar) ürünlerin gramajını topla
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

          // 2. Baremi Bul (Milyem Hesapla)
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

          // 3. SEPETİ GÜNCELLE
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
          // Klavye altında boşluk kalsın diye
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _formHesapla(double gram, double milyem) {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double tutar = 0;
    SatisSatiri temp = SatisSatiri(id: "temp", tur: _formSecilenTur, urunAdi: "", gram: gram, deger: milyem);
    tutar = _satirFiyatiHesapla(temp, hasFiyat);
    setState(() => _formAnlikTutar = tutar);
  }

  Widget _buildZiynetGrid(NumberFormat fmt) {
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

  // --- ÖDEME VE GEÇMİŞ FONKSİYONLARI ---
 // baslangicTipi parametresini ekledik
  void _odemeYap(BuildContext context, NumberFormat fmt, {String baslangicTipi = "Nakit"}) {
    // Seçilen tipe göre tutarı hemen hesaplayalım
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
              
              // Personel Seçimi
              DropdownButtonFormField<String>(
                value: _secilenPersonel,
                decoration: const InputDecoration(labelText: "Satışı Yapan Personel", prefixIcon: Icon(Icons.person)),
                items: _personelListesi.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) { setModalState(() => _secilenPersonel = val); },
              ),
              const SizedBox(height: 20),
              
              // Tutar Gösterimi
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
              
              // Büyük Onay Butonu
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
    Navigator.pop(context); // Modalı kapat

    // 1. Ürünlerin Çıplak Maliyeti
    double urunMaliyeti = _sepetMaliyetiniBul();
    
    // 2. Satış Rakamları (Müşteriden Çıkan Para)
    double satisOrani = 0;     // Müşteriye eklediğimiz vade farkı
    double bankaMaliyetOrani = 0; // Bankanın bizden kestiği komisyon
    
    if(odemeTipi == "Tek Çekim") {
       satisOrani = (_ayarlar['cc_single_rate'] ?? 0).toDouble();
       bankaMaliyetOrani = (_ayarlar['pos_cost_single'] ?? 0).toDouble(); // YENİ
    }
    else if(odemeTipi == "3 Taksit") {
       satisOrani = (_ayarlar['cc_install_rate'] ?? 0).toDouble();
       bankaMaliyetOrani = (_ayarlar['pos_cost_install'] ?? 0).toDouble(); // YENİ
    }

    double hamSatisTutari = _toplamNakit; // Nakit fiyatı
    double tahsilEdilenTutar = hamSatisTutari * (1 + (satisOrani / 100)); // Karta çekilen tutar
    
    // 3. Banka Gideri Hesaplama
    // Banka, toplam çekilen tutar üzerinden komisyon keser
    double bankaKomisyonTutari = tahsilEdilenTutar * (bankaMaliyetOrani / 100);
    
    // 4. Net Kar Hesaplama
    // Cebimize Giren = (Çekilen Tutar) - (Banka Komisyonu)
    // Net Kar = (Cebimize Giren) - (Ürün Maliyeti)
    double netEleGecen = tahsilEdilenTutar - bankaKomisyonTutari;
    double netKar = netEleGecen - urunMaliyeti;

    try {
      await FirebaseFirestore.instance.collection('satis_gecmisi').add({
        'tarih': FieldValue.serverTimestamp(), 
        'personel': _secilenPersonel, 
        'tutar': tahsilEdilenTutar, // Ciro (Müşteriden çekilen)
        'net_ele_gecen': netEleGecen, // Banka düştükten sonra (Analiz için lazım olabilir)
        'pos_gideri': bankaKomisyonTutari, // Muhasebe gideri
        'kar': netKar, // Gerçek Net Kar
        'odeme_tipi': odemeTipi, 
        'has_fiyat': _canliHasSatis,
        'urunler': _sepet.map((s) => s.tur.startsWith("ziynet") ? "${s.urunAdi} (${s.gram.toInt()} adet)" : "${s.urunAdi} (${s.gram}gr)").toList(),
      });
      
      setState(() { _sepet.clear(); _secilenPersonel = null; _sepetAcik = false; });
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Satış Başarılı! Net Kar: ${NumberFormat.currency(locale:"tr", symbol:"₺").format(netKar)} (Banka: -${bankaKomisyonTutari.toStringAsFixed(2)})"), 
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
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20), height: 600,
          child: Column(children: [
              const Text("Satış Geçmişi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('satis_gecmisi').orderBy('tarih', descending: true).limit(50).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("Henüz satış yok."));

                    double toplamCiro = 0;
                    double toplamKar = 0;
                    for (var doc in docs) {
                      var d = doc.data() as Map<String, dynamic>;
                      toplamCiro += (d['tutar'] ?? 0);
                      toplamKar += (d['kar'] ?? 0);
                    }

                    return Column(children: [
                      Container(
                        padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          Column(children: [const Text("GÜNLÜK CİRO", style: TextStyle(fontSize: 10, color: Colors.grey)), Text(fmt.format(toplamCiro), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B2631)))]),
                          Column(children: [const Text("GÜNLÜK KAR", style: TextStyle(fontSize: 10, color: Colors.grey)), Text(fmt.format(toplamKar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green))]),
                        ]),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: docs.length, separatorBuilder: (c,i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            var data = docs[index].data() as Map<String, dynamic>;
                            double tutar = (data['tutar'] ?? 0).toDouble();
                            double kar = (data['kar'] ?? 0).toDouble();
                            Timestamp? ts = data['tarih'];
                            String zaman = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : "-";
                            List<dynamic> urunler = data['urunler'] ?? [];

                            return ListTile(
                              dense: true,
                              leading: Text(zaman, style: const TextStyle(color: Colors.grey)),
                              title: Text(fmt.format(tutar), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Kar: ${kar.toStringAsFixed(0)} ₺"),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                              onTap: () {
                                showDialog(context: context, builder: (c) => AlertDialog(
                                  title: Text("Satış Detayı ($zaman)"),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: urunler.length,
                                      itemBuilder: (context, i) => ListTile(
                                        title: Text(urunler[i].toString(), style: const TextStyle(fontSize: 14)),
                                        leading: const Icon(Icons.check, size: 15, color: Colors.green),
                                      ),
                                    ),
                                  ),
                                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Kapat"))],
                                ));
                              },
                            );
                          },
                        ),
                      )
                    ]);
                  },
                ),
              )
          ]),
        );
      }
    );
  }
}
class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _sarrafiyeMakasController = TextEditingController();
  
  // SATIŞ ORANLARI (Müşteriye Yansıyan)
  final TextEditingController _ccSingleController = TextEditingController();
  final TextEditingController _ccInstallController = TextEditingController();

  // YENİ: MALİYET ORANLARI (Banka Kesintisi)
  final TextEditingController _posCostSingleCtrl = TextEditingController();
  final TextEditingController _posCostInstallCtrl = TextEditingController();

  final TextEditingController _weddingPlainCtrl = TextEditingController();
  final TextEditingController _weddingPatternCtrl = TextEditingController();
  final TextEditingController _b22BilezikCtrl = TextEditingController();
  final TextEditingController _b22AjdaCtrl = TextEditingController();
  final TextEditingController _b22TakiCtrl = TextEditingController(); 
  final TextEditingController _maxFactorCtrl = TextEditingController();

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
          
          // Yeni Alanları Çekiyoruz
          _posCostSingleCtrl.text = (data['pos_cost_single'] ?? 0).toString();
          _posCostInstallCtrl.text = (data['pos_cost_install'] ?? 0).toString();

          _weddingPlainCtrl.text = (data['factor_wedding_plain'] ?? 0.60).toString();
          _weddingPatternCtrl.text = (data['factor_wedding_pattern'] ?? 0.80).toString();
          _b22BilezikCtrl.text = (data['factor_b22_bilezik'] ?? 0.930).toString();
          _b22AjdaCtrl.text = (data['factor_b22_ajda'] ?? 0.930).toString();
          _b22TakiCtrl.text = (data['factor_b22_taki'] ?? 0.960).toString(); 
          _maxFactorCtrl.text = (data['factor_max'] ?? 0.725).toString();

          if(data.containsKey('toptan_araliklar')) {
            _toptanListesi = List<Map<String, dynamic>>.from(data['toptan_araliklar']);
          } else {
            _toptanListesi = [{'limit': 5, 'carpan': 0.90}, {'limit': 10, 'carpan': 0.85}, {'limit': 15, 'carpan': 0.82}, {'limit': 25, 'carpan': 0.77}];
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

  void _kaydet() {
    if(_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('ayarlar').doc('genel').set({
        'sarrafiye_makas': double.parse(_sarrafiyeMakasController.text.replaceAll(',', '.')),
        
        'cc_single_rate': double.parse(_ccSingleController.text.replaceAll(',', '.')),
        'cc_install_rate': double.parse(_ccInstallController.text.replaceAll(',', '.')),
        
        // Yeni maliyetleri kaydediyoruz
        'pos_cost_single': double.parse(_posCostSingleCtrl.text.replaceAll(',', '.')),
        'pos_cost_install': double.parse(_posCostInstallCtrl.text.replaceAll(',', '.')),

        'factor_wedding_plain': double.parse(_weddingPlainCtrl.text.replaceAll(',', '.')),
        'factor_wedding_pattern': double.parse(_weddingPatternCtrl.text.replaceAll(',', '.')),
        'factor_b22_bilezik': double.parse(_b22BilezikCtrl.text.replaceAll(',', '.')),
        'factor_b22_ajda': double.parse(_b22AjdaCtrl.text.replaceAll(',', '.')),
        'factor_b22_taki': double.parse(_b22TakiCtrl.text.replaceAll(',', '.')), 
        'factor_max': double.parse(_maxFactorCtrl.text.replaceAll(',', '.')),
        
        'toptan_araliklar': _toptanListesi,
        'personel_listesi': _personelListesi,
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tüm Ayarlar ve Maliyetler Kaydedildi!")));
    }
  }

  // ... (Diğer helper fonksiyonlar _listeElemanEkle vb. aynı kalacak, sadece build değişiyor)
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
              
              // TEK ÇEKİM SATIRI
              const Text("Tek Çekim:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Row(children: [
                Expanded(child: _buildInput("Satış Farkı (%)", _ccSingleController, icon: Icons.add_circle_outline, color: Colors.green)),
                const SizedBox(width: 10),
                Expanded(child: _buildInput("Banka Maliyeti (%)", _posCostSingleCtrl, icon: Icons.remove_circle_outline, color: Colors.red)),
              ]),
              
              const SizedBox(height: 10),
              
              // TAKSİTLİ ÇEKİM SATIRI
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
              // 2. ÖZEL ÜRÜNLER
              const Text("ÖZEL ÜRÜN ÇARPANLARI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              Row(children: [
                  Expanded(child: _buildInput("Düz Alyans", _weddingPlainCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Kalemli Alyans", _weddingPatternCtrl)),
              ]),
              Row(children: [
                  Expanded(child: _buildInput("22 Ayar Bilezik", _b22BilezikCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInput("Ajda / Şarnel", _b22AjdaCtrl)),
              ]),
              _buildInput("22 Ayar Takı (İşçilikli)", _b22TakiCtrl), 
              
              const SizedBox(height: 25),
              // 3. TOPTAN ARALIKLARI
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
              // 4. PERSONEL
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
}