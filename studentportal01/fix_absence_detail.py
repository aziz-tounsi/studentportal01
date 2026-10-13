
with open('lib/presentation/screens/absences/absence_detail_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Fix _getShortcutOrName
new_func = '''String _getShortcutOrName(AbsenceDetailData d) {
    final name = d.subjectName.trim();
    if (name.length > 15) {
      if (d.subjectCode != null && d.subjectCode!.trim().isNotEmpty) {
        return d.subjectCode!.trim();
      }
      final lower = name.toLowerCase();
      if (lower.contains('sciences de la vie') || lower.contains('svt') || lower.contains('terre')) {
        return 'SVT';
      }
      if (lower.contains('algorithmique') || lower.contains('structure')) {
        return 'ASD';
      }
      if (lower.contains('architecture') || lower.contains('ordinateur')) {
        return 'ARCHI';
      }
      if (lower.contains('math') || lower.contains('analyse') || lower.contains('algebre')) {
        return 'MATH';
      }
      if (lower.contains('compta') || lower.contains('gestion')) {
        return 'COMPTA';
      }
      if (lower.contains('anglais') || lower.contains('english') || lower.contains('francais')) {
        return 'LANG';
      }
      
      // Fallback: take first letters of each word
      final words = name.split(' ').where((w) => w.length > 2).toList();
      if (words.length >= 2) {
         return words.map((w) => w[0].toUpperCase()).join('');
      }
      
      return name.substring(0, 15) + '...';
    }
    return name;
  }'''

content = re.sub(r'String _getShortcutOrName\(AbsenceDetailData d\) \{.*?\n  \}', new_func, content, flags=re.DOTALL)

# Add softWrap: false
content = content.replace(
    '''_getShortcutOrName(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,''',
    '''_getShortcutOrName(d),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,'''
)

with open('lib/presentation/screens/absences/absence_detail_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

