import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/ticket_reminder_service.dart';

class TicketFormPage extends StatefulWidget {
  final Map<String, dynamic>? ticketParaEditar;

  const TicketFormPage({super.key, this.ticketParaEditar});

  @override
  State<TicketFormPage> createState() => _TicketFormPageState();
}

class _TicketFormPageState extends State<TicketFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _folioController = TextEditingController();
  final _clienteController = TextEditingController();
  final _solicitaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _lugarController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _recibioController = TextEditingController();

  DateTime _fechaSeleccionada = DateTime.now();
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  bool _isSaving = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.ticketParaEditar != null) {
      final t = widget.ticketParaEditar!;
      _folioController.text = t['folio']?.toString() ?? '';
      _clienteController.text = t['cliente'] ?? '';
      _solicitaController.text = t['solicita'] ?? '';
      _telefonoController.text = t['telefono'] ?? '';
      _emailController.text = t['email'] ?? '';
      _lugarController.text = t['lugar'] ?? '';
      _descripcionController.text = t['descripcion_servicio'] ?? '';
      _recibioController.text = t['recibio_nombre'] ?? '';

      if (t['fecha'] != null) {
        _fechaSeleccionada =
            DateTime.tryParse(t['fecha'].toString()) ?? DateTime.now();
      }

      if (t['hora_inicio'] != null && t['hora_inicio'].toString().isNotEmpty) {
        _horaInicio = _parseTimeOfDay(t['hora_inicio'].toString());
      }

      if (t['hora_fin'] != null && t['hora_fin'].toString().isNotEmpty) {
        _horaFin = _parseTimeOfDay(t['hora_fin'].toString());
      }
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final cleanStr = timeStr.trim().toUpperCase();
      bool isPm = cleanStr.contains('PM');
      bool isAm = cleanStr.contains('AM');

      String numbersOnly = cleanStr
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .trim();
      final parts = numbersOnly.split(':');
      if (parts.length < 2) return null;

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatFecha(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String? _calcularHorasTrabajadas() {
    if (_horaInicio == null || _horaFin == null) return null;

    final inicioMinutos = _horaInicio!.hour * 60 + _horaInicio!.minute;
    final finMinutos = _horaFin!.hour * 60 + _horaFin!.minute;

    int diferencia = finMinutos - inicioMinutos;
    if (diferencia < 0) diferencia += 24 * 60;

    final horas = diferencia ~/ 60;
    final minutos = diferencia % 60;

    if (minutos == 0) {
      return '$horas hr${horas != 1 ? 's' : ''}';
    }
    return '$horas hr${horas != 1 ? 's' : ''} $minutos min${minutos != 1 ? 's' : ''}';
  }

  @override
  void dispose() {
    _folioController.dispose();
    _clienteController.dispose();
    _solicitaController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _lugarController.dispose();
    _descripcionController.dispose();
    _recibioController.dispose();
    super.dispose();
  }

  Future<void> _guardarTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final String estadoCalculado = _horaFin != null
          ? 'completado'
          : 'realizando';

      // Únicamente enviamos las columnas existentes en Supabase
      final Map<String, dynamic> datosTicket = {
        'folio': int.tryParse(_folioController.text),
        'cliente': _clienteController.text,
        'solicita': _solicitaController.text,
        'telefono': _telefonoController.text,
        'email': _emailController.text,
        'lugar': _lugarController.text,
        'fecha': _formatFecha(_fechaSeleccionada),
        'hora_inicio': _horaInicio != null
            ? _formatTimeOfDay(_horaInicio!)
            : null,
        'hora_fin': _horaFin != null ? _formatTimeOfDay(_horaFin!) : null,
        'estado': estadoCalculado,
        'descripcion_servicio': _descripcionController.text,
        'recibio_nombre': _recibioController.text.isNotEmpty
            ? _recibioController.text
            : null,
      };

      late final String ticketId;
      if (widget.ticketParaEditar != null) {
        await _supabase
            .from('tickets')
            .update(datosTicket)
            .eq('id', widget.ticketParaEditar!['id']);
        ticketId = widget.ticketParaEditar!['id'].toString();
      } else {
        final ticketCreado = await _supabase
            .from('tickets')
            .insert(datosTicket)
            .select('id')
            .single();
        ticketId = ticketCreado['id'].toString();
      }

      final folio = int.parse(_folioController.text);
      final fechaProgramada = _horaInicio == null
          ? null
          : DateTime(
              _fechaSeleccionada.year,
              _fechaSeleccionada.month,
              _fechaSeleccionada.day,
              _horaInicio!.hour,
              _horaInicio!.minute,
            );

      String mensajeRecordatorio;
      try {
        final resultado = await TicketReminderService.schedule(
          ticketId: ticketId,
          folio: folio,
          fechaProgramada: fechaProgramada,
          completado: _horaFin != null,
        );
        mensajeRecordatorio = switch (resultado) {
          TicketReminderResult.scheduled =>
            ' Recordatorio programado una hora antes.',
          TicketReminderResult.notNeeded => ' No se programó recordatorio porque falta la hora o el ticket ya está completado.',
          TicketReminderResult.tooLate => ' No se programó recordatorio porque la hora ya pasó o falta menos de una hora.',
          TicketReminderResult.permissionDenied => ' No se programó el recordatorio porque las notificaciones están desactivadas.',
          TicketReminderResult.unsupported => ' Los recordatorios automáticos no están disponibles en esta plataforma.',
        };
      } catch (e) {
        mensajeRecordatorio = ' No se pudo programar el recordatorio: $e';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.ticketParaEditar != null ? 'Ticket actualizado correctamente.' : 'Ticket creado exitosamente.'}$mensajeRecordatorio',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.ticketParaEditar != null;
    final tiempoCalculado = _calcularHorasTrabajadas();

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Ticket' : 'Nuevo Ticket de Servicio'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DATOS DEL TICKET',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _folioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de Folio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Ingrese el número de folio';
                  if (int.tryParse(v) == null)
                    return 'Ingrese un número válido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  alignment: Alignment.centerLeft,
                ),
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'Fecha programada: ${_formatFecha(_fechaSeleccionada)}',
                ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _fechaSeleccionada,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _fechaSeleccionada = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'DATOS DEL CLIENTE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _clienteController,
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _solicitaController,
                      decoration: const InputDecoration(
                        labelText: 'Solicita',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lugarController,
                decoration: const InputDecoration(
                  labelText: 'Lugar / Dirección',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'HORARIO DEL SERVICIO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _horaInicio == null
                            ? 'Hora programada'
                            : 'Inicio: ${_formatTimeOfDay(_horaInicio!)}',
                      ),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _horaInicio ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() => _horaInicio = time);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_filled),
                      label: Text(
                        _horaFin == null
                            ? 'Hora Final'
                            : 'Fin: ${_formatTimeOfDay(_horaFin!)}',
                      ),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _horaFin ?? TimeOfDay.now(),
                        );
                        if (time != null) setState(() => _horaFin = time);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _horaFin != null
                    ? 'Los tickets completados no generan recordatorio.'
                    : _horaInicio == null
                    ? 'Selecciona una hora de inicio para recibir un recordatorio una hora antes.'
                    : 'Recibirás un recordatorio una hora antes del servicio programado.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: _horaFin != null
                      ? Colors.green.shade50
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _horaFin != null ? Colors.green : Colors.amber,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _horaFin != null
                          ? Icons.check_circle_outline
                          : Icons.pending_actions,
                      color: _horaFin != null
                          ? Colors.green.shade800
                          : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _horaFin != null
                            ? 'Estado: COMPLETADO | Tiempo total: ${tiempoCalculado ?? '0 hrs'}'
                            : 'Estado: REALIZANDO (Especifique Hora Final al concluir)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _horaFin != null
                              ? Colors.green.shade900
                              : Colors.amber.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'DESCRIPCIÓN DEL SERVICIO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Detalle del servicio a realizar...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Escriba el detalle del servicio'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'RECEPCIÓN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _recibioController,
                decoration: const InputDecoration(
                  labelText: 'Recibió el servicio (Nombre del cliente)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardarTicket,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving
                        ? 'Guardando...'
                        : (esEdicion ? 'Actualizar Ticket' : 'Guardar Ticket'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
