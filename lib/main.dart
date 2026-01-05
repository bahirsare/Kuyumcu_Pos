import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          isDense: true,
        ),
      ),
      home: const PosScreen(),
    );
  }
}

class SatisSatiri {
  String id;
  String tur;
  String urunAdi;
  double gram;
  double deger; // Milyem veya Alyans İşçiliği
  bool isManuel;

  SatisSatiri({
    required this.id,
    required this.tur,
    required this.urunAdi,
    this.gram = 0.0,
    this.deger = 0.0,
    this.isManuel = false,
  });
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Canlı Veriler
  double _canliHasAlis = 0;
  double _canliHasSatis = 0;
  
  // Kilitli Veriler (Ekranda sabit duracaklar)
  double _kilitliHasAlis = 0;
  
  bool _fiyatSabit = false; 
  bool _sunumModu = false;
  
  Map<String, dynamic> _ayarlar = {};
  List<SatisSatiri> _sepet = [];
  final TextEditingController _hasSatisManuelController = TextEditingController();

  final Map<String, String> _urunCesitleri = {
    "std": "Standart (14K)",
    "bracelet": "Bileklik (14K)",
    "earring": "Küpe (14K)",
    "ring": "Yüzük (14K)",
    "pendant": "Kolye Ucu (14K)",
    "chain": "Zincir (14K)",
    "cuff": "Kelepçe (14K)",
    "set": "Set / Mini Set",
    "wedding_plain": "Düz Alyans",
    "wedding_pattern": "Kalemli Alyans",
    "b22_ajda": "Ajda (22K)",
    "b22_sarnel": "Şarnel (22K)",
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _baslangicSatiriEkle();
    _firebaseDinle();
  }

  void _baslangicSatiriEkle() {
    _sepet.add(SatisSatiri(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tur: "std",
      urunAdi: "Standart (14K)",
    ));
    setState(() {});
  }

