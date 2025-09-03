class ProductModel {
  ProductModel({
    num? id,
    String? barcode,
    String? name,
    num? categoryId,
    num? vatable,
    num? taxId,
    num? markup,
    num? cost,
    num? prevCost,
    num? price,
    num? prevPrice,
    num? senior,
    num? pwd,
    num? status,
    num? userId,
    String? createdAt,
    String? updatedAt,
    num? supplierId,
    num? discountable,
    num? type,
    dynamic image,
    num? creditableToPoints,
    num? soloParent,
    num? naac,
    Category? category,
    Supplier? supplier,
    List<ItemUnits>? itemUnits,
    List<ItemStores>? itemStores,
  }) {
    _id = id;
    _barcode = barcode;
    _name = name;
    _categoryId = categoryId;
    _vatable = vatable;
    _taxId = taxId;
    _markup = markup;
    _cost = cost;
    _prevCost = prevCost;
    _price = price;
    _prevPrice = prevPrice;
    _senior = senior;
    _pwd = pwd;
    _status = status;
    _userId = userId;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _supplierId = supplierId;
    _discountable = discountable;
    _type = type;
    _image = image;
    _creditableToPoints = creditableToPoints;
    _soloParent = soloParent;
    _naac = naac;
    _category = category;
    _supplier = supplier;
    _itemUnits = itemUnits;
    _itemStores = itemStores;
  }

  ProductModel.fromJson(dynamic json) {
    _id = json['id'];
    _barcode = json['barcode'];
    _name = json['name'];
    _categoryId = json['category_id'];
    _vatable = json['vatable'];
    _taxId = json['tax_id'];
    _markup = json['markup'];
    _cost = json['cost'];
    _prevCost = json['prev_cost'];
    _price = json['price'];
    _prevPrice = json['prev_price'];
    _senior = json['senior'];
    _pwd = json['pwd'];
    _status = json['status'];
    _userId = json['user_id'];
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _supplierId = json['supplier_id'];
    _discountable = json['discountable'];
    _type = json['type'];
    _image = json['image'];
    _creditableToPoints = json['creditable_to_points'];
    _soloParent = json['solo_parent'];
    _naac = json['naac'];
    _category =
        json['category'] != null ? Category.fromJson(json['category']) : null;
    _supplier =
        json['supplier'] != null ? Supplier.fromJson(json['supplier']) : null;
    if (json['item_units'] != null) {
      _itemUnits = [];
      json['item_units'].forEach((v) {
        _itemUnits?.add(ItemUnits.fromJson(v));
      });
    }
    if (json['item_stores'] != null) {
      _itemStores = [];
      json['item_stores'].forEach((v) {
        _itemStores?.add(ItemStores.fromJson(v));
      });
    }
  }
  num? _id;
  String? _barcode;
  String? _name;
  num? _categoryId;
  num? _vatable;
  num? _taxId;
  num? _markup;
  num? _cost;
  num? _prevCost;
  num? _price;
  num? _prevPrice;
  num? _senior;
  num? _pwd;
  num? _status;
  num? _userId;
  String? _createdAt;
  String? _updatedAt;
  num? _supplierId;
  num? _discountable;
  num? _type;
  dynamic _image;
  num? _creditableToPoints;
  num? _soloParent;
  num? _naac;
  Category? _category;
  Supplier? _supplier;
  List<ItemUnits>? _itemUnits;
  List<ItemStores>? _itemStores;
  ProductModel copyWith({
    num? id,
    String? barcode,
    String? name,
    num? categoryId,
    num? vatable,
    num? taxId,
    num? markup,
    num? cost,
    num? prevCost,
    num? price,
    num? prevPrice,
    num? senior,
    num? pwd,
    num? status,
    num? userId,
    String? createdAt,
    String? updatedAt,
    num? supplierId,
    num? discountable,
    num? type,
    dynamic image,
    num? creditableToPoints,
    num? soloParent,
    num? naac,
    Category? category,
    Supplier? supplier,
    List<ItemUnits>? itemUnits,
    List<ItemStores>? itemStores,
  }) =>
      ProductModel(
        id: id ?? _id,
        barcode: barcode ?? _barcode,
        name: name ?? _name,
        categoryId: categoryId ?? _categoryId,
        vatable: vatable ?? _vatable,
        taxId: taxId ?? _taxId,
        markup: markup ?? _markup,
        cost: cost ?? _cost,
        prevCost: prevCost ?? _prevCost,
        price: price ?? _price,
        prevPrice: prevPrice ?? _prevPrice,
        senior: senior ?? _senior,
        pwd: pwd ?? _pwd,
        status: status ?? _status,
        userId: userId ?? _userId,
        createdAt: createdAt ?? _createdAt,
        updatedAt: updatedAt ?? _updatedAt,
        supplierId: supplierId ?? _supplierId,
        discountable: discountable ?? _discountable,
        type: type ?? _type,
        image: image ?? _image,
        creditableToPoints: creditableToPoints ?? _creditableToPoints,
        soloParent: soloParent ?? _soloParent,
        naac: naac ?? _naac,
        category: category ?? _category,
        supplier: supplier ?? _supplier,
        itemUnits: itemUnits ?? _itemUnits,
        itemStores: itemStores ?? _itemStores,
      );
  num? get id => _id;
  String? get barcode => _barcode;
  String? get name => _name;
  num? get categoryId => _categoryId;
  num? get vatable => _vatable;
  num? get taxId => _taxId;
  num? get markup => _markup;
  num? get cost => _cost;
  num? get prevCost => _prevCost;
  num? get price => _price;
  num? get prevPrice => _prevPrice;
  num? get senior => _senior;
  num? get pwd => _pwd;
  num? get status => _status;
  num? get userId => _userId;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  num? get supplierId => _supplierId;
  num? get discountable => _discountable;
  num? get type => _type;
  dynamic get image => _image;
  num? get creditableToPoints => _creditableToPoints;
  num? get soloParent => _soloParent;
  num? get naac => _naac;
  Category? get category => _category;
  Supplier? get supplier => _supplier;
  List<ItemUnits>? get itemUnits => _itemUnits;
  List<ItemStores>? get itemStores => _itemStores;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['barcode'] = _barcode;
    map['name'] = _name;
    map['category_id'] = _categoryId;
    map['vatable'] = _vatable;
    map['tax_id'] = _taxId;
    map['markup'] = _markup;
    map['cost'] = _cost;
    map['prev_cost'] = _prevCost;
    map['price'] = _price;
    map['prev_price'] = _prevPrice;
    map['senior'] = _senior;
    map['pwd'] = _pwd;
    map['status'] = _status;
    map['user_id'] = _userId;
    map['created_at'] = _createdAt;
    map['updated_at'] = _updatedAt;
    map['supplier_id'] = _supplierId;
    map['discountable'] = _discountable;
    map['type'] = _type;
    map['image'] = _image;
    map['creditable_to_points'] = _creditableToPoints;
    map['solo_parent'] = _soloParent;
    map['naac'] = _naac;
    if (_category != null) {
      map['category'] = _category?.toJson();
    }
    if (_supplier != null) {
      map['supplier'] = _supplier?.toJson();
    }
    if (_itemUnits != null) {
      map['item_units'] = _itemUnits?.map((v) => v.toJson()).toList();
    }
    if (_itemStores != null) {
      map['item_stores'] = _itemStores?.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

class ItemStores {
  ItemStores({
    num? id,
    num? stock,
    num? status,
    num? storeId,
    num? itemId,
    String? createdAt,
    String? updatedAt,
    Store? store,
  }) {
    _id = id;
    _stock = stock;
    _status = status;
    _storeId = storeId;
    _itemId = itemId;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _store = store;
  }

  ItemStores.fromJson(dynamic json) {
    _id = json['id'];
    _stock = json['stock'];
    _status = json['status'];
    _storeId = json['store_id'];
    _itemId = json['item_id'];
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _store = json['store'] != null ? Store.fromJson(json['store']) : null;
  }
  num? _id;
  num? _stock;
  num? _status;
  num? _storeId;
  num? _itemId;
  String? _createdAt;
  String? _updatedAt;
  Store? _store;
  ItemStores copyWith({
    num? id,
    num? stock,
    num? status,
    num? storeId,
    num? itemId,
    String? createdAt,
    String? updatedAt,
    Store? store,
  }) =>
      ItemStores(
        id: id ?? _id,
        stock: stock ?? _stock,
        status: status ?? _status,
        storeId: storeId ?? _storeId,
        itemId: itemId ?? _itemId,
        createdAt: createdAt ?? _createdAt,
        updatedAt: updatedAt ?? _updatedAt,
        store: store ?? _store,
      );
  num? get id => _id;
  num? get stock => _stock;
  num? get status => _status;
  num? get storeId => _storeId;
  num? get itemId => _itemId;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  Store? get store => _store;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['stock'] = _stock;
    map['status'] = _status;
    map['store_id'] = _storeId;
    map['item_id'] = _itemId;
    map['created_at'] = _createdAt;
    map['updated_at'] = _updatedAt;
    if (_store != null) {
      map['store'] = _store?.toJson();
    }
    return map;
  }
}

class Store {
  Store({
    num? id,
    String? name,
  }) {
    _id = id;
    _name = name;
  }

  Store.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
  }
  num? _id;
  String? _name;
  Store copyWith({
    num? id,
    String? name,
  }) =>
      Store(
        id: id ?? _id,
        name: name ?? _name,
      );
  num? get id => _id;
  String? get name => _name;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    return map;
  }
}

