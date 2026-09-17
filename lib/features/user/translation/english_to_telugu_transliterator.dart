/// Phonetic English → Telugu *script* transliteration — same words, same
/// sounds, just written in Telugu letters ("Milk" → "మిల్క్"), deliberately
/// not translation ("Milk" → "పాలు" is a different word with the same
/// meaning, which is exactly what this avoids). Used for catalogue content
/// (category names, product name/description/unit) via `TranslatedText`,
/// which is the only call site — screens shouldn't call this directly.
///
/// Pure, deterministic, on-device, no network/model download: this is a
/// rule-based phonetic engine, not a dictionary or ML model. English
/// spelling doesn't mark pronunciation reliably (the "ea" in "bread" and
/// "meat" are different sounds; "th" can be voiced or voiceless; vowel
/// length is often just implied) — this is a best-effort approximation of
/// how the word is normally read aloud, close enough to be recognizable
/// and natural for the overwhelming majority of everyday
/// food/grocery/pharmacy vocabulary, with [_overrides] hand-fixing the
/// small set of very common words the general rules get wrong.
library;

const _consonantDigraphs = <String, String>{
  'tch': 'చ్',
  'dge': 'జ్',
  'ph': 'ఫ్',
  'sh': 'శ్',
  'ch': 'చ్',
  'th': 'థ్',
  'gh': 'గ్',
  'kh': 'ఖ్',
  'bh': 'భ్',
  'dh': 'ధ్',
  'jh': 'ఝ్',
  'ck': 'క్',
  'qu': 'క్వ్',
  'ng': 'ంగ్',
  'ny': 'న్య్',
};

/// A private-use codepoint standing in for a word-final "ow" (as in
/// "yellow", "window") that we've decided should read as a long "o" rather
/// than the "ow" of "how"/"cow" — see [_preprocess].
const _finalOwSentinel = '';

String _consonantFor(String ch, {required String? nextChar}) {
  switch (ch) {
    case 'c':
      return (nextChar != null && 'eiy'.contains(nextChar)) ? 'స్' : 'క్';
    case 'g':
      return (nextChar != null && 'eiy'.contains(nextChar)) ? 'జ్' : 'గ్';
    case 'b':
      return 'బ్';
    case 'd':
      return 'డ్';
    case 'f':
      return 'ఫ్';
    case 'h':
      return 'హ్';
    case 'j':
      return 'జ్';
    case 'k':
      return 'క్';
    case 'l':
      return 'ల్';
    case 'm':
      return 'మ్';
    case 'n':
      return 'న్';
    case 'p':
      return 'ప్';
    case 'r':
      return 'ర్';
    case 's':
      return 'స్';
    case 't':
      return 'ట్';
    case 'v':
      return 'వ్';
    case 'w':
      return 'వ్';
    case 'x':
      return 'క్స్';
    case 'y':
      return 'య్';
    case 'z':
      return 'జ్';
    default:
      return '';
  }
}

/// Vowel sign (matra) attached to a preceding consonant — replaces that
/// consonant's inherent "a" sound. Empty string for "a" itself: the
/// inherent vowel needs no mark at all (a bare consonant already carries it).
const _vowelMatra = <String, String>{
  'a': '',
  'aa': 'ా',
  'i': 'ి',
  'ii': 'ీ',
  'u': 'ు',
  'uu': 'ూ',
  'e': 'ె',
  'ee': 'ే',
  'ai': 'ై',
  'o': 'ొ',
  'oo': 'ో',
  'au': 'ౌ',
};

/// The same vowel sounds as standalone letters — used at the start of a
/// word/syllable, where there's no preceding consonant for a matra to
/// attach to.
const _vowelIndependent = <String, String>{
  'a': 'అ',
  'aa': 'ఆ',
  'i': 'ఇ',
  'ii': 'ఈ',
  'u': 'ఉ',
  'uu': 'ఊ',
  'e': 'ఎ',
  'ee': 'ఏ',
  'ai': 'ఐ',
  'o': 'ఒ',
  'oo': 'ఓ',
  'au': 'ఔ',
};

/// Which glide consonant (య్ vs వ్) bridges two adjacent vowel-sounds that
/// have no consonant between them in the spelling ("onion" → o-ni-**y**-on)
/// — decided by the *preceding* vowel: a front/high one (i/e-family) glides
/// with య, a back one (u/o-family) with వ.
const _frontVowels = {'i', 'ii', 'e', 'ee', 'ai'};

/// English digraph spelling → canonical vowel-sound id, checked longest
/// match first.
const _vowelDigraphs = <String, String>{
  'augh': 'aa',
  'eigh': 'ee',
  'ough': 'aa',
  'igh': 'ai',
  'ee': 'ii',
  'ea': 'ii',
  'oo': 'uu',
  'ai': 'ai',
  'ay': 'ee',
  'oi': 'oi', // handled specially — see _scan
  'ou': 'au',
  'oa': 'oo',
  'au': 'aa',
  'aw': 'aa',
  'ue': 'uu',
  'ie': 'ai',
};

