import 'additive_db.dart';

/// Łacińska nazwa gatunkowa składnika spożywczego i jej polski odpowiednik.
class _Latin {
  const _Latin(this.latin, this.nom, this.gen);
  final String latin;
  final String nom; // mianownik: "spirulina"
  final String gen; // dopełniacz: "spiruliny" (po "z", "ze", "od", "bez")
}

const _names = <_Latin>[
  _Latin('Spirulina platensis', 'spirulina', 'spiruliny'),
  _Latin('Arthrospira platensis', 'spirulina', 'spiruliny'),
  _Latin('Chlorella vulgaris', 'chlorella', 'chlorelli'),
  _Latin('Camellia sinensis', 'herbata', 'herbaty'),
  _Latin('Coffea arabica', 'kawa arabica', 'kawy arabiki'),
  _Latin('Coffea canephora', 'kawa robusta', 'kawy robusty'),
  _Latin('Theobroma cacao', 'kakaowiec', 'kakaowca'),
  _Latin('Zingiber officinale', 'imbir', 'imbiru'),
  _Latin('Curcuma longa', 'kurkuma', 'kurkumy'),
  _Latin('Capsicum annuum', 'papryka', 'papryki'),
  _Latin('Piper nigrum', 'pieprz czarny', 'pieprzu czarnego'),
  _Latin('Cinnamomum verum', 'cynamon cejloński', 'cynamonu cejlońskiego'),
  _Latin('Cinnamomum cassia', 'cynamon cassia', 'cynamonu cassia'),
  _Latin('Vanilla planifolia', 'wanilia', 'wanilii'),
  _Latin('Allium sativum', 'czosnek', 'czosnku'),
  _Latin('Allium cepa', 'cebula', 'cebuli'),
  _Latin('Triticum aestivum', 'pszenica', 'pszenicy'),
  _Latin('Triticum durum', 'pszenica durum', 'pszenicy durum'),
  _Latin('Triticum spelta', 'orkisz', 'orkiszu'),
  _Latin('Hordeum vulgare', 'jęczmień', 'jęczmienia'),
  _Latin('Avena sativa', 'owies', 'owsa'),
  _Latin('Secale cereale', 'żyto', 'żyta'),
  _Latin('Zea mays', 'kukurydza', 'kukurydzy'),
  _Latin('Oryza sativa', 'ryż', 'ryżu'),
  _Latin('Glycine max', 'soja', 'soi'),
  _Latin('Helianthus annuus', 'słonecznik', 'słonecznika'),
  _Latin('Brassica napus', 'rzepak', 'rzepaku'),
  _Latin('Olea europaea', 'oliwka', 'oliwki'),
  _Latin('Elaeis guineensis', 'palma olejowa', 'palmy olejowej'),
  _Latin('Cocos nucifera', 'kokos', 'kokosa'),
  _Latin('Prunus dulcis', 'migdał', 'migdałów'),
  _Latin('Corylus avellana', 'orzech laskowy', 'orzechów laskowych'),
  _Latin('Juglans regia', 'orzech włoski', 'orzechów włoskich'),
  _Latin('Arachis hypogaea', 'orzeszki ziemne', 'orzeszków ziemnych'),
  _Latin('Vitis vinifera', 'winogrona', 'winogron'),
  _Latin('Malus domestica', 'jabłko', 'jabłek'),
  _Latin('Citrus limon', 'cytryna', 'cytryny'),
  _Latin('Citrus sinensis', 'pomarańcza', 'pomarańczy'),
  _Latin('Aloe vera', 'aloes', 'aloesu'),
  _Latin('Stevia rebaudiana', 'stewia', 'stewii'),
  _Latin('Saccharomyces cerevisiae', 'drożdże piwne', 'drożdży piwnych'),
  _Latin('Lactobacillus bulgaricus', 'pałeczka bułgarska', 'pałeczki bułgarskiej'),
  _Latin('Streptococcus thermophilus', 'paciorkowiec termofilny', 'paciorkowca termofilnego'),
  _Latin('Lactobacillus acidophilus', 'acidophilus', 'acidophilus'),
  _Latin('Euphausia superba', 'kryl antarktyczny', 'kryla antarktycznego'),
  _Latin('Gadus morhua', 'dorsz', 'dorsza'),
  _Latin('Salmo salar', 'łosoś atlantycki', 'łososia atlantyckiego'),
  _Latin('Clupea harengus', 'śledź', 'śledzia'),
  _Latin('Thunnus albacares', 'tuńczyk żółtopłetwy', 'tuńczyka żółtopłetwego'),
  _Latin('Ilex paraguariensis', 'ostrokrzew paragwajski (yerba mate)', 'ostrokrzewu paragwajskiego (yerba mate)'),
  _Latin('Paullinia cupana', 'guarana', 'guarany'),
  _Latin('Panax ginseng', 'żeń-szeń', 'żeń-szenia'),
  _Latin('Moringa oleifera', 'moringa', 'moringi'),
  _Latin('Cannabis sativa', 'konopie siewne', 'konopi siewnych'),
  _Latin('Linum usitatissimum', 'len zwyczajny', 'lnu zwyczajnego'),
  _Latin('Salvia hispanica', 'szałwia hiszpańska (chia)', 'szałwii hiszpańskiej (chia)'),
  _Latin('Chenopodium quinoa', 'komosa ryżowa (quinoa)', 'komosy ryżowej (quinoa)'),
  _Latin('Fagopyrum esculentum', 'gryka', 'gryki'),
  _Latin('Sesamum indicum', 'sezam', 'sezamu'),
  _Latin('Beta vulgaris', 'burak', 'buraka'),
  _Latin('Daucus carota', 'marchew', 'marchwi'),
  _Latin('Solanum lycopersicum', 'pomidor', 'pomidora'),
  _Latin('Solanum tuberosum', 'ziemniak', 'ziemniaka'),
  _Latin('Mentha piperita', 'mięta pieprzowa', 'mięty pieprzowej'),
  _Latin('Origanum vulgare', 'oregano', 'oregano'),
  _Latin('Thymus vulgaris', 'tymianek', 'tymianku'),
  _Latin('Rosmarinus officinalis', 'rozmaryn', 'rozmarynu'),
  _Latin('Ocimum basilicum', 'bazylia', 'bazylii'),
  _Latin('Petroselinum crispum', 'pietruszka', 'pietruszki'),
  _Latin('Trigonella foenum-graecum', 'kozieradka', 'kozieradki'),
  _Latin('Cuminum cyminum', 'kmin rzymski', 'kminu rzymskiego'),
  _Latin('Foeniculum vulgare', 'koper włoski', 'kopru włoskiego'),
  _Latin('Pimpinella anisum', 'anyż', 'anyżu'),
  _Latin('Coriandrum sativum', 'kolendra', 'kolendry'),
  _Latin('Elettaria cardamomum', 'kardamon', 'kardamonu'),
  _Latin('Syzygium aromaticum', 'goździk', 'goździków'),
  _Latin('Myristica fragrans', 'gałka muszkatołowa', 'gałki muszkatołowej'),
  _Latin('Hibiscus sabdariffa', 'hibiskus', 'hibiskusa'),
  _Latin('Rosa canina', 'dzika róża', 'dzikiej róży'),
  _Latin('Sambucus nigra', 'bez czarny', 'bzu czarnego'),
  _Latin('Aronia melanocarpa', 'aronia', 'aronii'),
  _Latin('Vaccinium myrtillus', 'borówka czarna', 'borówki czarnej'),
  _Latin('Vaccinium macrocarpon', 'żurawina', 'żurawiny'),
  _Latin('Rubus idaeus', 'malina', 'maliny'),
  _Latin('Ribes nigrum', 'czarna porzeczka', 'czarnej porzeczki'),
  _Latin('Mangifera indica', 'mango', 'mango'),
  _Latin('Ananas comosus', 'ananas', 'ananasa'),
  _Latin('Phoenix dactylifera', 'daktyl', 'daktyli'),
  _Latin('Ficus carica', 'figa', 'figi'),
  _Latin('Punica granatum', 'granat', 'granatu'),
  _Latin('Carica papaya', 'papaja', 'papai'),
  _Latin('Passiflora edulis', 'marakuja', 'marakui'),
  _Latin('Actinidia deliciosa', 'kiwi', 'kiwi'),
  _Latin('Spinacia oleracea', 'szpinak', 'szpinaku'),
  _Latin('Cichorium intybus', 'cykoria', 'cykorii'),
];

const _genitiveAfter = {'z', 'ze', 'od', 'bez', 'do', 'dla', 'na'};

/// Zamienia łacińskie nazwy gatunkowe w tekście na polskie
/// ("proszek ze Spirulina platensis" -> "proszek ze spiruliny").
/// Zwraca null, jeśli nie znaleziono łacińskiej nazwy.
({String name, String latin})? latinize(String text) {
  final folded = AdditiveDatabase.fold(text);
  for (final l in _names) {
    final key = AdditiveDatabase.fold(l.latin);
    final at = folded.indexOf(key);
    if (at < 0) continue;
    // Poprzednie słowo decyduje o przypadku.
    final before = folded.substring(0, at).trimRight();
    final prev = RegExp(r'[a-z]+$').firstMatch(before)?.group(0);
    final polish = prev != null && _genitiveAfter.contains(prev) ? l.gen : l.nom;
    // fold zachowuje długość tekstu (podmiana znak za znak).
    final out = text.substring(0, at) + polish + text.substring(at + key.length);
    return (name: out.trim(), latin: l.latin);
  }
  return null;
}