class ItemUnits {
  ItemUnits({
    num? id,
    num? qty,
    num? price,
    dynamic barcode,
    num? itemId,
    num? unitId,
    num? status,
    String? createdAt,
    String? updatedAt,
    Unit? unit,
  }) {
    _id = id;
    _qty = qty;
    _price = price;
    _barcode = barcode;
    _itemId = itemId;
    _unitId = unitId;
    _status = status;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _unit = unit;
  }

  ItemUnits.fromJson(dynamic json) {
    _id = json['id'];
    _qty = json['qty'];
    _price = json['price'];
    _barcode = json['barcode'];
    _itemId = json['item_id'];
    _unitId = json['unit_id'];
    _status = json['status'];
    _createdAt = json['created_at'];
    _updatedAt = json['updated_at'];
    _unit = json['unit'] != null ? Unit.fromJson(json['unit']) : null;
  }
  num? _id;
  num? _qty;
  num? _price;
  dynamic _barcode;
  num? _itemId;
  num? _unitId;
  num? _status;
  String? _createdAt;
  String? _updatedAt;
  Unit? _unit;
  ItemUnits copyWith({
    num? id,
    num? qty,
    num? price,
    dynamic barcode,
    num? itemId,
    num? unitId,
    num? status,
    String? createdAt,
    String? updatedAt,
    Unit? unit,
  }) =>
      ItemUnits(
        id: id ?? _id,
        qty: qty ?? _qty,
        price: price ?? _price,
        barcode: barcode ?? _barcode,
        itemId: itemId ?? _itemId,
        unitId: unitId ?? _unitId,
        status: status ?? _status,
        createdAt: createdAt ?? _createdAt,
        updatedAt: updatedAt ?? _updatedAt,
        unit: unit ?? _unit,
      );
  num? get id => _id;
  num? get qty => _qty;
  num? get price => _price;
  dynamic get barcode => _barcode;
  num? get itemId => _itemId;
  num? get unitId => _unitId;
  num? get status => _status;
  String? get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  Unit? get unit => _unit;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['qty'] = _qty;
    map['price'] = _price;
    map['barcode'] = _barcode;
    map['item_id'] = _itemId;
    map['unit_id'] = _unitId;
    map['status'] = _status;
    map['created_at'] = _createdAt;
    map['updated_at'] = _updatedAt;
    if (_unit != null) {
      map['unit'] = _unit?.toJson();
    }
    return map;
  }
}

class Unit {
  Unit({
    num? id,
    String? name,
  }) {
    _id = id;
    _name = name;
  }

  Unit.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
  }
  num? _id;
  String? _name;
  Unit copyWith({
    num? id,
    String? name,
  }) =>
      Unit(
        id: id ?? _id,
        name: name ?? _name,
      );
  num? get id => _id;
  String? get name => _name;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    return map;
  }
}

/// id : 2
/// name : "TSK RICE TRADING"

class Supplier {
  Supplier({
    num? id,
    String? name,
  }) {
    _id = id;
    _name = name;
  }

  Supplier.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
  }
  num? _id;
  String? _name;
  Supplier copyWith({
    num? id,
    String? name,
  }) =>
      Supplier(
        id: id ?? _id,
        name: name ?? _name,
      );
  num? get id => _id;
  String? get name => _name;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    return map;
  }
}

class Category {
  Category({
    num? id,
    String? name,
  }) {
    _id = id;
    _name = name;
  }

  Category.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
  }
  num? _id;
  String? _name;
  Category copyWith({
    num? id,
    String? name,
  }) =>
      Category(
        id: id ?? _id,
        name: name ?? _name,
      );
  num? get id => _id;
  String? get name => _name;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    return map;
  }
}
