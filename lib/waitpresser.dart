import "package:flutter/material.dart";

class WaitPresser extends StatefulWidget {
	const WaitPresser({
		super.key,

		required this.onPressed,
		required this.builder,

		this.replacePress
	});

	final Function(Future Function(Future Function()), ) onPressed;
	final dynamic replacePress;

	final Widget Function(Function()? onPressed, bool inFuture, Future? future) builder;

	@override
	State<WaitPresser> createState() => _WaitPresserState();
}

class _WaitPresserState extends State<WaitPresser> {
	bool inFuture = false;
	Future? future;

	@override
	Widget build(BuildContext context) {

		return widget.builder(
			!inFuture
				? () async => await widget.onPressed(registerFuture)
				: widget.replacePress,
			inFuture,
			future
		);
	}

	Future registerFuture<T>(Future<T> Function() getFuture) async {
		setState(() {
			future = getFuture();
			inFuture = true;
		});

		final T resuilt = await future;

		setState(() {
			future = null;
			inFuture = false;
		});

		return resuilt;
	}
}