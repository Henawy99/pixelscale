import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/data_service.dart';

class SeoScreen extends StatelessWidget {
  const SeoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final seo = DataService.getSeoInfo();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('SEO Übersicht'), backgroundColor: AppTheme.bg),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Score card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.gradient, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppTheme.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80, height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(value: seo.pageSpeed / 100, strokeWidth: 6,
                        backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
                      Text('${seo.pageSpeed.toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SEO Score', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Ihre Website ist gut optimiert', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Meta-Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          _metaCard('Title Tag', seo.title, '${seo.titleLength} Zeichen', seo.titleLength <= 70 ? AppTheme.green : AppTheme.orange),
          const SizedBox(height: 10),
          _metaCard('Meta Description', seo.description, '${seo.descLength} Zeichen', seo.descLength <= 160 ? AppTheme.green : AppTheme.orange),
          const SizedBox(height: 24),

          const Text('Technische Checks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          _checkItem('Canonical URL', seo.hasCanonical),
          _checkItem('Open Graph Tags', seo.hasOgTags),
          _checkItem('Schema.org Markup', seo.hasSchema),
          _checkItem('Mobile-freundlich', seo.mobileReady),
          _checkItem('Indexiert', seo.isIndexed),
          const SizedBox(height: 24),

          const Text('Empfehlungen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          _tipCard(Icons.image, 'Bilder optimieren', 'Komprimieren Sie Bilder für schnellere Ladezeiten und fügen Sie Alt-Tags hinzu.'),
          const SizedBox(height: 10),
          _tipCard(Icons.link, 'Backlinks aufbauen', 'Erstellen Sie Einträge auf lokalen Verzeichnissen (Herold, Google Business).'),
          const SizedBox(height: 10),
          _tipCard(Icons.article, 'Blog hinzufügen', 'Regelmäßige Blogposts zu Umzugs-Tipps verbessern Ihr Ranking.'),
        ],
      ),
    );
  }

  Widget _metaCard(String label, String content, String info, Color infoColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: infoColor.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
                child: Text(info, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: infoColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.5)),
        ],
      ),
    );
  }

  Widget _checkItem(String label, bool ok) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: (ok ? AppTheme.green : AppTheme.red).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ok ? Icons.check : Icons.close, color: ok ? AppTheme.green : AppTheme.red, size: 16),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          const Spacer(),
          Text(ok ? 'OK' : 'Fehlt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? AppTheme.green : AppTheme.red)),
        ],
      ),
    );
  }

  Widget _tipCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.gold, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
