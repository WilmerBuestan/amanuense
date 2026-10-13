// Todas las notas: buscador, filtro por materia y tarjetas agrupadas.
import 'dart:io';

import 'package:flutter/material.dart';

import '../note_meta.dart';
import '../settings.dart';
import '../storage.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'note.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.settings});
  final Settings settings;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteMeta>? _all;
  String _query = '';
  String _materia = ''; // '' = todas
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final files = await Storage.listNotes(widget.settings);
    final metas = await NoteMeta.readAll(files);
    if (mounted) setState(() => _all = metas);
  }

  List<NoteMeta> get _filtered {
    final q = _query.toLowerCase().trim();
    return (_all ?? []).where((m) {
      if (_materia.isNotEmpty && m.materia != _materia) return false;
      if (q.isEmpty) return true;
      return m.titulo.toLowerCase().contains(q) || m.materia.toLowerCase().contains(q) || m.name.contains(q);
    }).toList();
  }

  Future<void> _open(File f) async {
    await Navigator.push(context, slideRoute(NoteScreen(file: f)));
  }

  @override
  Widget build(BuildContext context) {
    final materias = {...?_all?.map((m) => m.materia).where((m) => m.isNotEmpty)}.toList()..sort();
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _searching
              ? TextField(
                  key: const ValueKey('search'),
                  controller: _search,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por título o materia',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                )
              : const Text('Notas', key: ValueKey('title')),
        ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => RotationTransition(turns: Tween(begin: .5, end: 1.0).animate(a), child: c),
              child: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, key: ValueKey(_searching)),
            ),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _query = '';
              }
            }),
          ),
        ],
      ),
      body: _all == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                if (materias.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          for (final m in ['', ...materias])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(m.isEmpty ? 'Todas (${_all!.length})' : m),
                                selected: _materia == m,
                                onSelected: (_) => setState(() => _materia = m),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: _query.isEmpty ? Icons.mic_none_rounded : Icons.search_off_rounded,
                      title: _query.isEmpty ? 'Todavía no hay notas' : 'Nada coincide con “$_query”',
                      text: _query.isEmpty ? 'Graba tu primera clase y aparecerá aquí.' : '',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => FadeSlideIn(
                        delay: i,
                        child: NoteCard(meta: list[i], onTap: () => _open(list[i].file)),
                      ),
                    ),
                  ),
              ]),
            ),
    );
  }
}
