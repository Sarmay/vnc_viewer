import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vnc_viewer_example/viewer.dart';
import 'dart:async';
import 'dart:isolate';
import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  // 初始化崩溃日志捕获
  initCrashHandler();
  runApp(const MyApp());
}

// 初始化崩溃日志处理
void initCrashHandler() {
  // 1. 捕获Flutter框架异常
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    } else {
      FlutterError.presentError(details);
      // 保存到日志文件
      _saveCrashLog('Flutter Framework Error', details);
    }
  };

  // 2. 捕获Dart异常
  runZonedGuarded(() {
    // 注册当前isolate的错误监听
    Isolate.current.addErrorListener(
      RawReceivePort((List<dynamic> pair) async {
        final error = pair.first;
        final stackTrace = pair.last;
        _saveCrashLog(
            'Dart Isolate Error',
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace as StackTrace,
              library: 'Isolate',
              context: ErrorDescription('Isolate Error'),
            ));
      }).sendPort,
    );
  }, (error, stackTrace) {
    // 捕获runZonedGuarded中的异常
    _saveCrashLog(
        'Dart Exception',
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Dart',
          context: ErrorDescription('Uncaught Dart Exception'),
        ));
  });
}

// 保存崩溃日志到文件
Future<void> _saveCrashLog(
    String errorType, FlutterErrorDetails details) async {
  try {
    // 获取应用文档目录
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    // 创建日志文件
    File logFile = File('$appDocPath/crash_logs.txt');
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }

    // 格式化日志内容
    String timestamp = DateTime.now().toIso8601String();
    String errorMessage = details.exception.toString();
    String stackTrace = details.stack.toString();
    String library = details.library ?? 'Unknown Library';

    // 构建日志条目
    String logEntry = '''
=== $timestamp ===
Error Type: $errorType
Library: $library
Error: $errorMessage
Stack Trace:
$stackTrace

''';

    // 追加到日志文件
    await logFile.writeAsString(logEntry, mode: FileMode.append);

    // 在控制台输出日志（调试用）
    debugPrint('Crash logged: $errorType');
  } catch (e) {
    debugPrint('Failed to save crash log: $e');
  }
}

class MyApp extends StatelessWidget {
  // 改为 StatelessWidget 更合适（无状态根组件）
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      showSemanticsDebugger: false,
      theme: ThemeData(
        primaryColor: Colors.blue,
        primarySwatch: Colors.blue,
      ),
      // 将主页内容抽离为独立组件，使用新的上下文
      home: const HomePage(),
    );
  }
}

// 独立的主页组件，内部上下文可访问 Navigator
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _hostNameEditingController =
      TextEditingController(text: "192.168.137.178");

  final TextEditingController _portEditingController =
      TextEditingController(text: "5900");

  final TextEditingController _passwordEditingController =
      TextEditingController(text: "Xjjt@123");

  @override
  Widget build(BuildContext context) {
    // 这里的 context 是 HomePage 的上下文，属于 Navigator 后代，可正常导航
    return Scaffold(
      appBar: AppBar(title: const Text('VncViewer app')),
      body: Container(
        margin: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              TextFormField(
                controller: _hostNameEditingController,
                decoration: const InputDecoration(hintText: 'host name'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _portEditingController,
                decoration: const InputDecoration(hintText: 'port'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordEditingController,
                decoration: const InputDecoration(hintText: 'password'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              const SizedBox(
                height: 16,
              ),
              MaterialButton(
                onPressed: () {
                  String hostName = _hostNameEditingController.text;
                  String port = _portEditingController.text;
                  String password = _passwordEditingController.text;
                  // 现在使用的是 HomePage 的 context，可正常找到 Navigator
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (contextC) => ExampleViewer(
                        hostName: hostName,
                        password: password,
                        port: port,
                      ),
                    ),
                  );
                },
                color: Colors.blue,
                child: const Text('open vnc viewer'),
              ),
              const SizedBox(height: 16),
              // 测试崩溃按钮
              MaterialButton(
                onPressed: () {
                  // 模拟Flutter框架异常
                  FlutterError.reportError(FlutterErrorDetails(
                    exception: Exception('Test Crash Exception'),
                    stack: StackTrace.current,
                    library: 'Test',
                    context: ErrorDescription('Test Crash Button Pressed'),
                  ));

                  // 模拟Dart异常
                  Future.delayed(const Duration(milliseconds: 500), () {
                    throw Exception('Test Delayed Crash Exception');
                  });
                },
                color: Colors.red,
                child: const Text('Test Crash'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 优化：释放控制器资源（避免内存泄漏）
  @override
  void dispose() {
    _hostNameEditingController.dispose();
    _portEditingController.dispose();
    _passwordEditingController.dispose();
    super.dispose();
  }
}
