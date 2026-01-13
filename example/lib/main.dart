import 'package:flutter/material.dart';
import 'package:vnc_viewer_example/viewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget { // 改为 StatelessWidget 更合适（无状态根组件）
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