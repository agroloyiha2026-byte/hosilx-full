import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

const _L = {
  'uz': {'add_product': 'Mahsulot qo‘shish', 'title': 'Nomi', 'type': 'Mahsulot turi', 'price': 'Narxi (so‘m)', 'qty': 'Miqdori', 'region': 'Hudud',
    'save': 'Saqlash', 'offer': 'Taklif narxi', 'msg': 'Xabar', 'add_task': 'Vazifa qo‘shish', 'pick': 'Sana va vaqtni tanlang', 'ok': 'Saqlandi',
    'sent': 'Yuborildi', 'bad': 'Maydonlarni to‘g‘ri to‘ldiring', 'inq': 'Sotuvchiga so‘rov', 'photo': 'Rasm tanlash', 'req': 'Saqlash so‘rovi', 'tons': 'Tonna'},
  'ru': {'add_product': 'Добавить продукт', 'title': 'Название', 'type': 'Тип продукта', 'price': 'Цена (сум)', 'qty': 'Количество', 'region': 'Регион',
    'save': 'Сохранить', 'offer': 'Предложенная цена', 'msg': 'Сообщение', 'add_task': 'Добавить задачу', 'pick': 'Выберите дату и время', 'ok': 'Сохранено',
    'sent': 'Отправлено', 'bad': 'Заполните поля корректно', 'inq': 'Запрос продавцу', 'photo': 'Выбрать фото', 'req': 'Запрос на хранение', 'tons': 'Тонн'},
  'en': {'add_product': 'Add product', 'title': 'Title', 'type': 'Product type', 'price': 'Price (UZS)', 'qty': 'Quantity', 'region': 'Region',
    'save': 'Save', 'offer': 'Offered price', 'msg': 'Message', 'add_task': 'Add task', 'pick': 'Pick date & time', 'ok': 'Saved',
    'sent': 'Sent', 'bad': 'Fill in the fields correctly', 'inq': 'Inquiry to seller', 'photo': 'Choose photo', 'req': 'Storage request', 'tons': 'Tons'},
};
String _t(String k) => _L[lang.value]![k] ?? k;

Future<void> _sheet(BuildContext c, String title, List<Widget> Function(StateSetter) body, Future<String?> Function() onSave) {
  return showModalBottomSheet(context: c, isScrollControlled: true, builder: (ctx) {
    String? err; bool busy = false;
    return StatefulBuilder(builder: (ctx, set) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 12),
        ...body(set).expand((w) => [w, const SizedBox(height: 10)]),
        if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
        FilledButton(onPressed: busy ? null : () async {
          set(() { busy = true; err = null; });
          final e = await onSave();
          if (e == null) { if (ctx.mounted) Navigator.pop(ctx); if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_t('ok')))); }
          else { set(() { busy = false; err = e; }); }
        }, child: Text(_t('save')))]))));
  });
}

InputDecoration _d(String k) => InputDecoration(labelText: _t(k));

Future<void> showAddProduct(BuildContext c) {
  final title = TextEditingController(), type = TextEditingController(), price = TextEditingController(), qty = TextEditingController(), region = TextEditingController();
  String cat = 'vegetable'; Uint8List? bytes;
  return _sheet(c, _t('add_product'), (set) => [
    TextField(controller: title, decoration: _d('title')), TextField(controller: type, decoration: _d('type')),
    DropdownButtonFormField<String>(value: cat, items: const ['fruit', 'vegetable', 'grain', 'dairy', 'other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => cat = v!),
    TextField(controller: price, keyboardType: TextInputType.number, decoration: _d('price')),
    TextField(controller: qty, keyboardType: TextInputType.number, decoration: _d('qty')), TextField(controller: region, decoration: _d('region')),
    OutlinedButton.icon(icon: const Icon(Icons.photo_outlined), label: Text(bytes == null ? _t('photo') : '✓ ${_t('photo')}'), onPressed: () async {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (x == null) return; final b = await x.readAsBytes();
      if (b.length <= 5 * 1024 * 1024) set(() => bytes = b);
    })],
  () async {
    final p = double.tryParse(price.text.replaceAll(' ', '')), q = double.tryParse(qty.text.replaceAll(' ', ''));
    if (title.text.trim().isEmpty || type.text.trim().isEmpty || region.text.trim().isEmpty || p == null || p <= 0 || q == null || q < 0) return _t('bad');
    try {
      String? url;
      if (bytes != null) {
        final path = '${sb().auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
        await sb().storage.from('images').uploadBinary(path, bytes!, fileOptions: const FileOptions(contentType: 'image/jpeg'));
        url = sb().storage.from('images').getPublicUrl(path);
      }
      await sb().from('products').insert({'image_url': url, 'seller_id': sb().auth.currentUser!.id, 'title': title.text.trim(), 'category': cat, 'product_type': type.text.trim().toLowerCase(),
        'price': p, 'currency': 'UZS', 'unit': 'kg', 'quantity': q, 'region': region.text.trim()});
      return null;
    } catch (_) { return t('error'); }
  });
}

Future<void> showAddTask(BuildContext c) {
  final title = TextEditingController(); DateTime? due;
  return _sheet(c, _t('add_task'), (set) => [
    TextField(controller: title, decoration: _d('title')),
    OutlinedButton(onPressed: () async {
      final d = await showDatePicker(context: c, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
      if (d == null || !c.mounted) return;
      final tm = await showTimePicker(context: c, initialTime: TimeOfDay.now());
      if (tm != null) set(() => due = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
    }, child: Text(due == null ? _t('pick') : due.toString().substring(0, 16)))],
  () async {
    if (title.text.trim().isEmpty || due == null) return _t('bad');
    try {
      await sb().from('tasks').insert({'user_id': sb().auth.currentUser!.id, 'title': title.text.trim(), 'due_at': due!.toUtc().toIso8601String()});
      return null;
    } catch (_) { return t('error'); }
  });
}

Future<void> showInquiry(BuildContext c, String productId) {
  final offer = TextEditingController(), msg = TextEditingController();
  return _sheet(c, _t('inq'), (set) => [
    TextField(controller: offer, keyboardType: TextInputType.number, decoration: _d('offer')), TextField(controller: msg, decoration: _d('msg'))],
  () async {
    final o = offer.text.trim().isEmpty ? null : double.tryParse(offer.text);
    if (offer.text.trim().isNotEmpty && (o == null || o <= 0)) return _t('bad');
    try {
      await sb().from('inquiries').insert({'product_id': productId, 'buyer_id': sb().auth.currentUser!.id, 'offered_price': o, 'message': msg.text.trim().isEmpty ? null : msg.text.trim()});
      return null;
    } catch (_) { return t('error'); }
  });
}

Future<void> showStorageRequest(BuildContext c, String warehouseId) {
  final type = TextEditingController(), tons = TextEditingController(), msg = TextEditingController();
  return _sheet(c, _t('req'), (set) => [
    TextField(controller: type, decoration: _d('type')),
    TextField(controller: tons, keyboardType: TextInputType.number, decoration: _d('tons')), TextField(controller: msg, decoration: _d('msg'))],
  () async {
    final q = double.tryParse(tons.text.replaceAll(' ', ''));
    if (type.text.trim().isEmpty || q == null || q <= 0) return _t('bad');
    try {
      await sb().from('storage_requests').insert({'warehouse_id': warehouseId, 'farmer_id': sb().auth.currentUser!.id, 'product_type': type.text.trim().toLowerCase(),
        'quantity_tons': q, 'message': msg.text.trim().isEmpty ? null : msg.text.trim()});
      return null;
    } catch (_) { return t('error'); }
  });
}
