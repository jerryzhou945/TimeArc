// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_CATEGORIZATION_NORMALIZE_H
#define TIMEARC_SERVICES_CATEGORIZATION_NORMALIZE_H

#include <QChar>
#include <QString>

// Text normalization for categorization matching.
//
// Every observed field and every rule needle passes through normalize() before
// comparison, so the same transformation applies to both sides. That symmetry
// is what lets a needle spelled "chrome.exe" match a macOS bundle id and a
// Windows executable basename without the rule author thinking about it.
//
// Non-ASCII literals in this subsystem use \uXXXX escapes: the build sets no
// /utf-8 flag, so raw UTF-8 in a narrow literal is interpreted in the
// compiler's codepage on MSVC.
namespace TimeArc::Categorization {

// Drop combining marks so "café" and "cafe" compare equal. CJK is unaffected.
inline QString foldDiacritics(const QString& value) {
  const QString decomposed = value.normalized(QString::NormalizationForm_D);
  QString folded;
  folded.reserve(decomposed.size());
  for (const QChar character : decomposed) {
    if (character.category() == QChar::Mark_NonSpacing) continue;
    folded.append(character);
  }
  return folded.normalized(QString::NormalizationForm_C);
}

inline bool isDashVariant(QChar character) {
  const char16_t code = character.unicode();
  return code == 0x2010 || code == 0x2011 || code == 0x2012 || code == 0x2013 ||
         code == 0x2014 || code == 0x2015 || code == 0x2212;
}

// 1. NFKC        - unify full-width/half-width and CJK compatibility forms.
// 2. case fold   - not toLower(); handles Turkish dotless i, German sharp s.
// 3. diacritics  - see foldDiacritics().
// 4. dashes      - every dash variant becomes '-'.
// 5. whitespace  - collapse runs, trim.
// 6. suffix      - strip one trailing ".exe" or ".app".
inline QString normalize(const QString& raw) {
  if (raw.trimmed().isEmpty()) return QString();

  QString value = raw.normalized(QString::NormalizationForm_KC).toCaseFolded();
  value = foldDiacritics(value);

  for (QChar& character : value) {
    if (isDashVariant(character)) character = QLatin1Char('-');
  }

  value = value.simplified();

  if (value.endsWith(QLatin1String(".exe")) ||
      value.endsWith(QLatin1String(".app"))) {
    value.chop(4);
  }

  return value.trimmed();
}

// Identity is one haystack for substring matching and two components for
// exact matching. Joining with a separator that cannot occur in either field
// keeps a needle from spanning the boundary.
inline QString joinIdentity(const QString& normalizedDisplayName,
                            const QString& normalizedAppId) {
  return normalizedDisplayName + QChar(0x1f) + normalizedAppId;
}

}  // namespace TimeArc::Categorization

#endif  // TIMEARC_SERVICES_CATEGORIZATION_NORMALIZE_H
