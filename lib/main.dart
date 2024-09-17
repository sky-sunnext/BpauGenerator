import "dart:async";

import "package:flutter/foundation.dart";
import "package:provider/provider.dart";
import "package:sqflite_common/sqflite.dart";
import "package:flutter/material.dart";
import "package:cross_file/cross_file.dart";
import "package:desktop_drop/desktop_drop.dart";
import "package:file_picker/file_picker.dart";
import "package:sembast/sembast.dart";
import "package:shared_preferences/shared_preferences.dart";
import "dart:io";

import "./waitpresser.dart";

Future main() async {
	final prefs = await SharedPreferencesWithCache.create(
		cacheOptions: const SharedPreferencesWithCacheOptions()
	);

	// 初始化 FFMPEG 路径
	if (prefs.getString("env.ffmpeg") == null) {
		await prefs.setString("env.ffmpeg", "ffmpeg");
	}

	// 初始化 FFPROBE 路径
	if (prefs.getString("env.ffprobe") == null) {
		await prefs.setString("env.ffprobe", "ffprobe");
	}

	runApp(MultiProvider(
		providers: [
			Provider<SharedPreferencesWithCache>.value(value: prefs)
		],
		child: const App(),
	));
}

class App extends StatelessWidget {
	const App({super.key});

	// This widget is the root of your application.
	@override
	Widget build(BuildContext context) {
		return const MaterialApp(
			themeMode: ThemeMode.system,
			home: Component()
		);
	}
}

class Component extends StatefulWidget {
	const Component({super.key});

	@override
	State<Component> createState() => _ComponentState();
}

class _ComponentState extends State<Component> {
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				toolbarHeight: 100,
				title: const Text("BPAU 生成"),
				actions: [
					WaitPresser(
						onPressed: (regFuture) async {
							regFuture(() => showHistory(context));
						},
						builder: (onPressed, inFuture, ture) {
							return IconButton.outlined(
								onPressed: onPressed,
								icon: const Icon(Icons.history),
								tooltip: "历史记录"
							);
						}
					),
					const SizedBox(width: 20)
				],
			),
			body: ListView(
				padding: const EdgeInsets.symmetric(horizontal: 25),
				children: const [
					ConfigureComponent(),
					SizedBox(height: 15),
					GeneratorComponent()
				]
			),
		);
	}
}

Future showHistory(BuildContext context) async {

}

class PickerInput extends StatelessWidget {
	const PickerInput({
		super.key,


		required this.controllerBuilder,
		required this.decoration
	});

	final TextEditingController Function() controllerBuilder;
	final InputDecoration decoration;

	@override
	Widget build(BuildContext context) {
		final controller = controllerBuilder();

		return TextField(
			controller: controller,
			decoration: decoration.copyWith(
				suffix: WaitPresser(
					onPressed: (regFuture) async {
						final FilePickerResult file = await regFuture(() {
							return FilePicker.platform.pickFiles();
						});

						controller.text = file.files.first.path!;
					},
					builder: (onPressed, inFuture, future) => IconButton(
						onPressed: onPressed,
						icon: const Icon(Icons.file_open)
					),
				)
			)
		);
	}
}

const defaultTitleStyle = TextStyle(
	fontWeight: FontWeight.bold,
	fontSize: 25
);

class ConfigureComponent extends StatelessWidget {
	const ConfigureComponent({super.key});

	@override
	Widget build(BuildContext context) {
		final prefs = context.read<SharedPreferencesWithCache>();
		return SizedBox(
			width: double.maxFinite,
			child: Card(
				child: Padding(
					padding: const EdgeInsets.all(15),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: <Widget>[
							...<String, String>{
								"FFMPEG": "env.ffmpeg",
								"FFPROBE": "env.ffprobe"
							}.entries.map(<Widget>(pair) => PickerInput(
								controllerBuilder: () {
									String initValue = prefs.getString(pair.value)!;
									final controller = TextEditingController(text: initValue);

									controller.addListener(() {
										prefs.setString(pair.value,
											controller.value.text);
									});

									return controller;
								},
								decoration: InputDecoration(
									labelText: "${pair.key} 运行程序地址",
									helper: Row(
										children: [
											Text("没有安装${pair.key}？不知道怎么输入？"),
											TextButton(
												onPressed: () {},
												child: const Text("查看教程")
											)
										],
									)
								),
							))
						]
						.indexed.map<List<Widget>>((pair) => [
							...pair.$1 == 0 ? [] : const [SizedBox(height: 5)],
							pair.$2
						])
						.reduce((a, b) => [...a, ...b])
						..insertAll(0, [
							const Text("配置选项", style: defaultTitleStyle),
							const Divider(),
						]),
					),
				)
			)
		);
	}
}

