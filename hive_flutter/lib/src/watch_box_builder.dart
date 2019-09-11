part of hive_flutter;

/// Signature for a function that builds a widget given a [Box].
typedef BoxWidgetBuilder = Widget Function(BuildContext context, Box box);

/// A general-purpose widget which rebuilds itself when the box or a specific
/// key change.
class WatchBoxBuilder extends StatefulWidget {
  /// Creates a widget that rebuilds itself when a value in the [box] changes.
  ///
  /// If you specify [watchKeys], the widget only refreshes when a value
  /// associated to a key in [watchKeys] changes.
  WatchBoxBuilder({
    Key key,
    @required this.box,
    @required this.builder,
    this.watchKeys,
  })  : assert(box != null),
        assert(builder != null),
        super(key: key);

  /// The box which should be watched.
  final Box box;

  /// Called every time the box changes. The builder must not return null.
  final BoxWidgetBuilder builder;

  /// Specifies which keys should be watched.
  final List<String> watchKeys;

  @override
  _WatchBoxBuilderState createState() => _WatchBoxBuilderState();
}

class _WatchBoxBuilderState extends State<WatchBoxBuilder> {
  @visibleForTesting
  StreamSubscription subscription;

  @override
  void initState() {
    super.initState();

    _subscribe();
  }

  @override
  void didUpdateWidget(WatchBoxBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.box != oldWidget.box) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    subscription = widget.box.watch().listen((event) {
      if (widget.watchKeys != null && !widget.watchKeys.contains(event.key)) {
        return;
      }

      setState(() {});
    });
  }

  void _unsubscribe() {
    subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.box);
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
