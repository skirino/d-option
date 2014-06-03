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

module skirino.option;

import std.array : empty;
import std.conv;
import std.traits;
import std.exception;

private template isNullableType(T) {
  enum isNullableType = is(T == class) || is(T == interface) || isPointer!T;
}

struct Option(T)
{
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

private:
  T _Option_value;// Avoid name conflict

public:
  @property pure ref inout(T) get() inout {
    enforce(isDefined, "No such element: None!(" ~ T.stringof ~ ").get");
    return _Option_value;
  }

  pure nothrow T getOrElse(U: T)(U other) {
    return isDefined ? _Option_value : other;
  }
  pure nothrow Option!T orElse(Option!T other) {
    return isDefined ? this : other;
  }

  pure nothrow inout(T)[] array() inout {
    return isDefined ? [_Option_value] : [];
  }
  static pure Option!T fromArray(U: T)(U[] array) {
    return array.empty ? None!T() : Some!T(array[0]);
  }

  string toString() {
    if(isDefined)
      return "Some!(" ~ T.stringof ~ ")(" ~ to!string(cast(Unqual!T) _Option_value) ~ ')';
    else
      return "None!(" ~ T.stringof ~ ")()";
  }

  auto opDispatch(string fn, Args...)(lazy Args args) {
    static if(args.length == 0) {
      alias F = typeof(mixin("_Option_value." ~ fn));
      static if(isCallable!F) {
        enum MethodCall = "_Option_value." ~ fn ~ "()";
      } else {// property access
        enum MethodCall = "_Option_value." ~ fn;
      }
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
  static if(isNullableType!T) {
    enforce(t, "Value must not be null!");
    return Option!T(t);
  } else {
    return Option!T(t, true);
  }
}

pure nothrow Option!T None(T)() {
  static if(isNullableType!T) {
    return Option!T(null);
  } else {
    return Option!T(T.init, false);
  }
}

auto map(alias fun, T)(Option!T o) if(isCallable!fun) {
  alias R = ReturnType!(fun);
  static if(is(R == void)) {
    if(o.isDefined)
      fun(o._Option_value);
  } else {
    if(o.isDefined)
      return Some!R(fun(o._Option_value));
    else
      return None!R();
  }
}

unittest {
  class C {
    int _i = 5;
    void method1()             { _i = 10; }
    int  method2(int x, int y) { return _i + x + y; }
    override string toString() { return "C's toString"; }
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

  {// construction with type qualifier should be able to compile
    assert(Option!(const     int)(0).isDefined);
    assert(Option!(immutable int)(0).isDefined);
    assert(Option!(const C)(              new C).isDefined);
    assert(Option!(const C)(cast(const C) new C).isDefined);
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
    assert(s0 == Option!(int   ).fromArray(s0.array));
    assert(s1 == Option!(string).fromArray(s1.array));
    assert(s2 == Option!(C     ).fromArray(s2.array));
    assert(n0 == Option!(int   ).fromArray(n0.array));
    assert(n1 == Option!(string).fromArray(n1.array));
    assert(n2 == Option!(C     ).fromArray(n2.array));
  }

  {// toString
    assert(s0.toString == "Some!(int)(3)");
    assert(s1.toString == "Some!(string)(hoge)");
    assert(s2.toString == "Some!(C)(C's toString)");
    assert(n0.toString == "None!(int)()");
    assert(n1.toString == "None!(string)()");
    assert(n2.toString == "None!(C)()");
  }

  {// call method
    assert(s1.length == Some!ulong(4));
    s2.method1();
    assert(s2.get._i        == 10);
    assert(s2._i            == Some(10));
    assert(s2.method2(1, 2) == Some(13));
    assert(n1.length        == None!ulong());
    assertNotThrown(n2.method1());
    assert(n2.method2(1, 2) == None!int());
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

    assert(Some(1)   .map!((int x) => x+1)() == Some(2));
    assert(None!int().map!((int x) => x+1)() == None!int());
  }

  {// arguments should be lazily evaluated
    int i = 1;
    assert(n2.method2(i, i++) == None!(int)());
    assert(i == 1);
    assert(s2.method2(i, i++) == Some!(int)(s2.get._i + 2));
    assert(i == 2);
  }

  {// type conversion from derived class
    auto d1 = new D1;
    auto optD1    = Option!D1(new D1);
    auto optD2    = Option!D2(new D2);
    auto optD1AsC = Option!C (new D1);
    auto optD2AsC = Option!C .fromArray([new D2]);
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
