/// General, non-statistical environmental tips. One is shown per day.
const List<List<String>> dailyTips = [
  ['Rinse containers before recycling. Food residue can spoil a whole batch.', 'اشطف العبوات قبل التدوير. بقايا الأكل ممكن تبوّظ دفعة كاملة.'],
  ['Glass and metal can be recycled again and again without losing quality.', 'الزجاج والمعادن بيتدوّروا مرات كتير من غير ما تقل جودتهم.'],
  ['Keep paper dry. Wet or greasy paper is hard to recycle.', 'خلي الورق جاف. الورق المبلول أو الدهني صعب يتدوّر.'],
  ['Composting food scraps turns waste into natural fertilizer.', 'عمل سماد من بقايا الأكل بيحوّل المخلفات لسماد طبيعي.'],
  ['The best waste is the one you never create. Reuse bags and bottles.', 'أحسن مخلفات هي اللي ما بتتعملش. أعد استخدام الأكياس والزجاجات.'],
  ['Separate organic waste from dry recyclables at home.', 'افصل المخلفات العضوية عن الجافة القابلة للتدوير في البيت.'],
  ['Flatten cardboard boxes to save space in the bin.', 'افرد صناديق الكرتون عشان توفر مكان في السلة.'],
];

int tipIndexFor(DateTime d) =>
    d.difference(DateTime(d.year, 1, 1)).inDays % dailyTips.length;
