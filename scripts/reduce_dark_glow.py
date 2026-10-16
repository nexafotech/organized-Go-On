# 1. Update app_tokens.dart
with open('mobile/lib/core/theme/app_tokens.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Soften dark theme borders and jewels
replacements = [
    ('border: Color(0x2EFFFFFF),          // Translucent specular white border (~18%)', 'border: Color(0x1F7E7594),          // Restrained soft obsidian border (~12%)'),
    ('borderStrong: Color(0x52FFFFFF),    // Specular edge highlight (~32%)', 'borderStrong: Color(0x33A89EC0),    // Restrained edge highlight (~20%)'),
    ('glassBorder: Color(0x33FFFFFF),        // 20% specular white rim', 'glassBorder: Color(0x24FFFFFF),        // 14% subtle specular rim (reduced glow)'),
    ('glassBorderStrong: Color(0x59FFFFFF),  // 35% specular white rim', 'glassBorderStrong: Color(0x38FFFFFF),  // 22% refined specular rim (reduced glow)'),
    ('glassHighlight: Color(0x66FFFFFF),     // Convex specular arc glare', 'glassHighlight: Color(0x26FFFFFF),     // Restrained specular glare (~15%)'),
    ('presentBg: Color(0x2610B981),       // Translucent emerald glass jewel', 'presentBg: Color(0x1A10B981),       // Restrained emerald jewel (~10%)'),
    ('absentBg: Color(0x26F43F5E),        // Translucent ruby glass jewel', 'absentBg: Color(0x1AF43F5E),        // Restrained ruby jewel (~10%)'),
    ('odBg: Color(0x26818CF8),            // Translucent sapphire glass jewel', 'odBg: Color(0x1A818CF8),            // Restrained sapphire jewel (~10%)'),
    ('warningBg: Color(0x26F59E0B),', 'warningBg: Color(0x1AF59E0B),'),
    ('errorBg: Color(0x26F43F5E),', 'errorBg: Color(0x1AF43F5E),'),
    ('infoBg: Color(0x26818CF8),', 'infoBg: Color(0x1A818CF8),'),
]

for old, new in replacements:
    if old in text:
        text = text.replace(old, new)
        print(f"Replaced token: {old[:30]}")
    else:
        print(f"WARN token not found: {old[:30]}")

# Add darkSpecularGradient to AppGlass
dark_grad = '''  static const LinearGradient darkSpecularGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x0AFFFFFF), // 4% subtle sheen (no milky glow)
      Color(0x00FFFFFF), // Transparent base
    ],
  );

  // Specular Gradients'''

if 'darkSpecularGradient' not in text:
    text = text.replace('  // Specular Gradients', dark_grad)
    print("Added darkSpecularGradient to AppGlass")

with open('mobile/lib/core/theme/app_tokens.dart', 'w', encoding='utf-8') as f:
    f.write(text)

# 2. Update app_card.dart
with open('mobile/lib/widgets/common/app_card.dart', 'r', encoding='utf-8') as f:
    card_text = f.read()

# Soften top rim glare from 0.35 to 0.12 in dark mode
old_rim = "colors.isDark ? Colors.white.withValues(alpha: 0.35) : Colors.transparent"
new_rim = "colors.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.transparent"

if old_rim in card_text:
    card_text = card_text.replace(old_rim, new_rim)
    print("Softened top rim glare in app_card.dart")

# Use darkSpecularGradient when colors.isDark in GlassCard
old_grad = "gradient = customGradient ?? AppGlass.specularGradient;"
new_grad = "gradient = customGradient ?? (colors.isDark ? AppGlass.darkSpecularGradient : AppGlass.specularGradient);"

if old_grad in card_text:
    card_text = card_text.replace(old_grad, new_grad)
    print("Applied darkSpecularGradient to GlassCard in app_card.dart")

with open('mobile/lib/widgets/common/app_card.dart', 'w', encoding='utf-8') as f:
    f.write(card_text)

print("Dark theme glow reduction completed!")
