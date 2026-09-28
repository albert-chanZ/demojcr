import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignTicketDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const SignTicketDialog({super.key, required this.ticket});

  @override
  State<SignTicketDialog> createState() => _SignTicketDialogState();
}

class _SignTicketDialogState extends State<SignTicketDialog> {
  final _recibioController = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isSaving = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _recibioController.text = widget.ticket['recibio_nombre'] ?? '';
  }

  @override
  void dispose() {
    _recibioController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _guardarFirma() async {
    if (_signatureController.isEmpty || _recibioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el nombre y realice la firma')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Uint8List? signatureBytes = await _signatureController.toPngBytes();

      if (signatureBytes != null) {
        final fileName = 'firma_${widget.ticket['id']}_${DateTime.now().millisecondsSinceEpoch}.png';

        await _supabase.storage.from('firmas').uploadBinary(
              fileName,
              signatureBytes,
              fileOptions: const FileOptions(contentType: 'image/png'),
            );

        final firmaUrl = _supabase.storage.from('firmas').getPublicUrl(fileName);

        await _supabase.from('tickets').update({
          'recibio_nombre': _recibioController.text,
          'firma_url': firmaUrl,
          'estado': 'completado',
        }).eq('id', widget.ticket['id']);

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar firma: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Firmar Ticket #${widget.ticket['folio']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _recibioController,
              decoration: const InputDecoration(
                labelText: 'Nombre de quien recibe el servicio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Firma del cliente:'),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: Signature(
                controller: _signatureController,
                height: 150,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _signatureController.clear(),
                child: const Text('Limpiar Firma'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _guardarFirma,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar y Completar'),
        ),
      ],
    );
  }
}