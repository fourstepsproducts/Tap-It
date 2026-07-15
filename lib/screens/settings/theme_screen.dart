import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tapit/providers/theme_provider.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  late ThemeMode _selectedThemeMode;
  late Color _selectedSeedColor;

  @override
  void initState() {
    super.initState();
    final provider = ThemeProvider.instance;
    _selectedThemeMode = provider.themeMode;
    _selectedSeedColor = provider.seedColor;
  }

  void _applyChanges() {
    final provider = ThemeProvider.instance;
    provider.setThemeMode(_selectedThemeMode);
    provider.setSeedColor(_selectedSeedColor);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Theme settings applied!')));
  }

  @override
  Widget build(BuildContext context) {
    // Calculate brightness for preview based on selection
    Brightness previewBrightness;
    if (_selectedThemeMode == ThemeMode.system) {
      previewBrightness = MediaQuery.platformBrightnessOf(context);
    } else {
      previewBrightness = _selectedThemeMode == ThemeMode.dark
          ? Brightness.dark
          : Brightness.light;
    }

    // Create a temporary theme for the preview using exact colors
    final previewTheme = ThemeData(
      colorScheme: previewBrightness == Brightness.dark
          ? ColorScheme.dark(
              primary: _selectedSeedColor,
              onPrimary: Colors.white,
              primaryContainer: _selectedSeedColor.withOpacity(0.2),
              onPrimaryContainer: _selectedSeedColor.withOpacity(0.8),
              secondary: _selectedSeedColor,
              onSecondary: Colors.white,
              surface: const Color(0xFF1E1E1E),
              onSurface: Colors.white,
              background: const Color(0xFF121212),
              onBackground: Colors.white,
            )
          : ColorScheme.light(
              primary: _selectedSeedColor,
              onPrimary: Colors.white,
              primaryContainer: _selectedSeedColor.withOpacity(0.1),
              onPrimaryContainer: _selectedSeedColor,
              secondary: _selectedSeedColor,
              onSecondary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1E1E1E),
              background: const Color(0xFFF8F9FA),
              onBackground: const Color(0xFF1E1E1E),
            ),
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(
        previewBrightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Appearance',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader(context, 'Theme Mode'),
          const SizedBox(height: 16),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.settings_brightness),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {_selectedThemeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              setState(() {
                _selectedThemeMode = newSelection.first;
              });
            },
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Accent Color'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildColorOption(const Color(0xFF3F51B5), 'Indigo'),
              _buildColorOption(const Color(0xFF5B5FED), 'Purple'),
              _buildColorOption(const Color(0xFF2196F3), 'Blue'),
              _buildColorOption(const Color(0xFF4CAF50), 'Green'),
              _buildColorOption(const Color(0xFFFF9800), 'Orange'),
              _buildColorOption(const Color(0xFFF44336), 'Red'),
              _buildColorOption(const Color(0xFFE91E63), 'Pink'),
              _buildColorOption(const Color(0xFF009688), 'Teal'),
              _buildColorOption(const Color(0xFF607D8B), 'Grey'),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Preview',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Preview Container
          Theme(
            data: previewTheme,
            child: Builder(
              builder: (previewContext) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: previewTheme.colorScheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: previewTheme.colorScheme.outlineVariant,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'This is how it looks!',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: previewTheme.colorScheme.onBackground,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FilledButton(
                            onPressed: () {},
                            child: const Text('Primary'),
                          ),
                          FloatingActionButton.small(
                            onPressed: () {},
                            backgroundColor: previewTheme.colorScheme.primary,
                            foregroundColor: previewTheme.colorScheme.onPrimary,
                            child: const Icon(Icons.add),
                          ),
                          Switch(value: true, onChanged: (_) {}),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.star_outline,
                            color: previewTheme.colorScheme.primary,
                          ),
                          title: const Text('Sample List Item'),
                          subtitle: const Text('With subtitle text'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Apply Settings',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildColorOption(Color color, String label) {
    final isSelected = _selectedSeedColor.value == color.value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSeedColor = color;
        });
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onBackground,
                      width: 3,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
