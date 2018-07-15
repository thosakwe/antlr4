# package:antlr

#### Description
Fully-featured ANTLR runtime library for Dart.

#### Contributors
* [Tiago Mazzutti](https://github.com/tiagomazzutti) - Original port to Dart, bulk of Dart runtime code
* [Tobe Osakwe](https://github.com/thosakwe) - Updated library for Dart 2.0/strong mode compatibility,
additional maintenance


#### Installation
The Dart ANTLR4 runtime can easily be installed from
[Pub](https://pub.dartlang.org/packages/antlr4):

Simply add it to your `pubspec.yaml` file as a dependency:

```yaml
dependencies:
  antlr: ^4.7.0
```

You may consider pinning to `4.x` versions, rather than `4.7.x`:

```yaml
dependencies:
  antlr: ^4.0.0
```

Afterwards, it is easy to pull the dependency from the Internet:

```bash
pub get
```

#### Usage
At some point, you will need to import the `antlr` library, like such:

```dart
import 'package:antlr/antlr.dart';
```

In Dart, you have two choices on how to manage this:
* Importing the library in each file, keeping them modular
([recommended](https://www.dartlang.org/guides/libraries/create-library-packages))
* Creating a master library that imports `antlr`, and transitively importing in child files via the
`part of` keyword

Either way, you will need to add a `@header{}` section to your grammar:
   
Either:

```
@header {
    library your_library_name;
    import 'package:antlr/antlr.dart';
}
```

Or: 
```
@header {
    part of your_library_name;
}
```

**NOTE:** Though it is not recommended by the Dart team, when prototyping grammars, you may consider
the `part of`-based strategy, for the sake of convenience. In general, however, or when publishing,
do not forget to revert `import`/`export`.

Afterwards, you can use your grammar in Dart code, just like any other library:

```
import "package:antlr/antlr.dart";
import "SomeLanguageLexer.dart";
import "SomeLanguageParser.dart";

main() {
  var input = 'some text to be parsed...';
  var source = new StringSource(input);
  var lexer = new SomeLanguageLexer(source);
  var tokens = new CommonTokenSource(lexer);
  var parser = new SomeLanguageParser(tokens);

  var result = parser.<entry_rule>();    
  // ...
}
```

You can find many samples (using the old version of the Dart runtime)
[here](https://github.com/tiagomazzutti/antlr4dart/tree/master/web).