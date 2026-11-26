/// Sorting game content. Items are common, unambiguous household items.
/// The picture for each item is a emoji glyph (Noto Emoji, OFL) or a drawn shape, not a photo.
/// Explanations are short general guidance written for this app and are not
/// copied from a single official source; local collection rules can differ.
class GameItem {
  final String en;
  final String ar;
  final String answer; // plastic, metal, glass, paper, organic
  final String pic; // emoji glyph, or 'shape:bottle|can|foil'
  final String expEn;
  final String expAr;
  const GameItem(this.en, this.ar, this.answer, this.pic, this.expEn, this.expAr);
}

const gameLevels = <List<GameItem>>[
  [
    GameItem('Plastic water bottle', 'زجاجة مياه بلاستيك', 'plastic', 'shape:bottle',
        'Empty plastic bottles are one of the most commonly recycled plastics. Empty it and keep the cap on if your local rules allow.',
        'زجاجات البلاستيك الفاضية من أكتر أنواع البلاستيك اللي بيتم تدويرها. فضّيها، وسيب الغطا عليها لو القواعد عندكم بتسمح.'),
    GameItem('Aluminum soda can', 'علبة مشروب غازي ألومنيوم', 'metal', 'shape:can',
        'Aluminum cans are metal and can be recycled many times. Empty them first.',
        'علب الألومنيوم معدن وبتتدوّر مرات كتير. فضّيها الأول.'),
    GameItem('Glass jar', 'برطمان زجاج', 'glass', '🫙',
        'Glass jars are recyclable glass. Rinse them and take off the lid.',
        'برطمانات الزجاج زجاج قابل للتدوير. اشطفها وشيل الغطا.'),
    GameItem('Newspaper', 'جرنال', 'paper', '📰',
        'Clean, dry paper can be recycled. Wet or dirty paper is harder to recycle.',
        'الورق النضيف الناشف بيتدوّر. الورق المبلول أو المتسخ تدويره أصعب.'),
    GameItem('Banana peel', 'قشر موز', 'organic', '🍌',
        'Fruit and vegetable scraps are organic waste and can be composted.',
        'بقايا الفاكهة والخضار مخلفات عضوية وممكن تتحوّل لسماد.'),
  ],
  [
    GameItem('Cardboard box', 'علبة كرتون', 'paper', '📦',
        'Cardboard is paper-based. Flatten it and keep it dry.',
        'الكرتون من الورق. اسطّحه وخليه ناشف.'),
    GameItem('Steel food can', 'علبة معلبات صفيح', 'metal', '🥫',
        'Steel food cans are metal. Empty and rinse them.',
        'علب المعلبات الصفيح معدن. فضّيها واشطفها.'),
    GameItem('Glass bottle', 'إزاز زجاجة', 'glass', '🍾',
        'Glass bottles are recyclable glass. Empty them first.',
        'زجاجات الزجاج قابلة للتدوير. فضّيها الأول.'),
    GameItem('Shampoo bottle', 'زجاجة شامبو', 'plastic', '🧴',
        'Rigid plastic bottles are plastic. Empty and rinse them.',
        'العبوات البلاستيك الصلبة بلاستيك. فضّيها واشطفها.'),
    GameItem('Apple core', 'قلب تفاحة', 'organic', '🍎',
        'Food scraps are organic waste and can be composted.',
        'بقايا الأكل مخلفات عضوية وممكن تتحوّل لسماد.'),
  ],
  [
    GameItem('Aluminum foil', 'ورق ألومنيوم', 'metal', 'shape:foil',
        'Aluminum foil is metal. Clean foil can usually be recycled with metals; remove food residue.',
        'ورق الألومنيوم معدن. لو نضيف بيتدوّر مع المعادن، شيل بقايا الأكل منه.'),
    GameItem('Coffee grounds', 'تفل قهوة', 'organic', '☕',
        'Coffee grounds are organic waste and work well in compost.',
        'تفل القهوة مخلفات عضوية وكويس في السماد.'),
    GameItem('Cereal box', 'علبة كورن فليكس', 'paper', '📦',
        'Thin cardboard boxes are paper-based. Remove any plastic bag inside.',
        'علب الكرتون الرفيعة من الورق. شيل كيس البلاستيك اللي جواها.'),
    GameItem('Jam jar', 'برطمان مربى', 'glass', '🍯',
        'Glass jars are recyclable glass. Rinse out the food and remove the lid.',
        'برطمانات الزجاج قابلة للتدوير. اشطف بقايا الأكل وشيل الغطا.'),
    GameItem('Detergent bottle', 'عبوة منظف', 'plastic', 'shape:bottle',
        'Rigid plastic containers are plastic. Empty and rinse them.',
        'العبوات البلاستيك الصلبة بلاستيك. فضّيها واشطفها.'),
  ],
];

const passMark = 4; // correct answers (out of 5) needed to unlock the next level