bool _isVowelLetter(String ch) => 'aeiou'.contains(ch);
bool _isLetter(String ch) => RegExp(r'^[a-z]$').hasMatch(ch);

/// One phonetic "beat" — either a consonant sound (already carrying its
/// own virama, stripped off again in [_assemble] if a vowel follows) or a
/// vowel-sound id to look up in [_vowelMatra]/[_vowelIndependent].
class _Unit {
  _Unit.consonant(this.telugu) : isVowel = false, soundId = null;
  _Unit.vowel(this.soundId) : isVowel = true, telugu = null;
  final bool isVowel;
  final String? telugu;
  final String? soundId;
}

({String stem, bool hadS, bool hadEs}) _stripSSuffix(String word) {
  if (word.length > 3 && word.endsWith('es') && 'sxzh'.contains(word[word.length - 3])) {
    return (stem: word.substring(0, word.length - 2), hadS: false, hadEs: true);
  }
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
    return (stem: word.substring(0, word.length - 1), hadS: true, hadEs: false);
  }
  return (stem: word, hadS: false, hadEs: false);
}

/// Common "-Cle" endings ("apple", "table", "candle", "bottle") are the
/// unstressed /əl/ syllable, not a real vowel+consonant+silent-e — rewritten
/// here as "-Cil" so the general scanner produces a natural i-vowel + l
/// rather than an unpronounceable 3-consonant cluster.
String _rewriteLeEnding(String word) {
  if (word.length < 4 || !word.endsWith('le')) return word;
  final beforeLe = word[word.length - 3];
  if (_isLetter(beforeLe) && !_isVowelLetter(beforeLe)) {
    return '${word.substring(0, word.length - 2)}il';
  }
  return word;
}

String _preprocess(String word) {
  var w = _rewriteLeEnding(word);
  if (w.endsWith('ow') && w.length > 2) {
    w = '${w.substring(0, w.length - 2)}$_finalOwSentinel';
  }
  return w;
}

/// English "vowel-consonant-e" at word end shifts the vowel to its long/
/// diphthong form and silences the 'e' ("cake", "time", "code", "cube").
({String word, Map<int, String> magicEOverrides}) _applyMagicE(String word) {
  if (word.length < 4 || !word.endsWith('e')) return (word: word, magicEOverrides: {});
  final consonant = word[word.length - 2];
  if (!_isLetter(consonant) || _isVowelLetter(consonant)) return (word: word, magicEOverrides: {});
  final vowelIndex = word.length - 3;
  if (vowelIndex < 0 || !_isVowelLetter(word[vowelIndex])) return (word: word, magicEOverrides: {});
  const shift = {'a': 'ee', 'i': 'ai', 'o': 'oo', 'u': 'uu', 'e': 'ii'};
  final shifted = shift[word[vowelIndex]];
  if (shifted == null) return (word: word, magicEOverrides: {});
  return (word: word.substring(0, word.length - 1), magicEOverrides: {vowelIndex: shifted});
}

List<_Unit> _scan(String word, Map<int, String> magicEOverrides) {
  final units = <_Unit>[];
  var i = 0;
  while (i < word.length) {
    if (word[i] == _finalOwSentinel) {
      units.add(_Unit.vowel('oo'));
      i += 1;
      continue;
    }
    final override = magicEOverrides[i];
    if (override != null) {
      units.add(_Unit.vowel(override));
      i += 1;
      continue;
    }
    final ch = word[i];
    if (_isVowelLetter(ch)) {
      String? matchedId;
      var matchedLen = 0;
      for (final entry in _vowelDigraphs.entries) {
        if (word.length - i >= entry.key.length && word.substring(i, i + entry.key.length) == entry.key) {
          if (entry.key.length > matchedLen) {
            matchedId = entry.value;
            matchedLen = entry.key.length;
          }
        }
      }
      if (matchedId == 'oi') {
        // "oy"/"oi" — rendered as o-vowel + య్ glide + i-vowel.
        units.add(_Unit.vowel('o'));
        units.add(_Unit.consonant('య్'));
        units.add(_Unit.vowel('i'));
        i += matchedLen;
        continue;
      }
      if (matchedId != null) {
        units.add(_Unit.vowel(matchedId));
        i += matchedLen;
        continue;
      }
      units.add(_Unit.vowel(ch));
      i += 1;
      continue;
    }
    if (ch == 'y') {
      final isLast = i == word.length - 1;
      final prevWasConsonant = units.isNotEmpty && !units.last.isVowel;
      final nextIsVowel = i + 1 < word.length && _isVowelLetter(word[i + 1]);
      if (isLast && prevWasConsonant && !nextIsVowel) {
        // Word-final 'y' after a consonant with nothing else following
        // acts as a vowel ("curry", "candy"), not a consonant.
        units.add(_Unit.vowel('ii'));
        i += 1;
        continue;
      }
    }
    if (!_isLetter(ch)) {
      i += 1;
      continue;
    }
    String? matchedTelugu;
    var matchedLen = 0;
    for (final entry in _consonantDigraphs.entries) {
      if (word.length - i >= entry.key.length && word.substring(i, i + entry.key.length) == entry.key) {
        if (entry.key.length > matchedLen) {
          matchedTelugu = entry.value;
          matchedLen = entry.key.length;
        }
      }
    }
    if (matchedTelugu != null) {
      units.add(_Unit.consonant(matchedTelugu));
      i += matchedLen;
      continue;
    }
    final nextChar = i + 1 < word.length ? word[i + 1] : null;
    final single = _consonantFor(ch, nextChar: nextChar);
    if (single.isNotEmpty) {
      units.add(_Unit.consonant(single));
      i += 1;
      continue;
    }
    i += 1;
  }
  return units;
}

