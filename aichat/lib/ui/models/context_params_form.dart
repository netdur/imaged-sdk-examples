import 'package:flutter/material.dart';

import '../../data/models/model_bundle.dart';

class ContextParamsValue {
  ContextParamsValue({
    required this.nCtx,
    required this.nBatch,
    required this.nUbatch,
    required this.flashAttn,
  });

  factory ContextParamsValue.defaults() => ContextParamsValue(
        nCtx: 2048,
        nBatch: 512,
        nUbatch: 512,
        flashAttn: FlashAttnMode.auto,
      );

  factory ContextParamsValue.fromBundle(ModelBundle m) => ContextParamsValue(
        nCtx: m.nCtx,
        nBatch: m.nBatch,
        nUbatch: m.nUbatch,
        flashAttn: m.flashAttn,
      );

  final int nCtx;
  final int nBatch;
  final int nUbatch;
  final FlashAttnMode flashAttn;

  ContextParamsValue copyWith({
    int? nCtx,
    int? nBatch,
    int? nUbatch,
    FlashAttnMode? flashAttn,
  }) =>
      ContextParamsValue(
        nCtx: nCtx ?? this.nCtx,
        nBatch: nBatch ?? this.nBatch,
        nUbatch: nUbatch ?? this.nUbatch,
        flashAttn: flashAttn ?? this.flashAttn,
      );
}

/// Reusable form for the engine-spawn-time context params on a model.
class ContextParamsForm extends StatefulWidget {
  const ContextParamsForm({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ContextParamsValue value;
  final void Function(ContextParamsValue) onChanged;

  @override
  State<ContextParamsForm> createState() => _ContextParamsFormState();
}

class _ContextParamsFormState extends State<ContextParamsForm> {
  late final TextEditingController _nCtx;
  late final TextEditingController _nBatch;
  late final TextEditingController _nUbatch;

  @override
  void initState() {
    super.initState();
    _nCtx = TextEditingController(text: widget.value.nCtx.toString());
    _nBatch = TextEditingController(text: widget.value.nBatch.toString());
    _nUbatch = TextEditingController(text: widget.value.nUbatch.toString());
  }

  @override
  void didUpdateWidget(covariant ContextParamsForm old) {
    super.didUpdateWidget(old);
    if (old.value.nCtx != widget.value.nCtx) {
      _nCtx.text = widget.value.nCtx.toString();
    }
    if (old.value.nBatch != widget.value.nBatch) {
      _nBatch.text = widget.value.nBatch.toString();
    }
    if (old.value.nUbatch != widget.value.nUbatch) {
      _nUbatch.text = widget.value.nUbatch.toString();
    }
  }

  @override
  void dispose() {
    _nCtx.dispose();
    _nBatch.dispose();
    _nUbatch.dispose();
    super.dispose();
  }

  void _emit({int? nCtx, int? nBatch, int? nUbatch, FlashAttnMode? flash}) {
    widget.onChanged(widget.value.copyWith(
      nCtx: nCtx,
      nBatch: nBatch,
      nUbatch: nUbatch,
      flashAttn: flash,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nCtx,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'nCtx (context window)',
                  helperText: 'Total tokens of context. Higher = more memory.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n > 0) _emit(nCtx: n);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nBatch,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'nBatch',
                  helperText: 'Logical prefill batch size.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n > 0) _emit(nBatch: n);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _nUbatch,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'nUbatch',
                  helperText: 'Physical (per-decode) batch.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n > 0) _emit(nUbatch: n);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<FlashAttnMode>(
          initialValue: widget.value.flashAttn,
          decoration: const InputDecoration(
            labelText: 'FlashAttention',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: FlashAttnMode.auto, child: Text('auto')),
            DropdownMenuItem(value: FlashAttnMode.on, child: Text('on')),
            DropdownMenuItem(value: FlashAttnMode.off, child: Text('off')),
          ],
          onChanged: (v) {
            if (v != null) _emit(flash: v);
          },
        ),
      ],
    );
  }
}
