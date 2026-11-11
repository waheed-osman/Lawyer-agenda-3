import 'package:flutter/material.dart';

import '../obligations/obligations_screen.dart';

/// تبويب "المزيد": الالتزامات الشخصية.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_Item>[
      _Item('الالتزامات الشخصية', 'ديون لي وعليّ، إيجارات، أقساط، فواتير', Icons.account_balance_wallet_outlined,
          const Color(0xFF2E7D32), () => const ObligationsScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (final it in items)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: it.color.withOpacity(0.15),
                child: Icon(it.icon, color: it.color),
              ),
              title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(it.subtitle),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.page())),
            ),
          ),
      ]),
    );
  }
}

class _Item {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() page;
  _Item(this.title, this.subtitle, this.icon, this.color, this.page);
}
