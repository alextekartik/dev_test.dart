library tekartik_dev_test.src.meta;

import 'package:test/test.dart' as _test;
import 'package:collection/equality.dart';

typedef _Body();

abstract class Callback {
  Group parent;
  _Body body;

  /// test group setUp or tearDown
  String get type {
    String type = runtimeType.toString();
    type = "${type[0].toLowerCase()}${type.substring(1)}";
    return type;
  }

  /// base implementation return the parent description
  List<String> get descriptions {
    if (parent != null) {
      return parent.descriptions;
    } else {
      return [];
    }
  }

  @override
  String toString() => '$type: $descriptions';

  @override
  int get hashCode => descriptions.length;

  // This is for testing mainly
  // 2 tests are the same if they have the same description
  @override
  bool operator ==(o) =>
      const ListEquality().equals(descriptions, o.descriptions);

  void declare();
}

class SetUp extends Callback {
  declare() {
    _test.setUp(body);
  }
}

class TearDown extends Callback {
  declare() {
    _test.tearDown(body);
  }
}

class SetUpAll extends Callback {
  declare() {
    _test.setUpAll(body);
  }
}

class TearDownAll extends Callback {
  declare() {
    _test.tearDownAll(body);
  }
}

abstract class Item extends Callback {
  String description;
  List<String> get descriptions {
    List<String> descriptions = super.descriptions;
    if (description != null) {
      descriptions..add(description);
    }
    return descriptions;
  }

  String testOn;
  _test.Timeout timeout;
  var _skip; // String or true if skipped
  set skip(skip) => _skip = skip;
  get skip {
    if (_skip == false || _skip == null) {
      if (devSkip) {
        _skip = true;
      }
    }
    return _skip;
  }

  Map<String, dynamic> onPlatform;

  bool devSkip;
  bool devSolo;

  @override
  String toString() {
    String text = super.toString();
    if (devSkip == true || devSolo == true) {
      text += " (${devSolo == true ? "solo" : "skip"})";
    }
    return text;
  }
}

class Group extends Item {
  Group();

  Iterable<Group> get groups =>
      _children.where((callback) => callback is Group);
  Iterable<Item> get items => _children.where((callback) => callback is Item);

  List<Callback> _children = [];
  List<Callback> get children => _children;

  // can be an item or not
  add(Callback callback) {
    _children.add(callback);
    callback.parent = this;
  }

  String get type => 'group';

  declare() {
    _test.group(description, body,
        testOn: testOn, timeout: timeout, skip: skip, onPlatform: onPlatform);
  }
}

class Root extends Group {
  @override
  String toString() => "$type: root";
}

///
/// The test definition
///
class Test extends Item {
  String get type => 'test';
  declare() {
    _test.test(description, body,
        testOn: testOn, timeout: timeout, skip: skip, onPlatform: onPlatform);
  }
}