class GeneratorComponent extends StatefulWidget {
	const GeneratorComponent({ super.key,});

	@override
	State<GeneratorComponent> createState() => _GeneratorComponentState();
}

class _GeneratorComponentState extends State<GeneratorComponent> {
	final titleControler = TextEditingController();
	var otherTitleAdder = TextEditingController();

	bool otherTitlesCreating = true;
	String? otherTitlesError;
	int otherTitlesIndex = 0;
	final List<TextEditingController> otherTitles = [];

	@override
	void initState() {
		super.initState();

		final prefs = context.read<SharedPreferencesWithCache>();


		// prefs.setStringList("temp.otherTitles", []);
		if (prefs.getStringList("temp.otherTitles") == null) {
			prefs.setStringList("temp.otherTitles", []);
		}

		otherTitles.clear();
		for (var text in prefs.getStringList("temp.otherTitles")!) {
			otherTitles.add(TextEditingController(text: text));
		}
	}

	void updateCollection(String name, List<TextEditingController> collection) {
		final prefs = context.read<SharedPreferencesWithCache>();

		debugPrint(collection.map((e) => e.text).toList().toString());
		prefs.setStringList("temp.otherTitles", collection.map((e) => e.text).toList())
		.whenComplete(() {
			setState(() {});
		});
	}

	void otherTitleSubmitted (String value) {
		otherTitlesError = null;

		if (otherTitlesCreating) {
			// 创建
			if (otherTitles.any((e) => e.text == value)) {
				setState(() => otherTitlesError = "该名称已存在！");
				return;
			}

			otherTitles.add(TextEditingController(text: value));
		}

		otherTitleAdder = TextEditingController();
		updateCollection("temp.otherTitles", otherTitles);
	}

	void otherTitleDelete() {
		otherTitlesCreating = true;
		otherTitles.removeAt(otherTitlesIndex);
		updateCollection("temp.otherTitles", otherTitles);
	}

	@override
	Widget build(BuildContext context) {
		// Init
		final formsList = <Widget>[
			Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					// 第一行
					Row(
						children: [
							const Flexible(
								flex: 2,
								fit: FlexFit.tight,
								child: TextField(
									decoration: InputDecoration(
										labelText: "音乐名",
										helperText: "要是音乐最原本的名字，比如“打上花火”就要写“打ち上げ花火”；注意“Remix”等字眼，不要。"
									),
								)
							),
							const SizedBox(width: 8,),
							Flexible(
								flex: 1,
								child: TextField(
									decoration: InputDecoration(
										labelText: "更多音乐名",
										helperText: "比如翻译之类的。",
										prefixIcon: otherTitlesCreating
											? const Icon(Icons.add)
											: const Icon(Icons.edit),
										suffix: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												otherTitlesCreating
													? const SizedBox()
													: IconButton(
														onPressed: otherTitleDelete,
														icon: const Icon(Icons.delete)
													)
											],
										),
										errorText: otherTitlesError
									),
									onSubmitted: otherTitleSubmitted,
									controller: otherTitlesCreating
										? otherTitleAdder
										: otherTitles[otherTitlesIndex],
								)
							)
						],
					),

					const SizedBox(height: 8),

					// 第二行
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Expanded(
								child: otherTitles.isEmpty
								? const SizedBox()
								: Scrollbar(
									child: SingleChildScrollView(
										child: Row(
											children: otherTitles.asMap().entries.map((pair) {
												final index = pair.key;
												final controler = pair.value;

												return TextButton(
													onPressed: () => setState(() {
														otherTitlesCreating = false;
														otherTitlesIndex = index;
													}),
													child: Text(controler.text)
												);
											}).toList(),
										),
									)
								)
							),

							const SizedBox(width: 8),
							
							TextButton.icon(
								onPressed: () => setState(() {
									otherTitlesCreating = true;
								}),
								label: const Text("添加"),
								icon: const Icon(Icons.add),
							),
						],
					)
				],
			)
		];
		
		return SizedBox(
			width: double.maxFinite,
			child: Card(
				child: Padding(
					padding: const EdgeInsets.all(15),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const Text("音乐信息", style: defaultTitleStyle),
							const Divider(),
							...formsList,
						]
					)
				)
			)
		);
	}
}