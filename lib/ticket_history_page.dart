import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ticket_form_page.dart';
import 'pdf_service.dart';
import 'services/excel_service.dart';

class TicketHistoryPage extends StatefulWidget {
  const TicketHistoryPage({super.key});

  @override
  State<TicketHistoryPage> createState() => _TicketHistoryPageState();
}

class _TicketHistoryPageState extends State<TicketHistoryPage> {
  final _supabase = Supabase.instance.client;

  // Controladores y estados para Búsqueda Avanzada
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _folioController = TextEditingController();

  String _searchQuery = '';
  String _filtroCliente = '';
  String _filtroFolio = '';
  String _filtroEstado = 'todos'; // 'todos', 'realizando', 'completado'

  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  bool _mostrarFiltrosAvanzados = false;

  // IDs seleccionados para acciones masivas
  final Set<String> _selectedTicketIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _clienteController.dispose();
    _folioController.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    setState(() {
      _searchController.clear();
      _clienteController.clear();
      _folioController.clear();
      _searchQuery = '';
      _filtroCliente = '';
      _filtroFolio = '';
      _filtroEstado = 'todos';
      _fechaDesde = null;
      _fechaHasta = null;
    });
  }

  String _formatFecha(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Método para enviar por WhatsApp
  Future<void> _enviarWhatsApp(Map<String, dynamic> ticket) async {
    final telefonoRaw = (ticket['telefono'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    
    if (telefonoRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El ticket no tiene teléfono registrado')),
      );
      return;
    }

    final String telefono = telefonoRaw.length == 10 ? '52$telefonoRaw' : telefonoRaw;

    final String mensaje = 
      '*HOJA DE SERVICIO - JCR*\n'
      '*Folio:* #${ticket['folio'] ?? ''}\n'
      '*Cliente:* ${ticket['cliente'] ?? ''}\n'
      '*Estado:* ${(ticket['estado'] ?? 'pendiente').toString().toUpperCase()}\n'
      '*Fecha:* ${ticket['fecha'] ?? ''}\n'
      '*Horario:* ${ticket['hora_inicio'] ?? ''} - ${ticket['hora_fin'] ?? 'En proceso'}\n\n'
      '*Descripción del Servicio:*\n${ticket['descripcion_servicio'] ?? ''}\n\n'
      'Atentamente,\nJOSE MARIA CANUL RAMOS';

    final Uri whatsappUri = Uri.parse('https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  // Método para enviar por Correo
  Future<void> _enviarCorreo(Map<String, dynamic> ticket) async {
    final email = ticket['email'] ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El ticket no tiene correo registrado')),
      );
      return;
    }

    final String subject = Uri.encodeComponent('Resumen Hoja de Servicio - Folio #${ticket['folio']}');
    final String body = Uri.encodeComponent(
      'Estimado/a ${ticket['recibio_nombre'] ?? ticket['cliente']},\n\n'
      'Adjuntamos la información de la Hoja de Servicio realizada.\n\n'
      'Cliente: ${ticket['cliente']}\n'
      'Estado: ${(ticket['estado'] ?? 'pendiente').toString().toUpperCase()}\n'
      'Fecha: ${ticket['fecha'] ?? ''}\n'
      'Horario: ${ticket['hora_inicio'] ?? ''} - ${ticket['hora_fin'] ?? 'En proceso'}\n\n'
      'Descripción del Servicio:\n${ticket['descripcion_servicio'] ?? ''}\n\n'
      'Atentamente,\nJOSE MARIA CANUL RAMOS\nAsesoría en Sistemas y TI',
    );

    final Uri mailUri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    if (await canLaunchUrl(mailUri)) {
      await launchUrl(mailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el cliente de correo')),
        );
      }
    }
  }

  // Eliminar seleccionados
  Future<void> _eliminarTicketsSeleccionados() async {
    if (_selectedTicketIds.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar los ${_selectedTicketIds.length} ticket(s) seleccionado(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final List<dynamic> idsParaEliminar = _selectedTicketIds.map((id) => int.tryParse(id) ?? id).toList();

        await _supabase
            .from('tickets')
            .delete()
            .inFilter('id', idsParaEliminar);

        setState(() {
          _selectedTicketIds.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket(s) eliminado(s) correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  // Descarga masiva en PDF
  Future<void> _descargarTicketsSeleccionados(List<Map<String, dynamic>> todosLosTickets) async {
    if (_selectedTicketIds.isEmpty) return;

    final seleccionados = todosLosTickets
        .where((t) => _selectedTicketIds.contains(t['id'].toString()))
        .toList();

    for (final ticket in seleccionados) {
      await PdfService.generarYDescargarPdf(ticket);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Descarga completada para ${seleccionados.length} ticket(s)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTicketIds.isNotEmpty
            ? '${_selectedTicketIds.length} seleccionado(s)'
            : 'Historial de Tickets'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedTicketIds.isNotEmpty) ...[
            // ACCIONES CUANDO HAY SELECCIÓN MÚLTIPLE
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'Descargar seleccionados en PDF',
              onPressed: () async {
                final snapshot = await _supabase.from('tickets').select();
                final list = List<Map<String, dynamic>>.from(snapshot);
                _descargarTicketsSeleccionados(list);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Eliminar seleccionados',
              onPressed: _eliminarTicketsSeleccionados,
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Deseleccionar todo',
              onPressed: () {
                setState(() {
                  _selectedTicketIds.clear();
                });
              },
            ),
          ] else ...[
            // ACCIONES GENERALES (EXPORTAR E IMPORTAR EXCEL)
            IconButton(
              icon: const Icon(Icons.file_upload, color: Colors.green),
              tooltip: 'Importar desde Excel',
              onPressed: () async {
                try {
                  final total = await ExcelService.importarDesdeExcel();
                  if (total > 0 && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Se importaron $total registro(s) exitosamente')),
                    );
                    setState(() {}); // Refrescar la lista automáticamente
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al importar: $e')),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_download, color: Colors.green),
              tooltip: 'Exportar a Excel',
              onPressed: () async {
                final snapshot = await _supabase
                    .from('tickets')
                    .select()
                    .order('created_at', ascending: false);
                final list = List<Map<String, dynamic>>.from(snapshot);
                if (list.isNotEmpty) {
                  await ExcelService.exportarAExcel(list);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No hay registros para exportar')),
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // PANEL DE BÚSQUEDA Y FILTROS
          Container(
            padding: const EdgeInsets.all(10.0),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Búsqueda General
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Búsqueda rápida...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón para desplegar Filtros Avanzados
                    IconButton.filledTonal(
                      icon: Icon(_mostrarFiltrosAvanzados ? Icons.filter_alt_off : Icons.filter_alt),
                      tooltip: 'Búsqueda Avanzada',
                      onPressed: () {
                        setState(() {
                          _mostrarFiltrosAvanzados = !_mostrarFiltrosAvanzados;
                        });
                      },
                    ),
                  ],
                ),
                
                // FILTROS AVANZADOS DESPLEGABLES
                if (_mostrarFiltrosAvanzados) ...[
                  const SizedBox(height: 10),
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FILTROS AVANZADOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Filtro Folio
                              Expanded(
                                child: TextField(
                                  controller: _folioController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => setState(() => _filtroFolio = v.trim()),
                                  decoration: const InputDecoration(
                                    labelText: 'Folio',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Filtro Cliente
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _clienteController,
                                  onChanged: (v) => setState(() => _filtroCliente = v.trim().toLowerCase()),
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre Cliente',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Rango de Fechas
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.date_range, size: 16),
                                  label: Text(_fechaDesde == null ? 'Desde: Todas' : _formatFecha(_fechaDesde!)),
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _fechaDesde ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (d != null) setState(() => _fechaDesde = d);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.date_range, size: 16),
                                  label: Text(_fechaHasta == null ? 'Hasta: Todas' : _formatFecha(_fechaHasta!)),
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _fechaHasta ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (d != null) setState(() => _fechaHasta = d);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Botón para limpiar todos los filtros
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: const Icon(Icons.restart_alt, size: 16),
                              label: const Text('Limpiar Filtros'),
                              onPressed: _limpiarFiltros,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Chips de Filtro por Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _filtroEstado == 'todos',
                      onSelected: (_) => setState(() => _filtroEstado = 'todos'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Realizando'),
                      selectedColor: Colors.amber.shade200,
                      selected: _filtroEstado == 'realizando',
                      onSelected: (_) => setState(() => _filtroEstado = 'realizando'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Completados'),
                      selectedColor: Colors.green.shade200,
                      selected: _filtroEstado == 'completado',
                      onSelected: (_) => setState(() => _filtroEstado = 'completado'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // LISTA FILTRADA DE TICKETS
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _supabase.from('tickets').select().order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar historial: ${snapshot.error}'));
                }

                final todosLosTickets = snapshot.data ?? [];

                // Aplicación de Búsqueda Rápida + Búsqueda Avanzada
                final ticketsFiltrados = todosLosTickets.where((ticket) {
                  final folio = (ticket['folio'] ?? '').toString().toLowerCase();
                  final cliente = (ticket['cliente'] ?? '').toString().toLowerCase();
                  final atendio = (ticket['recibio_nombre'] ?? '').toString().toLowerCase();
                  final estado = (ticket['estado'] ?? 'pendiente').toString().toLowerCase();
                  final fechaTicket = DateTime.tryParse(ticket['fecha']?.toString() ?? '');

                  // Búsqueda General por texto
                  final coincideTextoGeneral = _searchQuery.isEmpty ||
                      folio.contains(_searchQuery) ||
                      cliente.contains(_searchQuery) ||
                      atendio.contains(_searchQuery);

                  // Filtros Específicos (Avanzados)
                  final coincideFolio = _filtroFolio.isEmpty || folio == _filtroFolio;
                  final coincideCliente = _filtroCliente.isEmpty || cliente.contains(_filtroCliente);

                  // Filtro por Estado
                  bool coincideEstado = true;
                  if (_filtroEstado == 'realizando') {
                    coincideEstado = estado == 'realizando' || estado == 'pendiente';
                  } else if (_filtroEstado == 'completado') {
                    coincideEstado = estado == 'completado';
                  }

                  // Filtro por Fechas
                  bool coincideFecha = true;
                  if (fechaTicket != null) {
                    if (_fechaDesde != null && fechaTicket.isBefore(_fechaDesde!)) {
                      coincideFecha = false;
                    }
                    if (_fechaHasta != null && fechaTicket.isAfter(_fechaHasta!.add(const Duration(days: 1)))) {
                      coincideFecha = false;
                    }
                  }

                  return coincideTextoGeneral &&
                      coincideFolio &&
                      coincideCliente &&
                      coincideEstado &&
                      coincideFecha;
                }).toList();

                if (ticketsFiltrados.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron Hojas de Servicio con los filtros aplicados.'),
                  );
                }

                return ListView.builder(
                  itemCount: ticketsFiltrados.length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final ticket = ticketsFiltrados[index];
                    final String ticketId = ticket['id'].toString();
                    final bool isSelected = _selectedTicketIds.contains(ticketId);
                    final String estadoStr = (ticket['estado'] ?? 'pendiente').toString().toLowerCase();
                    final bool esCompletado = estadoStr == 'completado';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (bool? checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedTicketIds.add(ticketId);
                              } else {
                                _selectedTicketIds.remove(ticketId);
                              }
                            });
                          },
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ticket #${ticket['folio'] ?? 'Sin Folio'} - ${ticket['cliente'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: esCompletado ? Colors.green.shade100 : Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: esCompletado ? Colors.green : Colors.amber.shade800),
                              ),
                              child: Text(
                                esCompletado ? 'COMPLETADO' : 'REALIZANDO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: esCompletado ? Colors.green.shade900 : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Atendió: ${ticket['recibio_nombre'] ?? 'N/A'} | Fecha: ${ticket['fecha'] ?? ''}'),
                            Text('Horario: ${ticket['hora_inicio'] ?? '--:--'} - ${ticket['hora_fin'] ?? 'En proceso'}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              tooltip: 'Editar Ticket',
                              onPressed: () async {
                                final actualizado = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TicketFormPage(ticketParaEditar: ticket),
                                  ),
                                );
                                if (actualizado == true) {
                                  setState(() {});
                                }
                              },
                            ),
                           
                            IconButton(
                              icon: const Icon(Icons.email_outlined, color: Colors.blue),
                              tooltip: 'Enviar Correo',
                              onPressed: () => _enviarCorreo(ticket),
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              tooltip: 'Descargar PDF',
                              onPressed: () => PdfService.generarYDescargarPdf(ticket),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}