
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace GoogleFonts.cairo(...) with TextStyle(fontFamily: GoogleFonts.cairo().fontFamily, ...)
    content = re.sub(
        r'GoogleFonts\.cairo\(\s*fontSize:\s*([\d\.]+),\s*fontWeight:\s*([^,]+),\s*color:\s*([^,]+)(,\s*shadows:\s*[^,]+,\s*)?\s*\)',
        r'TextStyle(fontFamily: GoogleFonts.cairo().fontFamily, fontSize: \1, fontWeight: \2, color: \3\4)',
        content, flags=re.DOTALL
    )
    # Also for SemesterTabBar
    content = re.sub(
        r'GoogleFonts\.cairo\(\s*fontSize:\s*([\d\.]+),\s*fontWeight:\s*([^,]+),\s*color:\s*([^\)]+)\)',
        r'TextStyle(fontFamily: GoogleFonts.cairo().fontFamily, fontSize: \1, fontWeight: \2, color: \3)',
        content, flags=re.DOTALL
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

process_file('lib/presentation/widgets/semester_navigator.dart')
process_file('lib/presentation/screens/resultats/resultats_screen.dart')
process_file('lib/presentation/screens/resultats/resultats_screen_v2.dart')

