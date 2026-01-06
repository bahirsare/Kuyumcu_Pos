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
  bool isManuel; // Elle girildiyse true olur ve otomatik hesap bunu değiştirmez

  SatisSatiri({
    required this.id,
    required this.tur,
    required this.urunAdi,
    this.gram = 0.0,
    this.deger = 0.0,
    this.isManuel = false,
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
  
  // YENİ: Milyem kutusuna elle müdahale edildi mi?
  bool _milyemElleDegisti = false; 

  Map<String, dynamic> _ayarlar = {}; 
  List<dynamic> _toptanAraliklar = [];
  Map<String, dynamic> _piyasaVerileri = {}; 

  List<SatisSatiri> _sepet = [];
  final TextEditingController _hasSatisManuelController = TextEditingController();

  // SABİT LİSTELER (Kategori Ekleme Kaldırıldı, Personel Dinamik)
  List<String> _personelListesi = ["Mağaza"]; 
  
  // ÜRÜN ÇEŞİTLERİ (SADELEŞTİRİLMİŞ & 22 TAKI EKLENDİ)
  final Map<String, String> _urunCesitleri = {
    "std": "Standart (14K)",
    "b22_taki": "22 Ayar Takı", // YENİ EKLENDİ
    "wedding_plain": "Düz Alyans",
    "wedding_pattern": "Kalemli Alyans",
    "b22_bilezik": "22 Ayar Bilezik",
    "b22_ajda": "Ajda (22K)",
    "b22_sarnel": "Şarnel (22K)",
  }; 

  String? _secilenPersonel;

  // Takı Giriş Formu
  String _formSecilenTur = "std";
  final TextEditingController _formGramController = TextEditingController();
  final TextEditingController _formMilyemController = TextEditingController();

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
          if (fark.inSeconds < 60) veriTaze = true;
          else if (fark.inMinutes >= 3) guvenlikKilidi = true;
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
        if(s.tur == "std") toplamStdGram += s.gram;
      }
    }
    for (var satir in _sepet) {
      if (!satir.isManuel && !satir.tur.startsWith("ziynet")) {
        double refGram = (_toptanModu && satir.tur == "std") ? toplamStdGram : satir.gram;
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
    
    if (tur == "std") {
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
    if (satir.tur.startsWith("ziynet")) return satir.gram * satir.deger; 
    else if (satir.tur.startsWith("wedding")) return hasFiyat * (satir.gram * 0.585 + satir.deger);
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
        if(s.tur.startsWith("b22") || s.tur == "b22_taki") safOran = 0.916; 
        else if(s.tur.startsWith("wedding")) safOran = 0.585; 
        toplamMaliyet += (s.gram * safOran * hasFiyat);
      }
    }
    return toplamSatis - toplamMaliyet;
  }

  double get _toplamNakit {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double toplam = 0;
    for (var s in _sepet) toplam += _satirFiyatiHesapla(s, hasFiyat);
    return toplam;
  }

  // --- POPUPLAR ---
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

  // --- ARAYÜZ ---
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 0);
    double ekrandakiFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double fark = ekrandakiFiyat - _canliHasSatis;
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
      body: Stack(
        children: [
          Column(
            children: [
              // FİYAT BARI
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                color: const Color(0xFF212F3C),
                child: Column(
                  children: [
                    Row(
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
                    if(_tabController.index == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                              value: _toptanModu,
                              activeColor: const Color(0xFFD4AF37),
                              onChanged: (val) { setState(() { _toptanModu = val!; _otomatikDegerleriGuncelle(); }); },
                          ),
                          const Text("Toptan Hesap (Standart Ürünleri Birleştir)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              if (_fiyatSabit && fark.abs() > 10)
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
                    _buildTakiFormu(),
                    _buildZiynetGrid(fmt), 
                    const Center(child: Text("Hurda Sayfası Yakında...")),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.shopping_basket, color: Colors.white),
                            const SizedBox(width: 10),
                            Text("SEPET (${_sepet.length} Ürün)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ]),
                          Row(children: [
                            Text(fmt.format(_toplamNakit), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                            Icon(_sepetAcik ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white, size: 30),
                          ]),
                        ],
                      ),
                    ),
                  ),

                  if (_sepetAcik)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _sepet.isEmpty 
                            ? const Center(child: Text("Sepet Boş", style: TextStyle(fontSize: 18, color: Colors.grey)))
                            : ListView.separated(
                                padding: const EdgeInsets.all(10),
                                itemCount: _sepet.length,
                                separatorBuilder: (c,i) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  var s = _sepet[index];
                                  bool ziynetMi = s.tur.startsWith("ziynet");
                                  double tutar = ziynetMi ? (s.deger * s.gram) : _satirFiyatiHesapla(s, double.tryParse(_hasSatisManuelController.text)??0);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                    child: Row(
                                      children: [
                                        ziynetMi 
                                          ? const Icon(Icons.monetization_on, color: Colors.orange, size: 24)
                                          : const Icon(Icons.diamond, color: Colors.blue, size: 24),
                                        const SizedBox(width: 10),
                                        
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(s.urunAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              Text(fmt.format(s.deger * (ziynetMi ? 1 : 1)), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ),

                                        InkWell(
                                          onTap: () => _miktarDuzenle(s), 
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                            child: Text(
                                              ziynetMi ? "${s.gram.toInt()} Ad" : "${s.gram} Gr",
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 15),

                                        Text(fmt.format(tutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(width: 5),

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
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: Colors.grey.shade100, border: const Border(top: BorderSide(color: Colors.black12))),
                            child: ElevatedButton.icon(
                              onPressed: () => _odemeYap(context, fmt),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B2631), foregroundColor: Colors.white, padding: const EdgeInsets.all(15), minimumSize: const Size(double.infinity, 50)),
                              icon: const Icon(Icons.check_circle),
                              label: const Text("SATIŞI TAMAMLA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _fiyatKutusu(String label, String val, Color color, {TextEditingController? controller, bool readOnly = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        SizedBox(width: 120, child: controller != null 
          ? TextField(
              controller: controller, readOnly: readOnly, keyboardType: TextInputType.number, textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
              onChanged: (v) { setState(() { _otomatikDegerleriGuncelle(); }); },
              decoration: InputDecoration(fillColor: const Color(0xFF2C3E50), contentPadding: const EdgeInsets.symmetric(vertical: 8)),
            )
          : Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF2C3E50), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(4)),
              child: Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22), textAlign: TextAlign.center),
            )
        )
      ],
    );
  }

  Widget _buildTakiFormu() {
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
                _milyemElleDegisti = false; // Ürün değişince otomatik hesaplamaya dön
                // Milyem kutusunu temizle veya yeni türe göre güncelle
                if(_formGramController.text.isNotEmpty) {
                   double gr = double.tryParse(_formGramController.text.replaceAll(',', '.')) ?? 0;
                   if (gr > 0) {
                     _formMilyemController.text = _dinamikMilyemBul(_formSecilenTur, gr).toString();
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
                  // DÜZELTME: Sadece kullanıcı Milyem kutusuna elle müdahale etmediyse otomatik doldur
                  if (gr > 0 && !_milyemElleDegisti) {
                     double otoMilyem = _dinamikMilyemBul(_formSecilenTur, gr);
                     _formMilyemController.text = otoMilyem.toString();
                  }
                },
              )),
              const SizedBox(width: 15),
              Expanded(child: TextField(
                controller: _formMilyemController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "İşçilik / Milyem", prefixIcon: Icon(Icons.attach_money)),
                // Eğer kullanıcı buraya bir şey yazarsa, otomatik hesaplamayı durdur.
                onChanged: (val) {
                  setState(() => _milyemElleDegisti = true);
                },
              )),
            ],
          ),
          const SizedBox(height: 20),
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
                      // Kullanıcı elle yazdıysa (milyemElleDegisti=true) veya değer 0'dan büyükse MANUEL kabul et.
                      isManuel: _milyemElleDegisti || (val > 0), 
                    ));
                    _otomatikDegerleriGuncelle();
                    _sepetAcik = true; 
                    _formGramController.clear();
                    _formMilyemController.clear();
                    _milyemElleDegisti = false; // Sıfırla
                  });
                }
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text("SEPETE EKLE"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B2631), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
            ),
          )
        ],
      ),
    );
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

  void _odemeYap(BuildContext context, NumberFormat fmt) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("Ödeme & Personel", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Satışı Yapan Personel"),
                items: _personelListesi.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) { setModalState(() => _secilenPersonel = val); },
              ),
              const SizedBox(height: 20),
              Text(fmt.format(_toplamNakit), style: const TextStyle(fontSize: 40, color: Color(0xFF27AE60), fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(children: [Expanded(child: ElevatedButton(onPressed: () => _satisiTamamla("Nakit"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("NAKİT")))]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () => _satisiTamamla("Tek Çekim"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2980B9), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("TEK ÇEKİM"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => _satisiTamamla("3 Taksit"), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("3 TAKSİT"))),
              ]),
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
    
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double kar = _toplamKarHesapla(hasFiyat);
    double tutar = _toplamNakit;
    if(odemeTipi == "Tek Çekim") tutar *= (1 + ((_ayarlar['cc_single_rate']??7)/100));
    if(odemeTipi == "3 Taksit") tutar *= (1 + ((_ayarlar['cc_install_rate']??12)/100));

    try {
      await FirebaseFirestore.instance.collection('satis_gecmisi').add({
        'tarih': FieldValue.serverTimestamp(), 'personel': _secilenPersonel, 
        'tutar': tutar, 'kar': kar, 'odeme_tipi': odemeTipi, 'has_fiyat': hasFiyat,
        'urunler': _sepet.map((s) => s.tur.startsWith("ziynet") ? "${s.urunAdi} (${s.gram.toInt()} adet)" : "${s.urunAdi} (${s.gram}gr)").toList(),
      });
      setState(() { _sepet.clear(); _secilenPersonel = null; _sepetAcik = false; });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Satış Kaydedildi! Kar: ${kar.toStringAsFixed(0)} TL"), backgroundColor: Colors.green));
    } catch(e) { }
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
                            return ListTile(dense: true, leading: Text(zaman, style: const TextStyle(color: Colors.grey)), title: Text(fmt.format(tutar), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Kar: ${kar.toStringAsFixed(0)} ₺"), trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey));
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

// --- ADMIN PANEL (V10 - GÜNCEL) ---
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
  
  final TextEditingController _weddingPlainCtrl = TextEditingController();
  final TextEditingController _weddingPatternCtrl = TextEditingController();
  final TextEditingController _b22BilezikCtrl = TextEditingController();
  final TextEditingController _b22AjdaCtrl = TextEditingController();
  final TextEditingController _b22TakiCtrl = TextEditingController(); // YENİ
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
          
          _weddingPlainCtrl.text = (data['factor_wedding_plain'] ?? 0.60).toString();
          _weddingPatternCtrl.text = (data['factor_wedding_pattern'] ?? 0.80).toString();
          _b22BilezikCtrl.text = (data['factor_b22_bilezik'] ?? 0.930).toString();
          _b22AjdaCtrl.text = (data['factor_b22_ajda'] ?? 0.930).toString();
          _b22TakiCtrl.text = (data['factor_b22_taki'] ?? 0.960).toString(); // YENİ
          _maxFactorCtrl.text = (data['factor_max'] ?? 0.725).toString();

          if(data.containsKey('toptan_araliklar')) _toptanListesi = List<Map<String, dynamic>>.from(data['toptan_araliklar']);
          else _toptanListesi = [{'limit': 5, 'carpan': 0.90}, {'limit': 10, 'carpan': 0.85}, {'limit': 15, 'carpan': 0.82}, {'limit': 25, 'carpan': 0.77}];

          if(data.containsKey('personel_listesi')) _personelListesi = List<String>.from(data['personel_listesi']);
          else _personelListesi = ["Mağaza", "Ahmet"];
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
        
        'factor_wedding_plain': double.parse(_weddingPlainCtrl.text.replaceAll(',', '.')),
        'factor_wedding_pattern': double.parse(_weddingPatternCtrl.text.replaceAll(',', '.')),
        'factor_b22_bilezik': double.parse(_b22BilezikCtrl.text.replaceAll(',', '.')),
        'factor_b22_ajda': double.parse(_b22AjdaCtrl.text.replaceAll(',', '.')),
        'factor_b22_taki': double.parse(_b22TakiCtrl.text.replaceAll(',', '.')), // YENİ
        'factor_max': double.parse(_maxFactorCtrl.text.replaceAll(',', '.')),
        
        'toptan_araliklar': _toptanListesi,
        'personel_listesi': _personelListesi,
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tüm Ayarlar Kaydedildi!")));
    }
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
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Gram Limiti")),
        TextField(controller: carpanCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Çarpan")),
      ]),
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
    return Scaffold(
      appBar: AppBar(title: const Text("Yönetici Paneli"), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. GENEL
              const Text("GENEL & KOMİSYON", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              _buildInput("Sarrafiye Makas (Gr)", _sarrafiyeMakasController),
              Row(children: [
                Expanded(child: _buildInput("Tek Çekim (%)", _ccSingleController)),
                const SizedBox(width: 10),
                Expanded(child: _buildInput("Taksitli (%)", _ccInstallController)),
              ]),

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
              _buildInput("22 Ayar Takı (İşçilikli)", _b22TakiCtrl), // YENİ
              
              const SizedBox(height: 25),
              // 3. TOPTAN ARALIKLARI
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("TOPTAN ARALIKLARI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _buildInput(String lbl, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(controller: ctrl, decoration: InputDecoration(labelText: lbl), keyboardType: TextInputType.number),
    );
  }
}