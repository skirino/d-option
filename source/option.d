/*
 * The MIT License
 *
 * Copyright (c) 2014 Shunsuke Kirino
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

module option;

import std.algorithm;
import std.conv;
import std.traits;
import std.range;
import std.exception;

template isOptionType(T) {
  static if(is(T U == Option!U))
    enum bool isOptionType = true;
  else
    enum bool isOptionType = false;
}

private template isNullableType(T) {
  enum isNullableType = is(T == class) || is(T == interface) || isPointer!T;
}

struct Option(T)
{
private:
  T _Option_value;// Avoid name conflict by prefixing

public:
  alias T OptionValueType;

  // constructor
  static if(isNullableType!T) {
  public:
    this(U: T)(inout(U) u) inout { _Option_value = u; }
  } else {
  private:
    this(U: T)(inout(U) u, bool b) inout { _Option_value = u; _isDefined = b; }
  public:
    this(U: T)(inout(U) u) inout { _Option_value = u; _isDefined = true; }
  }

  // isDefined
  static if(isNullableType!T) {
  public:
    @property pure nothrow bool isDefined() const { return _Option_value !is null; }
  } else {
  private:
    bool _isDefined;
  public:
    @property pure nothrow bool isDefined() const { return _isDefined; }
  }
  @property pure nothrow bool isEmpty() const { return !isDefined(); }

  @property pure ref inout(T) get() inout {
    enforce(isDefined, "No such element: None!(" ~ T.stringof ~ ").get");
    return _Option_value;
  }
  pure nothrow inout(T) getOrElse(U: T)(inout(U) other) inout {
    return isDefined ? _Option_value : other;
  }
  pure nothrow inout(Option!T) orElse(inout(Option!T) other) inout {
    return isDefined ? this : other;
  }

  pure nothrow inout(T)[] array() inout {
    return isDefined ? [_Option_value] : [];
  }
  static pure Option!T fromRange(R)(R r) if(isInputRange!R && is(ElementType!(R): T)) {
    return r.empty ? None!T() : Some!T(r.front);
  }

  string toString() const {
    if(isDefined)
      return "Some!(" ~ T.stringof ~ ")(" ~ to!string(_Option_value) ~ ')';
    else
      return "None!(" ~ T.stringof ~ ")()";
  }

  auto opDispatch(string fn, Args...)(lazy Args args) {
    static if(args.length == 0) {
      alias F = typeof(mixin("_Option_value." ~ fn));
      static if(isCallable!F)
        enum MethodCall = "_Option_value." ~ fn ~ "()";
      else // property access
        enum MethodCall = "_Option_value." ~ fn;
    } else {
      enum MethodCall = "_Option_value." ~ fn ~ "(args)";
    }
    alias R = typeof(mixin(MethodCall));
    static if(is(R == void)) {
      if(isDefined) mixin(MethodCall ~ ';');
    } else {
      return isDefined ? Some!R(mixin(MethodCall)) : None!R();
    }
  }

  bool opEquals(U: T)(const(Option!U) rhs) const {
    if( isDefined &&  rhs.isDefined) return _Option_value == rhs._Option_value;
    if(!isDefined && !rhs.isDefined) return true;
    return false;
  }
}

pure Option!T Some(T)(T t) {
  return Some!(T, T)(t);
}
pure Option!T Some(T, U = T)(U t) if(is(T: U)) {
  static if(isNullableType!T) {
    enforce(t, "Value must not be null!");
    return Option!T(t);
  } else {
    return Option!T(t, true);
  }
}
pure nothrow Option!T None(T)() {
  static if(isNullableType!T)
    return Option!T(null);
  else
    return Option!T(T.init, false);
}

// `flatten` is defined as a top-level function in order to provide bettern type inference (to my best knowledge).
pure nothrow Option!T flatten(T)(Option!(Option!T) o)
{
  return o.isDefined ? o._Option_value : None!T();
}

// `filter`, `map` and `flatMap` is defined as a top-level function to avoid error:
// "cannot use local 'fun' as parameter to non-global template"
Option!T filter(alias pred, T)(Option!T o) if(is(typeof(unaryFun!pred(o.get)) : bool))
{
  if(o.isDefined && unaryFun!pred(o.get))
    return o;
  else
    return None!T();
}
auto map(alias fun, T)(Option!T o) if(is(typeof(unaryFun!fun(o.get))))
{
  alias R = typeof(unaryFun!fun(o.get));
  static if(is(R == void)) {
    if(o.isDefined) unaryFun!fun(o._Option_value);
  } else {
    return o.isDefined ? Some!R(unaryFun!fun(o._Option_value)) : None!R();
  }
}
auto flatMap(alias fun)(Option!(ParameterTypeTuple!(unaryFun!fun)[0]) o) if(isOptionType!(typeof(unaryFun!fun(o.get))))
{
  return map!fun(o).flatten;
}

// helpers for arrays and AAs
Option!(ElementEncodingType!R) detect(alias pred, R)(R range) if(isInputRange!R)
{
  return Option!(ElementEncodingType!R).fromRange(find!(pred, R)(range));
}
Option!V fetch(K, V)(V[K] aa, const K key)
{
  auto ptr = key in aa;
  return (ptr == null) ? None!V() : Some(*ptr);
}


unittest {
  class C {
    int _i = 5;
    void method1()             { _i = 10; }
    int  method2(int x, int y) { return _i + x + y; }
    override string toString() const { return "C's toString"; }
  }
  class D1: C {}
  class D2: C {}

  // construction helpers
  auto s0 = Some(3);
  auto s1 = Some("hoge");
  auto s2 = Some(new C);
  auto n0 = None!int();
  auto n1 = None!string();
  auto n2 = None!C();
  assert( s0.isDefined);
  assert( s1.isDefined);
  assert( s2.isDefined);
  assert(!n0.isDefined);
  assert(!n1.isDefined);
  assert(!n2.isDefined);
  assertThrown!Exception(Some!(int*)(null));
  assertThrown!Exception(Some!C(null));

  {// Option constructor with value type, pointer, array/AA, class (Note that empty arrays are treated as null)
    int integer = 0;
    int[string] aaEmpty, aaNonEmpty;
    aaNonEmpty["abc"] = 10;
    assert( Option!(int        )(19                    ).isDefined);
    assert(!Option!(int*       )(null                  ).isDefined);
    assert( Option!(int*       )(&integer              ).isDefined);
    assert( Option!(string     )(null                  ).isDefined);
    assert( Option!(string     )(""                    ).isDefined);
    assert( Option!(string     )("hoge"                ).isDefined);
    assert( Option!(int[string])(cast(int[string]) null).isDefined);
    assert( Option!(int[string])(aaEmpty               ).isDefined);
    assert( Option!(int[string])(aaNonEmpty            ).isDefined);
    assert( Option!(C          )(s2.get                ).isDefined);
    assert(!Option!(C          )(null                  ).isDefined);
    assert(Option!(string     )(                  null) == Some(""));
    assert(Option!(int[string])(cast(int[string]) null) == Some(aaEmpty));
  }

  {// construction with type qualifier should be compiled
    assert(Option!(const     int)(0).isDefined);
    assert(Option!(immutable int)(0).isDefined);
    assert(Option!(const C)(              new C).isDefined);
    assert(Option!(const C)(cast(const C) new C).isDefined);

    assert(Some!(const     int)(0).isDefined);
    assert(Some!(immutable int)(0).isDefined);
    assert(Some!(const C)(              new C).isDefined);
    assert(Some!(const C)(cast(const C) new C).isDefined);

    assert(!None!(const     int)().isDefined);
    assert(!None!(immutable int)().isDefined);
    assert(!None!(const C)().isDefined);
  }

  {// get, getOrElse, orElse
    assert(s0.get    == 3);
    assert(s1.get    == "hoge");
    assert(s2.get._i == 5);
    assertThrown!Exception(n0.get);
    assertThrown!Exception(n1.get);
    assertThrown!Exception(n2.get);

    assert(s0.getOrElse(7)         == s0.get);
    assert(s0.getOrElse!bool(true) == s0.get);
    assert(s1.getOrElse("fuga")    == s1.get);
    assert(s2.getOrElse(new C)     is s2.get);
    assert(n0.getOrElse(7)         == 7);
    assert(n1.getOrElse("fuga")    == "fuga");
    assert(n2.getOrElse(new C)._i  == 5);

    assert(s0.orElse(None!int)      == s0);
    assert(s1.orElse(Some("fuga"))  == s1);
    assert(s2.orElse(None!C())      == s2);
    assert(n0.orElse(Some(10))      == Some(10));
    assert(n1.orElse(None!string()) == None!string());
    assert(n2.orElse(s2)            == s2);
  }

  {// array conversion
    assert(s0.array == [s0.get]);
    assert(s1.array == [s1.get]);
    assert(s2.array == [s2.get]);
    assert(n0.array == []);
    assert(n1.array == []);
    assert(n2.array == []);
    assert(s0 == Option!(int   ).fromRange(s0.array));
    assert(s1 == Option!(string).fromRange(s1.array));
    assert(s2 == Option!(C     ).fromRange(s2.array));
    assert(n0 == Option!(int   ).fromRange(n0.array));
    assert(n1 == Option!(string).fromRange(n1.array));
    assert(n2 == Option!(C     ).fromRange(n2.array));
  }

  {// toString
    assert(s0.toString == "Some!(int)(3)");
    assert(s1.toString == "Some!(string)(hoge)");
    assert(s2.toString == "Some!(C)(C's toString)");
    assert(n0.toString == "None!(int)()");
    assert(n1.toString == "None!(string)()");
    assert(n2.toString == "None!(C)()");
  }

  {// access T's members
    assert(s1.length == Some!size_t(4));
    s2.method1();
    assert(s2.get._i        == 10);
    assert(s2._i            == Some(10));
    assert(s2.method2(1, 2) == Some(13));
    assert(n1.length        == None!size_t());
    assertNotThrown(n2.method1());
    assert(n2.method2(1, 2) == None!int());
  }

  {// flatten
    assert(Some(Some(1))      .flatten == Some(1));
    assert(Some(None!int())   .flatten == None!int());
    assert(None!(Option!int)().flatten == None!int());
  }

  {// filter
    assert(Some(3)   .filter!(x => x % 2 == 1) == Some(3));
    assert(Some(3)   .filter!("a % 2 == 0")    == None!int());
    assert(None!int().filter!(x => x % 2 == 1) == None!int());
    assert(None!int().filter!("a % 2 == 0")    == None!int());
  }

  {// map
    int sum = 0;
    void voidFun(int i) { sum += 1; }
    Some(1).map!voidFun();
    assert(sum == 1);
    None!int().map!voidFun();
    assert(sum == 1);

    static int intFun(int x) { return x + 1; }
    assert(Some(1).map!intFun()    == Some(2));
    assert(None!int().map!intFun() == None!int());

    assert(Some(1)   .map!((int x) => x + 1) == Some(2));
    assert(None!int().map!((int x) => x + 1) == None!int());
    assert(Some(1)   .map!"a + 1"() == Some(2));
    assert(None!int().map!"a + 1"() == None!int());

    // function passed to `map` should not return null
    C nullFun(int i) { return null; }
    assertThrown(Some(1).map!(nullFun));
  }

  {// flatMap
    Option!int fun(int i) { return Some(i+1); }
    assert(Some(1)   .flatMap!fun() == Some(2));
    assert(None!int().flatMap!fun() == None!int());
  }

  {// detect element from array
    auto array = [1, 2, 3, 4, 5];
    bool pred1(int i) { return i == 1; }
    assert(array.detect!pred1    == Some(1));
    assert(array.detect!"a > 3" == Some(4));
    assert(array.detect!"a > 8" == None!int());
  }

  {// fetch value from AA
    int[string] aa;
    aa["abc"] = 0;
    assert(aa.fetch("abc") == Some(0));
    assert(aa.fetch("xyz") == None!int());
  }

  {// arguments should be lazily evaluated
    int i = 1;
    assert(s2.method2(i, i++) == Some!(int)(s2.get._i + 2));
    assert(i == 2);
    assert(n2.method2(i, i++) == None!(int)());
    assert(i == 2);
  }

  {// type conversion from derived class
    auto d1 = new D1;
    auto optD1    = Option!D1(new D1);
    auto optD2    = Option!D2(new D2);
    auto optD1AsC = Option!C (new D1);
    auto optD2AsC = Option!C.fromRange([new D2]);
  }

  {// equality
    assert(None!(int )()  == None!(int )());
    assert(None!(int )()  == None!(long)());
    assert(None!(long)()  == None!(int )());
    assert(Some!(int )(1) != None!(int )());
    assert(None!(long)()  != Some!(int )(1));
    assert(Some(1) == Some(1));
    assert(Some(1) == Some(1L));
    assert(Some(1) != Some(2));
    assert(Some(1) != Some(2L));

    auto d1 = new D1;
    auto d2 = new D2;
    assert(Some!C (d1) == Some!C (d1));
    assert(Some!C (d1) == Some!D1(d1));
    assert(Some!D1(d1) == Some!C (d1));
    assert(Some!D1(d1) == Some!D1(d1));
    assert(Some!C (d1) != Some!C (d2));
  }
}