  void _firebaseDinle() {
    FirebaseFirestore.instance.collection('ayarlar').doc('genel').snapshots().listen((doc) {
      if (doc.exists) {
        setState(() {
          _ayarlar = doc.data()!;
          _otomatikDegerleriGuncelle();
        });
      }
    });

    FirebaseFirestore.instance.collection('piyasa').doc('canli').snapshots().listen((doc) {
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          _canliHasAlis = (data['alis'] as num).toDouble();
          _canliHasSatis = (data['satis'] as num).toDouble();

          // KİLİT KONTROLÜ
          if (!_fiyatSabit) {
             // Kilit yoksa canlı veriyi ekrana bas
             if (_hasSatisManuelController.text.isEmpty || !_hasSatisManuelController.text.contains('.')) { // Kullanıcı elle yazıyorsa bozma
                _hasSatisManuelController.text = _canliHasSatis.toString();
             }
             _kilitliHasAlis = _canliHasAlis;
          }
        });
      }
    });
  }

  void _otomatikDegerleriGuncelle() {
    for (var satir in _sepet) {
      if (!satir.isManuel) {
        satir.deger = _varsayilanDegerBul(satir.tur, satir.gram);
      }
    }
  }

  double _varsayilanDegerBul(String tur, double gram) {
    if (_ayarlar.isEmpty) return 0;
    
    // Alyans İşçilikleri (Has Gram Olarak Eklenir)
    if (tur == "wedding_plain") return (_ayarlar['wedding_plain_sale'] ?? 0.60).toDouble();
    if (tur == "wedding_pattern") return (_ayarlar['wedding_pattern_sale'] ?? 0.80).toDouble();
    
    // 22 Ayar Milyemleri
    if (tur == "b22_ajda") return (_ayarlar['b22_ajda_sale'] ?? 0.930).toDouble();
    if (tur == "b22_sarnel") return (_ayarlar['b22_sarnel_sale'] ?? 0.945).toDouble();
    
    // 14 Ayar Standart Milyemleri
    if (gram < 5) return (_ayarlar['factor_0_5'] ?? 0.90).toDouble();
    if (gram < 10) return (_ayarlar['factor_5_10'] ?? 0.85).toDouble();
    if (gram < 15) return (_ayarlar['factor_10_15'] ?? 0.82).toDouble();
    if (gram < 25) return (_ayarlar['factor_15_25'] ?? 0.77).toDouble();
    return (_ayarlar['factor_25_plus'] ?? 0.725).toDouble();
  }

  double _satirFiyatiHesapla(SatisSatiri satir, double hasFiyat) {
    if (satir.tur.startsWith("wedding")) {
      // Formül: Has * ( (Gram * 0.585) + İşçilik )
      double safGram = satir.gram * 0.585;
      double toplamHasKarsiligi = safGram + satir.deger; 
      return hasFiyat * toplamHasKarsiligi;
    } else {
      // Formül: Has * Gram * Milyem
      return hasFiyat * satir.gram * satir.deger;
    }
  }

  // --- "OLURU" HESAPLAMA (DİP FİYAT) ---
  // Mantık: Varsayılan satış milyeminden 20 puan (0.02) düşeriz.
  double _satirOluruHesapla(SatisSatiri satir, double hasFiyat) {
    // 1. Sistemdeki varsayılan değeri bul (Manuel oynanmış olsa bile orijinali baz al)
    double varsayilan = _varsayilanDegerBul(satir.tur, satir.gram);
    
    // 2. Oluru Milyemini/İşçiliğini Hesapla (20 Puan Altı)
    double oluruDegeri = varsayilan - 0.05;
    if (oluruDegeri < 0) oluruDegeri = 0; // Güvenlik

    // 3. Fiyatı Hesapla
    if (satir.tur.startsWith("wedding")) {
      // Alyans: Has * ( (Gram * 0.585) + (İşçilik - 0.05) )
      double safGram = satir.gram * 0.585;
      return hasFiyat * (safGram + oluruDegeri);
    } else {
      // Standart: Has * Gram * (Milyem - 0.02)
      return hasFiyat * satir.gram * oluruDegeri;
    }
  }

  double get _toplamNakit {
    double toplam = 0;
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    for (var s in _sepet) {
      toplam += _satirFiyatiHesapla(s, hasFiyat);
    }
    return toplam;
  }
  
  double get _toplamGram {
    return _sepet.fold(0, (sum, item) => sum + item.gram);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 0);
    
    // Fiyat Farkı Uyarısı
    double ekrandakiFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double fark = ekrandakiFiyat - _canliHasSatis;
    bool tehlikeliFark = _fiyatSabit && (fark.abs() > 10);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bigbos Eren Kuyumculuk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B2631),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_sunumModu ? Icons.visibility_off : Icons.visibility, color: _sunumModu ? Colors.orange : Colors.white),
            onPressed: () => setState(() => _sunumModu = !_sunumModu),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => _gecmisSatislariGoster(context, fmt),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.white70),
            onPressed: () {
               if (FirebaseAuth.instance.currentUser != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(text: "TAKI SATIŞ", icon: Icon(Icons.diamond_outlined)),
            Tab(text: "ZİYNET", icon: Icon(Icons.monetization_on_outlined)),
            Tab(text: "HURDA", icon: Icon(Icons.recycling)),
          ],
        ),
      ),
      body: Column(
        children: [
          // FİYAT BARI
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            color: const Color(0xFF212F3C),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ALIŞ (KİLİTLİ DEĞİŞKENİ KULLANIR)
                _fiyatKutusu("HAS ALIŞ", _kilitliHasAlis.toStringAsFixed(2), Colors.orangeAccent, readOnly: true),
                const SizedBox(width: 20),
                
                // SATIŞ + KİLİT
                Row(
                  children: [
                    _fiyatKutusu("HAS SATIŞ", "", const Color(0xFF2ECC71), controller: _hasSatisManuelController),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Transform.scale(
                          scale: 1.3,
                          child: Checkbox(
                            value: _fiyatSabit,
                            activeColor: Colors.red,
                            side: const BorderSide(color: Colors.white54, width: 2),
                            onChanged: (val) {
                              setState(() {
                                _fiyatSabit = val!;
                                if (!_fiyatSabit) {
                                  // Kilidi açınca hemen güncelleri çek
                                  _hasSatisManuelController.text = _canliHasSatis.toString();
                                  _kilitliHasAlis = _canliHasAlis;
                                }
                              });
                            },
                          ),
                        ),
                        const Text("SABİTLE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (tehlikeliFark)
            Container(
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    fark > 0 ? "PİYASA DÜŞTÜ! (${fark.toStringAsFixed(2)} TL)" : "PİYASA YÜKSELDİ! (${fark.abs().toStringAsFixed(2)} TL)",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    onPressed: () => setState(() {
                       _hasSatisManuelController.text = _canliHasSatis.toString();
                       _kilitliHasAlis = _canliHasAlis;
                    }),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, elevation: 0),
                    child: const Text("GÜNCELLE"),
                  )
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTakiSayfasi(fmt),
                const Center(child: Text("Ziynet Sayfası Hazırlanıyor...", style: TextStyle(color: Colors.grey))),
                const Center(child: Text("Hurda Sayfası Hazırlanıyor...", style: TextStyle(color: Colors.grey))),
              ],
            ),
          ),
          
          // ALT TOPLAM
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B2631),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TOPLAM ${_toplamGram.toStringAsFixed(2)} gr", style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    Text(fmt.format(_toplamNakit), style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _odemeYap(context, fmt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    elevation: 5,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 28),
                  label: const Text("SATIŞI ONAYLA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _fiyatKutusu(String label, String val, Color color, {TextEditingController? controller, bool readOnly = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 5),
        SizedBox(
          width: 120,
          child: controller != null 
            ? TextField(
                controller: controller,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
                textAlign: TextAlign.center,
                onChanged: (v) => setState(() {}),
                decoration: InputDecoration(
                  fillColor: const Color(0xFF2C3E50),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF2C3E50), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(4)),
                child: Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22), textAlign: TextAlign.center),
              ),
        )
      ],
    );
  }

  Widget _buildTakiSayfasi(NumberFormat fmt) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _sepet.length,
            itemBuilder: (context, index) {
              var satir = _sepet[index];
              double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
              
              double nakitTutar = _satirFiyatiHesapla(satir, hasFiyat);
              
              double tekCekimOrani = (_ayarlar['cc_single_rate'] ?? 7).toDouble();
              double taksitOrani = (_ayarlar['cc_install_rate'] ?? 12).toDouble();
              
              double tekCekimTutar = nakitTutar * (1 + tekCekimOrani / 100);
              double taksitliTutar = nakitTutar * (1 + taksitOrani / 100);

              double oluruFiyat = _satirOluruHesapla(satir, hasFiyat);

              bool isAlyans = satir.tur.startsWith("wedding");
              String labelText = isAlyans ? "İŞÇİLİK" : "MİLYEM";

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // --- 1. SATIR (GİRİŞLER) ---
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<String>(
                              value: _urunCesitleri.containsKey(satir.tur) ? satir.tur : "std",
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: "Ürün"),
                              style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold),
                              items: _urunCesitleri.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                setState(() {
                                  satir.tur = val!;
                                  satir.urunAdi = _urunCesitleri[val]!;
                                  satir.isManuel = false;
                                  satir.deger = _varsayilanDegerBul(satir.tur, satir.gram);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: satir.gram == 0 ? "" : satir.gram.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(labelText: "Gr"),
                              onChanged: (val) {
                                setState(() {
                                  satir.gram = double.tryParse(val) ?? 0;
                                  if (!satir.isManuel) satir.deger = _varsayilanDegerBul(satir.tur, satir.gram);
                                });
                              },
                            ),
                          ),
                          if (!_sunumModu) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                key: ValueKey(satir.deger), 
                                initialValue: satir.deger.toStringAsFixed(3),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                                decoration: InputDecoration(
                                  labelText: labelText,
                                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF27AE60))),
                                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF27AE60), width: 2)),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    satir.deger = double.tryParse(val) ?? 0;
                                    satir.isManuel = true;
                                  });
                                },
                              ),
                            ),
                          ]
                        ],
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(thickness: 1, color: Colors.black12),
                      ),

                      // --- 2. SATIR (SONUÇLAR) ---
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("NAKİT", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(fmt.format(nakitTutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1B2631))),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("TEK ÇEKİM", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                Text(fmt.format(tekCekimTutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("3 TAKSİT", style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                                Text(fmt.format(taksitliTutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple)),
                              ],
                            ),
                          ),
                          if (!_sunumModu)
                           Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("OLURU", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                  Text(fmt.format(oluruFiyat), style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                            onPressed: () => setState(() => _sepet.removeAt(index)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            onPressed: _baslangicSatiriEkle,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text("YENİ SATIR EKLE"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B2631),
              side: const BorderSide(color: Color(0xFF1B2631)),
              minimumSize: const Size(double.infinity, 50),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  void _odemeYap(BuildContext context, NumberFormat fmt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ödeme Onayı", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B2631))),
              const Divider(),
              const SizedBox(height: 10),
              Text(fmt.format(_toplamNakit), style: const TextStyle(fontSize: 40, color: Color(0xFF27AE60), fontWeight: FontWeight.bold)),
              const Text("Nakit Bazlı Hesaplanan Tutar", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (){ Navigator.pop(ctx); _satisiVeritabaninaYaz("Nakit", _toplamNakit); }, 
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), 
                      child: const Text("NAKİT")
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (){ 
                         double tekCekimOrani = (_ayarlar['cc_single_rate'] ?? 7).toDouble();
                         double tutar = _toplamNakit * (1 + tekCekimOrani/100);
                         Navigator.pop(ctx); 
                         _satisiVeritabaninaYaz("Tek Çekim", tutar); 
                      }, 
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2980B9), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), 
                      child: const Text("TEK ÇEKİM")
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (){ 
                         double taksitOrani = (_ayarlar['cc_install_rate'] ?? 12).toDouble();
                         double tutar = _toplamNakit * (1 + taksitOrani/100);
                         Navigator.pop(ctx); 
                         _satisiVeritabaninaYaz("3 TAKSİT", tutar); 
                      }, 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), 
                      child: const Text("3 TAKSİT")
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Future<void> _satisiVeritabaninaYaz(String odemeTipi, double tutar) async {
    try {
      await FirebaseFirestore.instance.collection('satis_gecmisi').add({
        'tarih': FieldValue.serverTimestamp(),
        'toplam_gram': _toplamGram,
        'tutar': tutar,
        'odeme_tipi': odemeTipi,
        'has_fiyat': double.tryParse(_hasSatisManuelController.text) ?? 0,
        'satir_sayisi': _sepet.length
      });
      setState(() { _sepet.clear(); _baslangicSatiriEkle(); });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Satış Kaydedildi: $odemeTipi - ${tutar.toStringAsFixed(0)} TL"), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  void _gecmisSatislariGoster(BuildContext context, NumberFormat fmt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 500,
          child: Column(
            children: [
              const Text("Son Satışlar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('satis_gecmisi').orderBy('tarih', descending: true).limit(20).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("Henüz satış yok."));
                    
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (c,i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        double tutar = (data['tutar'] ?? 0).toDouble();
                        String tip = data['odeme_tipi'] ?? "?";
                        Timestamp? ts = data['tarih'];
                        String zaman = ts != null ? DateFormat('dd/MM HH:mm').format(ts.toDate()) : "-";
                        
                        return ListTile(
                          leading: Icon(Icons.sell, color: tip == "Nakit" ? Colors.green : Colors.purple),
                          title: Text(fmt.format(tutar), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B2631))),
                          subtitle: Text("$zaman  •  $tip"),
                          trailing: Text("${(data['toplam_gram']??0).toStringAsFixed(2)} gr", style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      }
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Giriş")), body: const Center(child: Text("Login Sayfası...")));
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Admin Paneli")), body: const Center(child: Text("Admin Paneli...")));
  }
}