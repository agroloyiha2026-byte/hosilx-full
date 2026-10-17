import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../market/market_providers.dart';
import 'product_providers.dart';
import 'product_repository.dart';

/// Yangi e'lon (id == null) yoki o'zining e'lonini tahrirlash. Xavfsizlik: RLS faqat egasiga ruxsat beradi;
/// moderatsiya maydonlarini sotuvchi o'zgartira olmaydi (server triggeri).
class ProductFormScreen extends ConsumerStatefulWidget {
  final String? id;
  const ProductFormScreen({super.key, this.id});
  @override
  ConsumerState<ProductFormScreen> createState() => _S();
}

class _S extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _type = TextEditingController(), _price = TextEditingController();
  final _qty = TextEditingController(), _region = TextEditingController(), _desc = TextEditingController();
  String? _category;
  String _currency = 'UZS', _unit = 'kg';
  String? _currentMain;
  List<XFile> _images = [];
  bool _busy = false, _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await ref.read(marketRepositoryProvider).product(widget.id!);
      if (p != null && mounted) {
        _title.text = p.title; _type.text = p.productType; _price.text = p.price.toString(); _qty.text = p.quantity.toString();
        _region.text = p.region; _desc.text = p.description ?? '';
        _category = p.category; _currency = p.currency; _unit = p.unit; _currentMain = p.imageUrl;
      }
    } catch (e) {
      if (mounted) _err = errText(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _type, _price, _qty, _region, _desc]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
    final ok = <XFile>[];
    for (final f in picked.take(5)) {
      if (imageContentType(f.name) != null && await f.length() <= maxImageBytes) ok.add(f);
    }
    if (mounted) setState(() { _images = ok; if (picked.isNotEmpty && ok.length < picked.take(5).length) _err = context.tr('bad_image'); });
  }

  double _n(String s) => double.parse(s.replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _submit() async {
    final uid = ref.read(sessionProvider).user?.id;
    if (uid == null || _category == null || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try {
      final repo = ref.read(productRepoProvider);
      final urls = <String>[for (final f in _images) await repo.uploadImage(f, uid)];
      final data = {
        'title': _title.text.trim(), 'category': _category, 'product_type': _type.text.trim().toLowerCase(),
        'price': _n(_price.text), 'currency': _currency, 'unit': _unit, 'quantity': _n(_qty.text),
        'region': _region.text.trim(), 'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      };
      final String pid;
      if (widget.id == null) {
        pid = await repo.create({...data, 'seller_id': uid});
      } else {
        pid = widget.id!;
        await repo.update(pid, data);
      }
      await repo.attachImages(pid, urls, setMain: _currentMain == null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('saved_ok'))));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _err = errText(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
    if (_category == null && cats.isNotEmpty) _category = cats.first.slug;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(widget.id == null ? 'add_product' : 'edit_product'))),
      body: _loading
          ? const LoadingView()
          : ListView(padding: const EdgeInsets.all(16), children: [
              Form(
                key: _form,
                child: Column(children: [
                  AppTextField(controller: _title, label: context.tr('f_title'), validator: tv(context, Validators.required)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: cats.any((c) => c.slug == _category) ? _category : null,
                    decoration: InputDecoration(labelText: context.tr('f_category'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    items: [for (final c in cats) DropdownMenuItem(value: c.slug, child: Text('${c.icon ?? ''} ${c.name(lang)}'.trim()))],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(controller: _type, label: context.tr('f_type'), validator: tv(context, Validators.required)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(flex: 3, child: AppTextField(controller: _price, label: context.tr('f_price'), keyboardType: TextInputType.number, validator: tv(context, Validators.positive))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: DropdownButtonFormField<String>(value: _currency, items: const [DropdownMenuItem(value: 'UZS', child: Text('UZS')), DropdownMenuItem(value: 'USD', child: Text('USD'))], onChanged: (v) => setState(() => _currency = v ?? 'UZS'))),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(flex: 3, child: AppTextField(controller: _qty, label: context.tr('f_quantity'), keyboardType: TextInputType.number, validator: tv(context, Validators.positive))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: DropdownButtonFormField<String>(value: _unit, items: [for (final u in const ['kg', 'tonna', 'dona', 'litr']) DropdownMenuItem(value: u, child: Text(u))], onChanged: (v) => setState(() => _unit = v ?? 'kg'))),
                  ]),
                  const SizedBox(height: 14),
                  AppTextField(controller: _region, label: context.tr('f_region'), validator: tv(context, Validators.required)),
                  const SizedBox(height: 14),
                  AppTextField(controller: _desc, label: context.tr('f_description'), maxLines: 3),
                ]),
              ),
              const SizedBox(height: 14),
              AppButton(label: _images.isEmpty ? context.tr('pick_images') : '${_images.length} ${context.tr('images_chosen')}', outlined: true, icon: Icons.photo_library_outlined, onPressed: _pick),
              const SizedBox(height: 16),
              ErrorText(_err),
              AppButton(label: context.tr('save'), onPressed: _submit, loading: _busy),
            ]),
    );
  }
}
