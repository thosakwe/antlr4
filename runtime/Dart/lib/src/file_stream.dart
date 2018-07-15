import 'package:file/file.dart';
import 'async_stream.dart';

/// An input stream sourced from a file.
///
/// This class uses `package:file`, which has the advantage of being pluggable, and mockable.
/// Thus, it could potentially even work in the browser.
class ANTLRFileStream extends ANTLRAsyncStream {
  ANTLRFileStream(File file)
      : super(file.openRead(),
            length: file.lengthSync(), sourceName: file.absolute.path);
}
