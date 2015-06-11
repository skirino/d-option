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

import std.algorithm : find, reduce;
import std.functional : unaryFun;
import std.conv : to;
import std.traits : isCallable, isPointer, Unqual;
import std.range : isInputRange, ElementType, ElementEncodingType, empty, front;
import std.exception : enforce, assertThrown, assertNotThrown;

template isOptionType(T) {
  static if(is(T U == Option!U))
    enum isOptionType = true;
  else
    enum isOptionType = false;
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
    this      (inout(T) t) inout { _Option_value = t; }
    this(U: T)(inout(U) u) inout { _Option_value = u; }
  } else {
  private:
    this      (inout(T) t, bool b) inout { _Option_value = t; _isDefined = b; }
    this(U: T)(inout(U) u, bool b) inout { _Option_value = u; _isDefined = b; }
  public:
    this      (inout(T) u) inout { _Option_value = u; _isDefined = true; }
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

  pure nothrow const(T) getOrElse(U: T)(const(U) other) const {
    return isDefined ? _Option_value : other;
  }
  pure nothrow T getOrElse(U: T)(U other) {
    return isDefined ? _Option_value : other;
  }
  pure nothrow const(Option!T) orElse(U: T)(const(Option!U) other) const {
    return isDefined ? this : other;
  }
  pure nothrow Option!T orElse(U: T)(Option!U other) {
    return isDefined ? this : other;
  }

  pure nothrow inout(T)[] array() inout {
    return isDefined ? [_Option_value] : [];
  }
  static pure Option!T fromRange(R)(R r) if(isInputRange!R && is(ElementType!(R): T)) {
    return r.empty ? None!T() : Some!T(r.front);
  }

  string toString() const { // toString must be "const" in order to avoid strange linker error
    if(isDefined) {
      static if(__traits(compiles, to!string(_Option_value)))
        return "Some!(" ~ T.stringof ~ ")(" ~ to!string(_Option_value) ~ ')';
      else
        return "Some!(" ~ T.stringof ~ ")(" ~ (cast(Unqual!T)_Option_value).toString ~ ')'; // Avoid error due to non-const toString()
    } else {
      return "None!(" ~ T.stringof ~ ")()";
    }
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

  // foreach support
  int opApply(int delegate(ref const(T)) operation) const {
    if(isDefined)
      return operation(_Option_value);
    else
      return 0;
  }
}

pure Option!T Some(T)(T t)
{
  return Some!(T, T)(t);
}
pure Option!T Some(T, U = T)(U t) if(is(T: U))
{
  static if(isNullableType!T) {
    enforce(t, "Value must not be null!");
    return Option!T(t);
  } else {
    return Option!T(t, true);
  }
}
pure nothrow Option!T None(T)()
{
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
pure nothrow Option!T filter(alias pred, T)(Option!T o) if(is(typeof(unaryFun!pred(o.get)) : bool))
{
  if(o.isDefined && unaryFun!pred(o._Option_value))
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
auto flatMap(alias fun, T)(Option!T o) if(isOptionType!(typeof(unaryFun!fun(o.get))))
{
  return map!fun(o).flatten;
}

// range helper
Option!(ElementEncodingType!R) detect(alias pred, R)(R range) if(isInputRange!R)
{
  return Option!(ElementEncodingType!R).fromRange(find!(pred, R)(range));
}
pure ElementEncodingType!(R).OptionValueType[] flatten(R)(R range) if(isInputRange!R && isOptionType!(ElementEncodingType!R))
{
  ElementEncodingType!(R).OptionValueType[] a0 = [];
  return reduce!((a, b) => b.isDefined ? a ~ b.get : a)(a0, range);
}

// associative array helper
//   Define each function overloads for mutable/const/immutable to workaround
//   an issue about inout (https://issues.dlang.org/show_bug.cgi?id=9983).
pure nothrow Option!V fetch(K, V)(V[K] aa, const K key)
{
  auto ptr = key in aa;
  return (ptr == null) ? None!V() : Some(*ptr);
}
pure nothrow Option!(const V) fetch(K, V)(const V[K] aa, const K key)
{
  auto ptr = key in aa;
  return (ptr == null) ? None!(const V)() : Some(*ptr);
}
pure nothrow Option!(immutable V) fetch(K, V)(immutable V[K] aa, const K key)
{
  auto ptr = key in aa;
  return (ptr == null) ? None!(immutable V)() : Some(*ptr);
}


unittest {
  class C
  {
    int _i = 5;
    void method1()             { _i = 10; }
    int  method2(int x, int y) { return _i + x + y; }
    override string toString() const { return "C#toString"; }
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

    assert(s0.getOrElse(7)        == s0.get);
    assert(s0.getOrElse(true)     == s0.get);
    assert(s1.getOrElse("fuga")   == s1.get);
    assert(s2.getOrElse(new C)    is s2.get);
    assert(n0.getOrElse(7)        == 7);
    assert(n1.getOrElse("fuga")   == "fuga");
    assert(n2.getOrElse(new C)._i == 5);

    assert(s0.orElse(None!int)      == s0);
    assert(s1.orElse(Some("fuga"))  == s1);
    assert(s2.orElse(None!C())      == s2);
    assert(n0.orElse(Some(10))      == Some(10));
    assert(n1.orElse(None!string()) == None!string());
    assert(n2.orElse(s2)            == s2);

    assert(Some!(const     int)(1).get == 1);
    assert(Some!(immutable int)(1).get == 1);
    assert(Some!(const     int)(1).getOrElse(0) == 1);
    assert(Some!(immutable int)(1).getOrElse(0) == 1);
    assert(Some!(const     int)(1).orElse(Some!(const     int)(0)) == Some(1));
    assert(Some!(immutable int)(1).orElse(Some!(immutable int)(0)) == Some(1));
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

    assert(Option!(const     int).fromRange(Some!(const     int)(1).array) == Some(1));
    assert(Option!(immutable int).fromRange(Some!(immutable int)(1).array) == Some(1));
  }

  {// toString
    assert(s0.toString == "Some!(int)(3)");
    assert(s1.toString == "Some!(string)(hoge)");
    assert(s2.toString == "Some!(C)(C#toString)");
    assert(n0.toString == "None!(int)()");
    assert(n1.toString == "None!(string)()");
    assert(n2.toString == "None!(C)()");

    class X {}
    static assert(__traits(compiles, Some(new X).toString));
    struct Y {}
    static assert(__traits(compiles, Some(Y()).toString));

    assert(Some!(const     int)(1).toString == "Some!(const(int))(1)");
    assert(Some!(immutable int)(1).toString == "Some!(immutable(int))(1)");
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

    assert(Some!(const     string)("hello").length == Some(5));
    assert(Some!(immutable string)("hello").length == Some(5));
  }

  {// flatten
    assert(Some(Some(1))      .flatten == Some(1));
    assert(Some(None!int())   .flatten == None!int());
    assert(None!(Option!int)().flatten == None!int());

    assert(Some(Some!(const     int)(1)).flatten == Some(1));
    assert(Some(Some!(immutable int)(1)).flatten == Some(1));
  }

  {// filter
    assert(Some(3)   .filter!(x => x % 2 == 1) == Some(3));
    assert(Some(3)   .filter!("a % 2 == 0")    == None!int());
    assert(None!int().filter!(x => x % 2 == 1) == None!int());
    assert(None!int().filter!("a % 2 == 0")    == None!int());

    assert(Some!(const     int)(3).filter!(x => x % 2 == 1) == Some(3));
    assert(Some!(immutable int)(3).filter!(x => x % 2 == 1) == Some(3));
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

    assert(Some!(const     int)(1).map!((int x) => x + 1) == Some(2));
    assert(Some!(immutable int)(1).map!((int x) => x + 1) == Some(2));
  }

  {// flatMap
    Option!int fun(int i) { return Some(i+1); }
    assert(Some(1)   .flatMap!fun() == Some(2));
    assert(None!int().flatMap!fun() == None!int());

    assert(Some!(const     int)(1).flatMap!fun() == Some(2));
    assert(Some!(immutable int)(1).flatMap!fun() == Some(2));
  }

  {// method chaining
    Option!int f1(int i) { return i % 2 == 0 ? Some(i / 2) : None!int(); }
    Option!int f2(int i) { return i % 3 == 0 ? Some(i / 3) : None!int(); }
    auto x = 10;
    assert(Some(12).flatMap!f1.flatMap!f2.map!(i => to!string(i * x)).getOrElse("None") == "20"); // => "20"
  }

  {// detect element from array
    auto array1 = [1, 2, 3, 4, 5];
    bool pred1(int i) { return i == 1; }
    assert(array1.detect!pred1        == Some(1));
    assert(array1.detect!"a % 2 == 0" == Some(2));
    assert(array1.detect!(i => i > 7) == None!int());
    const array2 = array1;
    assert(array2.detect!pred1        == Some(1));
    assert(array2.detect!"a % 2 == 0" == Some(2));
    assert(array2.detect!(i => i > 7) == None!int());
    immutable array3 = array1.idup;
    assert(array3.detect!pred1        == Some(1));
    assert(array3.detect!"a % 2 == 0" == Some(2));
    assert(array3.detect!(i => i > 7) == None!int());
  }

  {// flatten array of Option's
    assert([None!int()]                  .flatten == []);
    assert([Some(1), None!int(), Some(2)].flatten == [1, 2]);
    assert([Some(1), Some(2), Some(3)]   .flatten == [1, 2, 3]);
    const array1 = [None!int(), Some(1)];
    assert(array1.flatten == [1]);
    immutable array2 = [Some(1), Some(2)];
    assert(array2.flatten == [1, 2]);
  }

  {// fetch value from AA
    int[string] aa1;
    aa1["abc"] = 0;
    assert(aa1.fetch("abc") == Some(0));
    assert(aa1.fetch("xyz") == None!int());
    const aa2 = aa1;
    assert(aa2.fetch("abc") == Some(0));
    assert(aa2.fetch("xyz") == None!int());
    immutable aa3 = cast(immutable)aa1.dup;
    assert(aa3.fetch("abc") == Some(0));
    assert(aa3.fetch("xyz") == None!int());
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

  {// foreach
    int x = 0;
    foreach(elem; Some("hello")) { x++; }
    assert(x == 1);
    foreach(elem; None!int()) { x++; }
    assert(x == 1);
  }
}
