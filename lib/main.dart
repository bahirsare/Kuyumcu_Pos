import 'dart:async';
import 'dart:math'; // Max/Min hesabı için
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  double deger; // Milyem veya İşçilik
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
  
  // Veriler
  double _canliHasAlis = 0;
  double _canliHasSatis = 0;
  double _kilitliHasAlis = 0;
  bool _fiyatSabit = false; 
  bool _sunumModu = false;
  
  Map<String, dynamic> _ayarlar = {};
  List<SatisSatiri> _sepet = [];
  final TextEditingController _hasSatisManuelController = TextEditingController();

  // Personel Listesi (Normalde DB'den gelir, şimdilik manuel)
  final List<String> _personelListesi = ["Ahmet", "Mehmet", "Ayşe", "Fatma"];
  String? _secilenPersonel;

  final Map<String, String> _urunCesitleri = {
    "std": "Standart (14K)",
    "bracelet": "Bileklik (14K)",
    "earring": "Küpe (14K)",
    "ring": "Yüzük (14K)",
    "set": "Set / Mini Set",
    "wedding_plain": "Düz Alyans",
    "wedding_pattern": "Kalemli Alyans",
    "b22_ajda": "Ajda (22K)",
    "b22_sarnel": "Şarnel (22K)",
    "b22_bilezik": "22 Ayar Bilezik", // Yeni eklendi
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

          if (!_fiyatSabit) {
             if (_hasSatisManuelController.text.isEmpty || !_hasSatisManuelController.text.contains('.')) {
                _hasSatisManuelController.text = _canliHasSatis.toString();
             }
             _kilitliHasAlis = _canliHasAlis;
          }
        });
      }
    });
  }

  // --- KRİTİK: TOPLAM GRAMA GÖRE OTOMATİK MİLYEM GÜNCELLEME ---
  void _otomatikDegerleriGuncelle() {
    // Sepetteki tüm STANDART (14K) ürünlerin toplam gramajını bul
    double toplamStdGram = 0;
    for(var s in _sepet) {
      if(s.tur == 'std' || s.tur == 'bracelet' || s.tur == 'earring' || s.tur == 'ring' || s.tur == 'set') {
        toplamStdGram += s.gram;
      }
    }

    for (var satir in _sepet) {
      if (!satir.isManuel) {
        // Her satır için, o anki toplam gramaja göre milyem çekiyoruz
        satir.deger = _varsayilanDegerBul(satir.tur, satir.gram, toplamStdGram);
      }
    }
  }

  double _varsayilanDegerBul(String tur, double urunGram, double toplamSepetGram) {
    if (_ayarlar.isEmpty) return 0;
    
    // Alyanslar
    if (tur == "wedding_plain") return (_ayarlar['wedding_plain_sale'] ?? 0.60).toDouble();
    if (tur == "wedding_pattern") return (_ayarlar['wedding_pattern_sale'] ?? 0.80).toDouble();
    
    // 22 Ayarlar
    if (tur == "b22_ajda") return (_ayarlar['b22_ajda_sale'] ?? 0.930).toDouble();
    if (tur == "b22_sarnel") return (_ayarlar['b22_sarnel_sale'] ?? 0.945).toDouble();
    if (tur == "b22_bilezik") return 0.930; // Varsayılan satış
    
    // 14 Ayar Standart (TOPLAM GRAMA GÖRE HESAPLANIR)
    // Eğer sepet toplamı yüksekse, tekil ürün gramına bakmaksızın düşük milyem verilir.
    // HTML'deki "Toplam Gram" mantığı burasıdır.
    double referansGram = toplamSepetGram > 0 ? toplamSepetGram : urunGram;

    if (referansGram < 5) return (_ayarlar['factor_0_5'] ?? 0.90).toDouble();
    if (referansGram < 10) return (_ayarlar['factor_5_10'] ?? 0.85).toDouble();
    if (referansGram < 15) return (_ayarlar['factor_10_15'] ?? 0.82).toDouble();
    if (referansGram < 25) return (_ayarlar['factor_15_25'] ?? 0.77).toDouble();
    return (_ayarlar['factor_25_plus'] ?? 0.725).toDouble();
  }

  double _satirFiyatiHesapla(SatisSatiri satir, double hasFiyat) {
    if (satir.tur.startsWith("wedding")) {
      double safGram = satir.gram * 0.585;
      double toplamHasKarsiligi = safGram + satir.deger; 
      return hasFiyat * toplamHasKarsiligi;
    } else {
      return hasFiyat * satir.gram * satir.deger;
    }
  }

  // --- "OLURU" HESAPLAMA (GÜNCELLENDİ: 710 Limiti ve Özel Kurallar) ---
  double _satirOluruHesapla(SatisSatiri satir, double hasFiyat) {
    double oluruDegeri = 0;
    double varsayilan = _varsayilanDegerBul(satir.tur, satir.gram, _toplamStdGramSepet());

    if (satir.tur == "b22_bilezik") {
      // KURAL: 22 Ayar Bilezik Oluru SABİT 0.926
      oluruDegeri = 0.926;
    } 
    else if (satir.tur.startsWith("wedding")) {
      // KURAL: Alyans 0.05 puan altı
      oluruDegeri = varsayilan - 0.05;
      if(oluruDegeri < 0) oluruDegeri = 0;
    }
    else if (satir.tur.startsWith("b22")) {
      // Diğer 22'likler (Ajda vs) - 0.01 diyelim (Varsayılan)
      oluruDegeri = varsayilan - 0.01;
    } 
    else {
      // KURAL: Standart 14K -> 0.025 Puan Altı AMA En az 0.710
      oluruDegeri = varsayilan - 0.025;
      if (oluruDegeri < 0.710) oluruDegeri = 0.710; // Taban Limit
    }

    // Fiyat Hesabı
    if (satir.tur.startsWith("wedding")) {
      double safGram = satir.gram * 0.585;
      return hasFiyat * (safGram + oluruDegeri);
    } else {
      return hasFiyat * satir.gram * oluruDegeri;
    }
  }

  // Yardımcı: Sadece 14K ürünlerin toplam gramı
  double _toplamStdGramSepet() {
    double t = 0;
    for(var s in _sepet) {
      if(!s.tur.startsWith("wedding") && !s.tur.startsWith("b22")) t += s.gram;
    }
    return t;
  }

  // --- KAR HESAPLAMA (Maliyet Çıkarma) ---
  double _toplamKarHesapla(double hasFiyat) {
    double toplamSatis = _toplamNakit;
    double toplamMaliyet = 0;

    for(var s in _sepet) {
      double safOran = 0.585;
      if(s.tur.startsWith("b22")) safOran = 0.916;
      else if(s.tur.startsWith("wedding")) safOran = 0.585;
      
      // Ham Altın Maliyeti
      double hamMaliyet = s.gram * hasFiyat * safOran;
      
      // İşçilik/Ek Maliyet (Ayarlardan veya Sabit 10 TL/gr diyelim)
      // Normalde bu da DB'den gelir
      double ekMaliyet = s.gram * 10; 
      
      toplamMaliyet += (hamMaliyet + ekMaliyet);
    }
    
    return toplamSatis - toplamMaliyet;
  }

  double get _toplamNakit {
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double toplam = 0;
    for (var s in _sepet) toplam += _satirFiyatiHesapla(s, hasFiyat);
    return toplam;
  }
  
  double get _toplamGram {
    return _sepet.fold(0, (sum, item) => sum + item.gram);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: "tr_TR", symbol: "₺", decimalDigits: 0);
    double ekrandakiFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double fark = ekrandakiFiyat - _canliHasSatis;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bigbos Eren Kuyumculuk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B2631),
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
               // Admin kontrolü...
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
                _fiyatKutusu("HAS ALIŞ", _kilitliHasAlis.toStringAsFixed(2), Colors.orangeAccent, readOnly: true),
                const SizedBox(width: 20),
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
                                  _hasSatisManuelController.text = _canliHasSatis.toString();
                                  _kilitliHasAlis = _canliHasAlis;
                                }
                              });
                            },
                          ),
                        ),
                        const Text("SABİTLE", style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (_fiyatSabit && fark.abs() > 10)
            Container(
              width: double.infinity, color: Colors.redAccent, padding: const EdgeInsets.all(8),
              child: Center(child: Text("DİKKAT! PİYASA FARKLI (${fark.toStringAsFixed(2)})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTakiSayfasi(fmt),
                const Center(child: Text("Ziynet...")),
                const Center(child: Text("Hurda...")),
              ],
            ),
          ),
          
          // ALT TOPLAM
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B2631),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TOPLAM ${_toplamGram.toStringAsFixed(2)} gr", style: const TextStyle(color: Colors.white54)),
                    Text(fmt.format(_toplamNakit), style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _odemeYap(context, fmt),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)),
                  icon: const Icon(Icons.check_circle_outline, size: 28),
                  label: const Text("TAMAMLA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        SizedBox(width: 120, child: controller != null 
          ? TextField(
              controller: controller, readOnly: readOnly,
              keyboardType: TextInputType.number, textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
              onChanged: (v) { setState(() { _otomatikDegerleriGuncelle(); }); }, // Elle değişimde de güncelle
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

  Widget _buildTakiSayfasi(NumberFormat fmt) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _sepet.length,
      itemBuilder: (context, index) {
        var satir = _sepet[index];
        double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
        
        double nakitTutar = _satirFiyatiHesapla(satir, hasFiyat);
        double tekCekimTutar = nakitTutar * (1 + ((_ayarlar['cc_single_rate']??7)/100));
        double taksitliTutar = nakitTutar * (1 + ((_ayarlar['cc_install_rate']??12)/100));
        double oluruFiyat = _satirOluruHesapla(satir, hasFiyat);

        bool isAlyans = satir.tur.startsWith("wedding");
        String labelText = isAlyans ? "İŞÇİLİK" : "MİLYEM";

        return Card(
          elevation: 4, margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(children: [
                  Expanded(flex: 4, child: DropdownButtonFormField<String>(
                    value: _urunCesitleri.containsKey(satir.tur) ? satir.tur : "std",
                    isExpanded: true,
                    items: _urunCesitleri.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      setState(() {
                        satir.tur = val!;
                        satir.urunAdi = _urunCesitleri[val]!;
                        satir.isManuel = false;
                        _otomatikDegerleriGuncelle();
                      });
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: TextFormField(
                    initialValue: satir.gram == 0 ? "" : satir.gram.toString(),
                    keyboardType: TextInputType.number, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(labelText: "Gr"),
                    onChanged: (val) {
                      setState(() {
                        satir.gram = double.tryParse(val) ?? 0;
                        _otomatikDegerleriGuncelle();
                      });
                    },
                  )),
                  if (!_sunumModu) ...[
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: TextFormField(
                      key: ValueKey(satir.deger), 
                      initialValue: satir.deger.toStringAsFixed(3),
                      keyboardType: TextInputType.number, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                      decoration: InputDecoration(labelText: labelText),
                      onChanged: (val) {
                        setState(() {
                          satir.deger = double.tryParse(val) ?? 0;
                          satir.isManuel = true;
                        });
                      },
                    )),
                  ]
                ]),
                const Divider(),
                Row(children: [
                  Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("NAKİT", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(fmt.format(nakitTutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1B2631))),
                  ])),
                  Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("TEK ÇEKİM", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                    Text(fmt.format(tekCekimTutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                  ])),
                  Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("3 TAKSİT", style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                    Text(fmt.format(taksitliTutar), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple)),
                  ])),
                  if (!_sunumModu)
                   Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text("OLURU", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                      Text(fmt.format(oluruFiyat), style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                   ])),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => _sepet.removeAt(index)))
                ])
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ÖDEME VE FİŞ EKRANI ---
  void _odemeYap(BuildContext context, NumberFormat fmt) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Ödeme & Personel", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B2631))),
                  const Divider(),
                  
                  // PERSONEL SEÇİMİ
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Satışı Yapan Personel"),
                    items: _personelListesi.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      setModalState(() => _secilenPersonel = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  Text(fmt.format(_toplamNakit), style: const TextStyle(fontSize: 40, color: Color(0xFF27AE60), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  Row(children: [
                    Expanded(child: ElevatedButton(onPressed: () => _satisiTamamla("Nakit"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("NAKİT"))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ElevatedButton(onPressed: () => _satisiTamamla("Tek Çekim"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2980B9), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("TEK ÇEKİM"))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: () => _satisiTamamla("3 Taksit"), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), child: const Text("3 TAKSİT"))),
                  ]),
                  const SizedBox(height: 10),
                  // FİŞ YAZDIR BUTONU (Örnek)
                  TextButton.icon(
                    onPressed: () => _fisYazdir(fmt),
                    icon: const Icon(Icons.print),
                    label: const Text("FİŞ ÖNİZLEME (PDF)"),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _satisiTamamla(String odemeTipi) async {
    if (_secilenPersonel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen Personel Seçin!"), backgroundColor: Colors.red));
      return;
    }
    Navigator.pop(context);
    
    double hasFiyat = double.tryParse(_hasSatisManuelController.text) ?? 0;
    double kar = _toplamKarHesapla(hasFiyat);
    double tutar = _toplamNakit; // Ödeme tipine göre değişebilir ama temel tutar bu
    if(odemeTipi == "Tek Çekim") tutar *= (1 + ((_ayarlar['cc_single_rate']??7)/100));
    if(odemeTipi == "3 Taksit") tutar *= (1 + ((_ayarlar['cc_install_rate']??12)/100));

    try {
      await FirebaseFirestore.instance.collection('satis_gecmisi').add({
        'tarih': FieldValue.serverTimestamp(),
        'personel': _secilenPersonel,
        'toplam_gram': _toplamGram,
        'tutar': tutar,
        'kar': kar,
        'odeme_tipi': odemeTipi,
        'has_fiyat': hasFiyat,
        'urunler': _sepet.map((s) => "${s.urunAdi} (${s.gram}gr)").toList(),
      });

      setState(() { _sepet.clear(); _baslangicSatiriEkle(); _secilenPersonel = null; });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Satış ve Kar Kaydedildi!"), backgroundColor: Colors.green));
    } catch(e) {
      // Hata
    }
  }
  
  // --- PDF FİŞ OLUŞTURMA ---
  Future<void> _fisYazdir(NumberFormat fmt) async {
    final doc = pw.Document();
    
    // Font yükleme vs gerekebilir, basit standart fontla:
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Text("BIGBOS EREN KUYUMCULUK", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))),
            pw.Divider(),
            pw.Text("Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}"),
            pw.Text("Personel: ${_secilenPersonel ?? '-'}"),
            pw.Divider(),
            ..._sepet.map((s) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("${s.urunAdi} (${s.gram} gr)"),
                pw.Text(fmt.format(s.gram * (double.tryParse(_hasSatisManuelController.text)??0) * s.deger)),
              ]
            )),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("TOPLAM:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(fmt.format(_toplamNakit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ]
            ),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Text("Tesekkur Ederiz"))
          ]
        );
      }
    ));

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
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