String _assemble(List<_Unit> units) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < units.length) {
    final unit = units[i];
    if (!unit.isVowel) {
      final nextIsVowel = i + 1 < units.length && units[i + 1].isVowel;
      if (nextIsVowel) {
        final vowelId = units[i + 1].soundId!;
        final consonantBase = unit.telugu!.substring(0, unit.telugu!.length - 1); // strip the virama
        buffer.write(consonantBase);
        buffer.write(_vowelMatra[vowelId] ?? '');
        i += 2;
        continue;
      }
      buffer.write(unit.telugu);
      i += 1;
      continue;
    }
    final prevWasVowel = i > 0 && units[i - 1].isVowel;
    if (prevWasVowel) {
      final glide = _frontVowels.contains(units[i - 1].soundId) ? 'య' : 'వ';
      buffer.write(glide);
      buffer.write(_vowelMatra[unit.soundId] ?? '');
    } else {
      buffer.write(_vowelIndependent[unit.soundId] ?? '');
    }
    i += 1;
  }
  return buffer.toString();
}

/// Curated exceptions for words the general spelling-based rules can't get
/// right — English spelling doesn't reliably mark vowel length ("bread" vs
/// "meat" spell the same "ea" for two different sounds) or which
/// consonant clusters still keep the "magic e" long vowel ("paste") — so a
/// handful of very common catalogue words are hand-fixed rather than
/// algorithmically derived. Extend this list as specific product names in
/// the catalogue turn out to need it.
const _overrides = <String, String>{
  'rice': 'రైస్',
  'water': 'వాటర్',
  'biryani': 'బిర్యానీ',
  'bread': 'బ్రెడ్',
  'tomato': 'టమాటో',
  'potato': 'పొటాటో',
  'juice': 'జ్యూస్',
  'butter': 'బటర్',
  'mango': 'మ్యాంగో',
  'paste': 'పేస్ట్',
  'toothpaste': 'టూత్‌పేస్ట్',
};

/// Transliterates one whitespace-free English word to Telugu script.
String transliterateWord(String word) {
  final lower = word.toLowerCase();
  final override = _overrides[lower];
  if (override != null) return override;

  final suffix = _stripSSuffix(lower);
  // "tomatoes"/"potatoes": stripping just the trailing "s" leaves a
  // dangling silent "e" ("tomatoe") that won't match the singular's
  // override entry ("tomato") until that's trimmed too.
  final overrideStem = _overrides[suffix.stem] ?? (suffix.stem.endsWith('e') ? _overrides[suffix.stem.substring(0, suffix.stem.length - 1)] : null);
  if (overrideStem != null) {
    if (suffix.hadEs) return '$overrideStemెస్';
    if (suffix.hadS) return '$overrideStemస్';
  }

  final preprocessed = _preprocess(suffix.stem);
  final magic = _applyMagicE(preprocessed);
  final units = _scan(magic.word, magic.magicEOverrides);
  var result = _assemble(units);
  if (suffix.hadEs) {
    result = '$resultెస్';
  } else if (suffix.hadS) {
    result = '$resultస్';
  }
  return result;
}

/// Transliterates a full string (product name, description, ...),
/// word-by-word — numbers, punctuation, and any already-non-Latin text
/// pass through unchanged.
String transliterateText(String text) {
  final buffer = StringBuffer();
  final regex = RegExp(r'[A-Za-z]+|[^A-Za-z]+');
  for (final match in regex.allMatches(text)) {
    final token = match.group(0)!;
    if (RegExp(r'^[A-Za-z]+$').hasMatch(token)) {
      buffer.write(transliterateWord(token));
    } else {
      buffer.write(token);
    }
  }
  return buffer.toString();
}
