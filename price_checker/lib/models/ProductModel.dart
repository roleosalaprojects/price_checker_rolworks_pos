/// id : 1433
/// barcode : ""
/// name : "WINSTON RED"
/// category_id : 0
/// vatable : 1
/// tax_id : 1
/// markup : 5
/// cost : 122.5
/// prev_cost : 0
/// price : 144
/// prev_price : 0
/// senior : 20
/// pwd : 20
/// status : 1
/// user_id : 1
/// created_at : null
/// updated_at : "2023-11-12T14:27:54.000000Z"
/// supplier_id : 41
/// discountable : 0
/// type : 0

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
    dynamic createdAt,
    String? updatedAt,
    num? supplierId,
    num? discountable,
    num? type,
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
  dynamic _createdAt;
  String? _updatedAt;
  num? _supplierId;
  num? _discountable;
  num? _type;
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
    dynamic createdAt,
    String? updatedAt,
    num? supplierId,
    num? discountable,
    num? type,
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
  dynamic get createdAt => _createdAt;
  String? get updatedAt => _updatedAt;
  num? get supplierId => _supplierId;
  num? get discountable => _discountable;
  num? get type => _type;

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
    return map;
  }
}
