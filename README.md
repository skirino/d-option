# Yet another Option/Maybe implementation in D

## Installation

- You can add this package as your project's dependency using [dub](https://github.com/D-Programming-Language/dub).
See [here](http://code.dlang.org/packages/d-option) for instructions.

## Usage

```d
import option;

// construct Option instances and pull out the values
Some(1)   .getOrElse(3); // => 1
None!int().getOrElse(3); // => 3
Some(1)   .get;          // => 1
None!int().get;          // throws an exception since there's nothing to return

// query statuses
Some(1)   .isDefined; // => true
None!int().isDefined; // => false
Some(1)   .isEmpty;   // => false
None!int().isEmpty;   // => true

// access fields of wrapped values
class A {
  int method(int i) { return i + 1; }
}
Some("hello").length;   // => Some(5)    : get `length` property and wrap the result
Some(new A).method(5);  // => Some(6)    : call `A#method` with the content and wrap the result
None!A()   .method(10); // => None!int() : skip calling `A#method` since it's an empty Option
Some(1).map!"a + 2"();  // => Some(3)    : apply lambda to the content and wrap the result

// method chaining
Option!int f1(int i) { return i % 2 == 0 ? Some(i / 2) : None!int(); }
Option!int f2(int i) { return i % 3 == 0 ? Some(i / 3) : None!int(); }
auto x = 5;
Some(12).flatMap!f1.flatMap!f2.map!(i => to!string(i * x)).getOrElse("None") == "20"; // => "20"

// array and AA helpers
int[] array = [1, 2, 3, 4, 5];
array.detect!"a % 2 == 0"; // => Some(2)
array.detect!(i => i > 7); // => None!int()
int[string] aa;
aa["abc"] = 0;
aa.fetch("abc"); // => Some(0)
aa.fetch("xyz"); // => None!int()
```
- See unit tests in [option.d](source/option.d) for more detail.

## Development

- Run unit tests: `$ dub test`
- Run unit tests on each edit using [guard gem](https://github.com/guard/guard): `$ guard start`
