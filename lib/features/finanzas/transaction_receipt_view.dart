import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';

class TransactionReceiptView extends StatefulWidget {
  const TransactionReceiptView({super.key, required this.path});

  final String path;

  @override
  State<TransactionReceiptView> createState() => _TransactionReceiptViewState();
}

class _TransactionReceiptViewState extends State<TransactionReceiptView> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await supabase.storage
          .from('receipts')
          .createSignedUrl(widget.path, 900);
      if (mounted) setState(() => _url = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: _url == null
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            )
          : Image.network(
              _url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No se pudo cargar el recibo.'),
              ),
            ),
    );
  }
}
